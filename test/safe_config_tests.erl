-module(safe_config_tests).
-include_lib("eunit/include/eunit.hrl").

make_config_success_test() ->
    %% Mock the interface functions
    meck:new(safe_rebar_interface, [passthrough]),
    meck:new(safe_path_util, [passthrough]),

    %% Mock the interface functions to return known values
    meck:expect(safe_rebar_interface, project_apps_from_state, fun(_State) ->
        [
            #{name => "app1", ebin_dir => "/project/_build/default/lib/app1/ebin"},
            #{name => "app2", ebin_dir => "/project/_build/default/lib/app2/ebin"}
        ]
    end),
    meck:expect(safe_rebar_interface, dir_from_state, fun(_State) -> "/project" end),
    meck:expect(safe_rebar_interface, app_info_ebin_dir, fun(AppInfo) ->
        maps:get(ebin_dir, AppInfo)
    end),
    meck:expect(safe_rebar_interface, app_info_name, fun(AppInfo) ->
        maps:get(name, AppInfo)
    end),
    meck:expect(safe_rebar_interface, app_info_app_file, fun(AppInfo) ->
        maps:get(ebin_dir, AppInfo) ++ "/app1.app"
    end),

    meck:expect(safe_path_util, longest_common_prefix, fun(_Paths) ->
        <<"/project/_build/default/lib">>
    end),

    try
        State = rebar_state:new(),
        {ok, ConfigMap} = safe_config:make_config(State),
        ?assert(is_map(ConfigMap)),
        ?assert(maps:is_key(output, ConfigMap)),
        ?assert(lists:member(<<"stdio">>, maps:get(output, ConfigMap))),
        ?assert(lists:member(<<"file">>, maps:get(output, ConfigMap))),
        ?assertEqual(<<"1.1">>, maps:get(version, ConfigMap))
    after
        meck:unload(safe_rebar_interface),
        meck:unload(safe_path_util)
    end.

%% Test error handling for app_file_outside_project
make_config_app_file_outside_test() ->
    meck:new(safe_rebar_interface, [passthrough]),

    meck:expect(safe_rebar_interface, project_apps_from_state, fun(_State) ->
        [#{name => "app1", ebin_dir => "/project/_build/default/lib/app1/ebin"}]
    end),
    meck:expect(safe_rebar_interface, dir_from_state, fun(_State) -> "/project" end),
    meck:expect(safe_rebar_interface, app_info_ebin_dir, fun(AppInfo) ->
        maps:get(ebin_dir, AppInfo)
    end),
    meck:expect(safe_rebar_interface, app_info_name, fun(AppInfo) ->
        maps:get(name, AppInfo)
    end),
    meck:expect(safe_rebar_interface, app_info_app_file, fun(_AppInfo) ->
        % This is outside the project
        "/outside/project/app1.app"
    end),

    try
        State = rebar_state:new(),
        Result = safe_config:make_config(State),
        ?assertMatch({error, {app_file_outside_project, _, _}}, Result)
    after
        meck:unload(safe_rebar_interface)
    end.

%% Test interactive_write function
interactive_write_file_exists_user_selects_no_overwrite_test() ->
    TmpDir = filename:basedir(user_cache, "safe_test"),
    ok = filelib:ensure_dir(filename:join(TmpDir, "dummy")),
    TmpFile = filename:join(TmpDir, "safe_config_test_no_overwrite.json"),
    ok = file:write_file(TmpFile, <<"old content">>),

    meck:new(safe_io, [passthrough]),
    meck:expect(safe_io, bool_prompt, fun(_) -> false end),

    try
        Result = safe_config:interactive_write(TmpFile, <<"{}">>),
        ?assertEqual(ok, Result),

        %% Verify file was NOT overwritten
        {ok, Content} = file:read_file(TmpFile),
        ?assertEqual(<<"old content">>, Content),

        % checking IO content
        Out = ?capturedOutput,
        ?assert(string:str(Out, "Skipping writing config to " ++ TmpFile) > 0)
    after
        meck:unload(safe_io),
        file:delete(TmpFile)
    end.

interactive_write_file_exists_user_selects_overwrite_test() ->
    TmpDir = filename:basedir(user_cache, "safe_test"),
    ok = filelib:ensure_dir(filename:join(TmpDir, "dummy")),
    TmpFile = filename:join(TmpDir, "safe_config_test_overwrite.json"),
    ok = file:write_file(TmpFile, <<"old content">>),

    meck:new(safe_io, [passthrough]),
    meck:expect(safe_io, bool_prompt, fun(_) -> true end),

    try
        Result = safe_config:interactive_write(TmpFile, <<"{}">>),
        ?assertEqual(ok, Result),

        %% Verify file WAS overwritten with new config
        {ok, Content} = file:read_file(TmpFile),
        ?assertEqual(<<"{}">>, Content),

        % checking for NO skip message
        Out = ?capturedOutput,
        ?assert(string:str(Out, "Skipping writing config to " ++ TmpFile) =:= 0)
    after
        meck:unload(safe_io),
        file:delete(TmpFile)
    end.
