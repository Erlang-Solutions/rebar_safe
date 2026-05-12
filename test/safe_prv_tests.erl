-module(safe_prv_tests).

-include_lib("eunit/include/eunit.hrl").

%% MOCKED TESTS

%% Test: fingerprint task succeeds
fingerprint_success_test() ->
    setup_mocks("fingerprint", binary_exists),
    meck:expect(safe_runner, fingerprint, fun(_Dir, _Config) -> ok end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result),
        ?assert(meck:called(safe_runner, fingerprint, ['_', '_']))
    after
        teardown_mocks()
    end.

%% Test: fingerprint task fails
fingerprint_failure_test() ->
    setup_mocks("fingerprint", binary_exists),
    meck:expect(safe_runner, fingerprint, fun(_Dir, _Config) ->
        {error, {fingerprint, 1}}
    end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({error, _}, Result)
    after
        teardown_mocks()
    end.

%% Test: analyse task succeeds
analyse_success_test() ->
    setup_mocks("analyse", binary_exists),
    meck:expect(safe_runner, analyse, fun(_Dir, _Config) -> ok end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result),
        ?assert(meck:called(safe_runner, analyse, ['_', '_']))
    after
        teardown_mocks()
    end.

%% Test: analyse task fails with error (exit code 1)
analyse_error_test() ->
    setup_mocks("analyse", binary_exists),
    meck:expect(safe_runner, analyse, fun(_Dir, _Config) ->
        {error, {analyse, 1}}
    end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({error, _}, Result)
    after
        teardown_mocks()
    end.

%% Test: analyse task finds vulnerabilities (exit code 2)
analyse_vulnerabilities_found_test() ->
    setup_mocks("analyse", binary_exists),
    meck:expect(safe_runner, analyse, fun(_Dir, _Config) ->
        {error, {analyse, 2}}
    end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({error, _}, Result)
    after
        teardown_mocks()
    end.

%% Test: No task specified
no_task_test() ->
    setup_mocks(undefined, no_binary),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({error, _}, Result)
    after
        teardown_mocks()
    end.

%% Test: help task
help_task_test() ->
    setup_mocks("help", no_binary),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result)
    after
        teardown_mocks()
    end.

%% Test: unrecognised task
unrecognised_task_test() ->
    setup_mocks("invalid_task", no_binary),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({error, _}, Result)
    after
        teardown_mocks()
    end.

%% Test: error handling in ensure_binary_available when binary is not available
ensure_binary_not_available_test() ->
    setup_mocks("fingerprint", no_binary),
    meck:expect(safe_rel, get_latest_compatible_version, fun(_) ->
        {ok, <<"1.4.0">>, #{<<"linux">> => <<"checksum123">>}}
    end),
    meck:expect(safe_rel, download_version, fun(_, _, _) ->
        {error, download_failed}
    end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({error, _}, Result)
    after
        teardown_mocks()
    end.

%% Test: error handling in ensure_binary_available when version resolution fails
ensure_binary_version_error_test() ->
    setup_mocks("fingerprint", no_binary),
    meck:expect(safe_rel, get_latest_compatible_version, fun(_) ->
        {error, no_compatible_version}
    end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({error, _}, Result)
    after
        teardown_mocks()
    end.

%% Test: fingerprint task with debug mode
fingerprint_debug_test() ->
    setup_mocks_with_debug("fingerprint", binary_exists),
    meck:expect(safe_runner, fingerprint, fun(_Dir, _Config) -> ok end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result)
    after
        teardown_mocks()
    end.

%% File exists, user says yes -> fingerprint runs with file contents
fingerprint_uses_existing_config_test() ->
    setup_mocks("fingerprint", binary_exists),
    ConfigFile = fixture_config_file(),
    KnownConfig = <<"{\"version\": \"1.1\"}">>,
    ok = filelib:ensure_dir(ConfigFile),
    ok = file:write_file(ConfigFile, KnownConfig),
    meck:expect(safe_io, bool_prompt, fun(_) -> true end),
    meck:expect(safe_runner, fingerprint, fun(_Dir, {config_path, ConfigPath}) ->
        ?assert(is_list(ConfigPath)),
        ?assert(string:str(ConfigPath, "config.json") > 0),
        ok
    end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result),
        ?assert(meck:called(safe_runner, fingerprint, ['_', '_']))
    after
        cleanup_config_file(),
        teardown_mocks()
    end.

%% No file, user rejects generated config -> clean abort, file written to disk
fingerprint_saves_config_on_rejection_test() ->
    setup_mocks("fingerprint", binary_exists),
    ConfigFile = fixture_config_file(),
    cleanup_config_file(),
    %% First call (file check prompt) never fires since no file exists;
    %% second call is the "proceed?" prompt - return false
    meck:expect(safe_io, bool_prompt, fun(_) -> false end),
    meck:expect(safe_runner, fingerprint, fun(_Dir, _Config) -> ok end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result),
        ?assertNot(meck:called(safe_runner, fingerprint, ['_', '_'])),
        ?assert(filelib:is_file(ConfigFile))
    after
        cleanup_config_file(),
        teardown_mocks()
    end.

%%====================================================================
%% Analyse config flow tests
%%====================================================================

%% File exists -> analyse runs with file contents, no prompt
analyse_uses_existing_config_test() ->
    setup_mocks("analyse", binary_exists),
    ConfigFile = fixture_config_file(),
    KnownConfig = <<"{\"version\": \"1.1\"}">>,
    ok = filelib:ensure_dir(ConfigFile),
    ok = file:write_file(ConfigFile, KnownConfig),
    meck:expect(safe_runner, analyse, fun(_Dir, {config_path, ConfigPath}) ->
        ?assert(is_list(ConfigPath)),
        ?assert(string:str(ConfigPath, "config.json") > 0),
        ok
    end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result),
        ?assert(meck:called(safe_runner, analyse, ['_', '_'])),
        %% bool_prompt should NOT have been called for analyse
        ?assertNot(meck:called(safe_io, bool_prompt, ['_']))
    after
        cleanup_config_file(),
        teardown_mocks()
    end.

%%====================================================================
%% Download command tests
%%====================================================================

download_success_test() ->
    setup_mocks("download", binary_exists),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result)
    after
        teardown_mocks()
    end.

download_triggers_download_when_no_binary_test() ->
    setup_mocks("download", no_binary),
    meck:expect(safe_rel, get_latest_compatible_version, fun(_) ->
        {ok, <<"1.5.0">>, #{<<"macos-x86_64">> => <<"abc123">>}}
    end),
    meck:expect(safe_rel, download_version, fun(_, _, _) ->
        {ok, "/some/path/safe"}
    end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result),
        ?assert(meck:called(safe_rel, download_version, ['_', '_', '_']))
    after
        teardown_mocks()
    end.

%%====================================================================
%% Version command tests
%%====================================================================

version_success_test() ->
    setup_mocks("version", binary_exists),
    meck:expect(safe_runner, version, fun(_Dir) -> ok end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result),
        ?assert(meck:called(safe_runner, version, ['_']))
    after
        teardown_mocks()
    end.

version_failure_test() ->
    setup_mocks("version", binary_exists),
    meck:expect(safe_runner, version, fun(_Dir) -> {error, {version, 1}} end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({error, _}, Result)
    after
        teardown_mocks()
    end.

%% No binary present -> ok with informational message, version not called
version_no_binary_test() ->
    setup_mocks("version", no_binary),
    meck:expect(safe_runner, version, fun(_Dir) -> ok end),
    try
        State = rebar_state:new(),
        {ok, State1} = safe_prv:init(State),
        Result = safe_prv:do(State1),
        ?assertMatch({ok, _}, Result),
        ?assertNot(meck:called(safe_runner, version, ['_']))
    after
        teardown_mocks()
    end.

%%====================================================================
%% format_error tests
%%====================================================================

format_error_fingerprint_failed_test() ->
    R = safe_prv:format_error({fingerprint_failed, 1}),
    ?assert(lists:flatten(R) =/= []).

format_error_vulnerabilities_found_test() ->
    R = safe_prv:format_error(vulnerabilities_found),
    ?assert(R =/= []).

format_error_analyse_failed_test() ->
    R = safe_prv:format_error({analyse_failed, 1}),
    ?assert(lists:flatten(R) =/= []).

format_error_checksum_mismatch_test() ->
    R = safe_prv:format_error({checksum_mismatch, #{}}),
    ?assert(R =/= []).

format_error_no_checksum_for_platform_test() ->
    R = safe_prv:format_error({no_checksum_for_platform, <<"linux-x86_64">>}),
    ?assert(lists:flatten(R) =/= []).

format_error_download_failed_test() ->
    R = safe_prv:format_error({download_failed, "http://example.com", timeout}),
    ?assert(lists:flatten(R) =/= []).

format_error_write_error_test() ->
    R = safe_prv:format_error({write_error, enospc}),
    ?assert(lists:flatten(R) =/= []).

format_error_http_error_404_test() ->
    R = safe_prv:format_error({http_error, 404, "Not Found"}),
    ?assert(R =/= []).

format_error_http_error_500_test() ->
    R = safe_prv:format_error({http_error, 500, "Server Error"}),
    ?assert(lists:flatten(R) =/= []).

format_error_unsupported_platform_test() ->
    R = safe_prv:format_error(unsupported_platform),
    ?assert(lists:flatten(R) =/= []).

format_error_manifest_fetch_failed_test() ->
    R = safe_prv:format_error({manifest_fetch_failed, timeout}),
    ?assert(R =/= []).

format_error_no_compatible_version_test() ->
    R = safe_prv:format_error(no_compatible_version),
    ?assert(lists:flatten(R) =/= []).

format_error_app_file_outside_test() ->
    R = safe_prv:format_error({app_file_outside_project, "/path/app", "/project"}),
    ?assert(lists:flatten(R) =/= []).

format_error_invalid_checksums_test() ->
    R = safe_prv:format_error({invalid_checksums, bad}),
    ?assert(R =/= []).

format_error_unknown_test() ->
    R = safe_prv:format_error(something_completely_unexpected),
    ?assert(lists:flatten(R) =/= []).

format_error_config_read_error_test() ->
    R = safe_prv:format_error({config_read_error, enoent}),
    ?assert(lists:flatten(R) =/= []).

format_error_config_write_error_test() ->
    R = safe_prv:format_error({config_write_error, enospc}),
    ?assert(lists:flatten(R) =/= []).

format_error_version_failed_test() ->
    R = safe_prv:format_error({version_failed, 1}),
    ?assert(lists:flatten(R) =/= []).

%%====================================================================
%% Helpers
%%====================================================================

setup_mocks(Task, BinaryMode) ->
    %% Create a temp directory for test binary paths
    TempDir = filename:basedir(user_cache, "safe_test"),
    ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
    BinaryPath = filename:join(TempDir, "mock_safe_binary"),
    case BinaryMode of
        binary_exists ->
            ok = file:write_file(BinaryPath, <<"mock">>);
        no_binary ->
            file:delete(BinaryPath)
    end,
    meck:new(safe_rebar_interface, [passthrough]),
    meck:expect(safe_rebar_interface, command_parsed_args_from_state, fun(_) ->
        {[{task, Task}], []}
    end),
    meck:expect(safe_rebar_interface, dir_from_state, fun(_) ->
        {ok, Cwd} = file:get_cwd(),
        filename:join(Cwd, "fixtures/my_umbrella")
    end),
    meck:expect(safe_rebar_interface, project_apps_from_state, fun(_) ->
        {ok, Cwd} = file:get_cwd(),
        ProjectDir = filename:join(Cwd, "fixtures/my_umbrella"),
        EbinDir = filename:join([ProjectDir, "_build", "default", "lib", "app1", "ebin"]),
        [#{name => "app1", ebin_dir => EbinDir}]
    end),
    meck:expect(safe_rebar_interface, app_info_ebin_dir, fun(#{ebin_dir := D}) -> D end),
    meck:expect(safe_rebar_interface, app_info_name, fun(#{name := N}) -> N end),
    meck:expect(safe_rebar_interface, app_info_app_file, fun(#{ebin_dir := D, name := N}) ->
        NameStr =
            if
                is_list(N) -> N;
                is_binary(N) -> binary_to_list(N);
                is_atom(N) -> atom_to_list(N)
            end,
        filename:join(D, NameStr ++ ".app")
    end),
    meck:new(safe_rel, [passthrough]),
    %% Point get_safe_binary_path to a real temp file path
    meck:expect(safe_rel, get_safe_binary_path, fun(_Dir) -> BinaryPath end),
    meck:new(safe_runner, [passthrough]),
    %% Mock safe_io so prompts don't block; default to confirming (true)
    meck:new(safe_io, [passthrough]),
    meck:expect(safe_io, bool_prompt, fun(_) -> true end).

setup_mocks_with_debug(Task, BinaryMode) ->
    setup_mocks(Task, BinaryMode),
    %% Override command_parsed_args to also include debug=true
    meck:expect(safe_rebar_interface, command_parsed_args_from_state, fun(_) ->
        {[{task, Task}, {debug, true}], []}
    end).

teardown_mocks() ->
    TempDir = filename:basedir(user_cache, "safe_test"),
    file:delete(filename:join(TempDir, "mock_safe_binary")),
    file:del_dir(TempDir),
    {ok, Cwd} = file:get_cwd(),
    FixtureDir = filename:join(Cwd, "fixtures/my_umbrella"),
    file:delete(filename:join(FixtureDir, "safe.lock")),
    meck:unload(safe_rebar_interface),
    meck:unload(safe_rel),
    meck:unload(safe_runner),
    meck:unload(safe_io).

%% Returns the .safe/config.json path for the fixture project dir
fixture_config_file() ->
    {ok, Cwd} = file:get_cwd(),
    filename:join([Cwd, "fixtures/my_umbrella", ".safe", "config.json"]).

cleanup_config_file() ->
    ConfigFile = fixture_config_file(),
    file:delete(ConfigFile),
    file:del_dir(filename:dirname(ConfigFile)).
