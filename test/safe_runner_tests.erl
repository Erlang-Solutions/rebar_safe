-module(safe_runner_tests).
-include_lib("eunit/include/eunit.hrl").

setup() ->
    meck:new(safe_os, [passthrough]),
    meck:new(safe_rel, [passthrough]),
    meck:expect(safe_rel, get_safe_binary_path, fun(Dir) -> filename:join(Dir, "safe") end).

teardown(_) ->
    meck:unload(safe_os),
    meck:unload(safe_rel).

runner_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
        fun fingerprint_success/0,
        fun fingerprint_failure/0,
        fun analyse_success/0,
        fun analyse_failure/0,
        fun config_path_arg/0,
        fun config_json_arg/0,
        fun sca_success/0,
        fun sca_failure/0,
        fun sca_extra_args/0
    ]}.

fingerprint_success() ->
    meck:expect(safe_os, shell_passthrough, fun(_Exe, _Args, _Opts) -> 0 end),
    ?assertEqual(ok, safe_runner:fingerprint("/fake/project", {config_path, "/fake/config.json"})),
    [{_, {safe_os, shell_passthrough, [_Exe, Args, _]}, _}] = meck:history(safe_os),
    ?assert(lists:member("fingerprint", Args)),
    ?assert(lists:member("--config-path", Args)),
    ?assert(lists:member("--project-root", Args)).

fingerprint_failure() ->
    meck:expect(safe_os, shell_passthrough, fun(_Exe, _Args, _Opts) -> 1 end),
    ?assertEqual(
        {error, {fingerprint, 1}},
        safe_runner:fingerprint("/fake/project", {config_path, "/fake/config.json"})
    ).

analyse_success() ->
    meck:expect(safe_os, shell_passthrough, fun(_Exe, _Args, _Opts) -> 0 end),
    ?assertEqual(ok, safe_runner:analyse("/fake/project", {config_path, "/fake/config.json"})),
    [{_, {safe_os, shell_passthrough, [_Exe, Args, _]}, _}] = meck:history(safe_os),
    ?assert(lists:member("analyse", Args)).

analyse_failure() ->
    meck:expect(safe_os, shell_passthrough, fun(_Exe, _Args, _Opts) -> 2 end),
    ?assertEqual(
        {error, {analyse, 2}},
        safe_runner:analyse("/fake/project", {config_path, "/fake/config.json"})
    ).

config_path_arg() ->
    meck:expect(safe_os, shell_passthrough, fun(_Exe, _Args, _Opts) -> 0 end),
    ok = safe_runner:fingerprint("/fake/project", {config_path, "/my/project/.safe/config.json"}),
    [{_, {safe_os, shell_passthrough, [_Exe, Args, _]}, _}] = meck:history(safe_os),
    ?assert(lists:member("--config-path", Args)),
    ?assert(lists:member("/my/project/.safe/config.json", Args)).

config_json_arg() ->
    meck:expect(safe_os, shell_passthrough, fun(_Exe, _Args, _Opts) -> 0 end),
    ok = safe_runner:fingerprint("/fake/project", {config_json, "{\"version\":\"1.1\"}"}),
    [{_, {safe_os, shell_passthrough, [_Exe, Args, _]}, _}] = meck:history(safe_os),
    ?assert(lists:member("--config-json", Args)),
    ?assert(lists:member("{\"version\":\"1.1\"}", Args)).

sca_success() ->
    meck:expect(safe_os, shell_passthrough, fun(_Exe, _Args, _Opts) -> 0 end),
    ?assertEqual(ok, safe_runner:sca("/fake/project", [])),
    [{_, {safe_os, shell_passthrough, [_Exe, Args, Opts]}, _}] = meck:history(safe_os),
    ?assert(lists:member("sca", Args)),
    % sca does not accept --project-root; binary auto-discovers lock file via cd
    ?assertNot(lists:member("--project-root", Args)),
    ?assertEqual("/fake/project", proplists:get_value(cd, Opts)).

sca_failure() ->
    meck:expect(safe_os, shell_passthrough, fun(_Exe, _Args, _Opts) -> 2 end),
    ?assertEqual(
        {error, {sca, 2}},
        safe_runner:sca("/fake/project", [])
    ).

sca_extra_args() ->
    meck:expect(safe_os, shell_passthrough, fun(_Exe, _Args, _Opts) -> 0 end),
    ok = safe_runner:sca("/fake/project", ["--warnings-as-errors"]),
    [{_, {safe_os, shell_passthrough, [_Exe, Args, _]}, _}] = meck:history(safe_os),
    ?assert(lists:member("--warnings-as-errors", Args)).
