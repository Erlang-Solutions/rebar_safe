-module(safe_os_tests).
-include_lib("eunit/include/eunit.hrl").

shell_passthrough_success_test() ->
    Echo = os:find_executable("echo"),
    ExitCode = safe_os:shell_passthrough(Echo, ["hello"], []),
    ?assertEqual(0, ExitCode).

shell_passthrough_exit_code_test() ->
    Sh = os:find_executable("sh"),
    ExitCode = safe_os:shell_passthrough(Sh, ["-c", "exit 42"], []),
    ?assertEqual(42, ExitCode).

shell_passthrough_cd_test() ->
    Pwd = os:find_executable("pwd"),
    ExitCode = safe_os:shell_passthrough(Pwd, [], [{cd, "/tmp"}]),
    ?assertEqual(0, ExitCode).

shell_passthrough_env_test() ->
    Sh = os:find_executable("sh"),
    ExitCode = safe_os:shell_passthrough(
        Sh,
        ["-c", "test \"$MYVAR\" = testval"],
        [{env, [{"MYVAR", "testval"}]}]
    ),
    ?assertEqual(0, ExitCode).
