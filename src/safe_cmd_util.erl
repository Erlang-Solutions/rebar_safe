-module(safe_cmd_util).

%% Utilities shared across command modules.

-export([config_file_path/1, use_existing_config/2, get_config/2]).

%% @doc Returns the path to the project's SAFE config file.
-spec config_file_path(string()) -> string().
config_file_path(Dir) ->
    filename:join([Dir, ".safe", "config.json"]).

%% @doc Returns a config_path spec for an existing config file, with debug output.
-spec use_existing_config(string(), boolean()) ->
    {ok, {config_path, string()}}.
use_existing_config(ConfigFile, Debug) ->
    safe_print:status("* Using config from .safe/config.json"),
    safe_print:debug(Debug, "Using existing config: ~s", [ConfigFile]),
    {ok, {config_path, ConfigFile}}.

%% @doc Build the SAFE config from rebar3 state, with debug output.
-spec get_config(safe_rebar_interface:state(), boolean()) ->
    {ok, map()} | {error, term()}.
get_config(State, Debug) ->
    safe_print:status("* checking your project's structure"),
    ProjectApps = safe_rebar_interface:project_apps_from_state(State),
    AppNames = [safe_rebar_interface:app_info_name(App) || App <- ProjectApps],
    safe_print:debug(Debug, "Discovered ~B app(s): ~p", [length(AppNames), AppNames]),
    AppDirs = [safe_rebar_interface:app_info_ebin_dir(App) || App <- ProjectApps],
    safe_print:debug(Debug, "Ebin dirs: ~p", [AppDirs]),
    lists:foreach(
        fun(App) ->
            AppFile = safe_rebar_interface:app_info_app_file(App),
            Name = safe_rebar_interface:app_info_name(App),
            safe_print:debug(Debug, "App ~s -> app file: ~s", [Name, AppFile])
        end,
        ProjectApps
    ),
    case safe_config:make_config(State) of
        {ok, ConfigMap} ->
            safe_print:debug(Debug, "Config: ~s", [
                jsx:encode(ConfigMap, [{space, 1}, {indent, 2}])
            ]),
            {ok, ConfigMap};
        {error, _} = Err ->
            Err
    end.
