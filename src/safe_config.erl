-module(safe_config).

-export([make_config/1, save/2, interactive_write/2]).

%% @doc Build the SAFE configuration map from rebar3 project state.
-spec make_config(safe_rebar_interface:state()) -> {ok, map()} | {error, term()}.
make_config(State) ->
    ProjectApps = safe_rebar_interface:project_apps_from_state(State),
    Dir = safe_rebar_interface:dir_from_state(State),
    AppDirs = lists:map(fun safe_rebar_interface:app_info_ebin_dir/1, ProjectApps),

    %% remove the Dir prefix from each path
    RelAppDirs = lists:map(fun(Path) -> relpath(Path, Dir) end, AppDirs),

    BuildPath = find_build_path(RelAppDirs),

    case wrap_app_names(ProjectApps, Dir) of
        {ok, AppNames} ->
            Data =
                #{
                    output => [<<"stdio">>, <<"file">>],
                    version => <<"1.1">>,
                    project =>
                        #{
                            name => list_to_binary(filename:basename(Dir)),
                            type => <<"beam">>,
                            apps => AppNames,
                            paths => [BuildPath]
                        }
                },
            {ok, Data};
        {error, Reason} ->
            {error, Reason}
    end.

%%------------------------------------------------------------------
%% File writing helpers
%%------------------------------------------------------------------

%% @doc Ensure parent directory exists and write ConfigMap as pretty JSON to FilePath.
-spec save(file:filename_all(), map()) -> ok | {error, {config_write_error, term()}}.
save(FilePath, ConfigMap) ->
    case filelib:ensure_dir(FilePath) of
        ok -> write_config_json(FilePath, ConfigMap);
        {error, Reason} -> {error, {config_write_error, Reason}}
    end.

write_config_json(FilePath, ConfigMap) ->
    Encoded = jsx:encode(ConfigMap, [{space, 1}, {indent, 2}]),
    case file:write_file(FilePath, Encoded) of
        ok -> ok;
        {error, Reason} -> {error, {config_write_error, Reason}}
    end.

%% @doc Interactively write pre-encoded Config (iodata) to File.
%% If File exists, the user is prompted whether to overwrite.
%% Returns ok on success or if the user declines, {error, Reason} on failure.
interactive_write(File, Config) ->
    case filelib:is_file(File) of
        true ->
            Prompt = io_lib:format("Config file ~s exists. Overwrite?", [File]),
            case safe_io:bool_prompt(Prompt) of
                true ->
                    file:write_file(File, Config);
                false ->
                    io:format("Skipping writing config to ~s~n", [File]),
                    ok
            end;
        false ->
            file:write_file(File, Config)
    end.

-spec wrap_app_names([safe_rebar_interface:app_info()], string()) ->
    {ok, [map()]} | {error, term()}.
wrap_app_names([], _Dir) ->
    {ok, []};
wrap_app_names([App | Rest], Dir) ->
    case wrap_app_name(App, Dir) of
        {ok, AppMap} -> prepend_app(AppMap, wrap_app_names(Rest, Dir));
        {error, _} = Err -> Err
    end.

prepend_app(AppMap, {ok, Rest}) -> {ok, [AppMap | Rest]};
prepend_app(_, {error, _} = Err) -> Err.

-spec wrap_app_name(safe_rebar_interface:app_info(), string()) ->
    {ok, #{name => binary(), app_file => binary(), additional_includes => [binary()]}}
    | {error, term()}.
wrap_app_name(AppInfo, ProjectDir) ->
    Name = safe_rebar_interface:app_info_name(AppInfo),
    AppFile = safe_rebar_interface:app_info_app_file(AppInfo),
    case AppFile of
        undefined ->
            {ok, #{name => Name, app_file => <<>>, additional_includes => []}};
        Path ->
            %% Verify the path is within the project directory
            case lists:prefix(filename:split(ProjectDir), filename:split(Path)) of
                true ->
                    RelPath = relpath(Path, ProjectDir),
                    {ok, #{
                        name => Name,
                        app_file => list_to_binary(RelPath),
                        additional_includes => []
                    }};
                false ->
                    {error, {app_file_outside_project, Path, ProjectDir}}
            end
    end.

relpath(Path, Base) ->
    P = filename:split(Path),
    B = filename:split(Base),
    filename:join(strip_prefix(P, B)).

strip_prefix([Head | T1], [Head | T2] = _Prefix) ->
    strip_prefix(T1, T2);
strip_prefix(Rest, _) ->
    Rest.

find_build_path(AppDirs) ->
    BinAppDirs = lists:map(fun(Path) -> list_to_binary(Path) end, AppDirs),
    safe_path_util:longest_common_prefix(BinAppDirs).
