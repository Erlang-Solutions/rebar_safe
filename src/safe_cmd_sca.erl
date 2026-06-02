-module(safe_cmd_sca).

-export([handle/4]).

-spec handle(safe_rebar_interface:state(), string(), boolean(), [string()]) ->
    {ok, safe_rebar_interface:state()} | {error, string()}.
handle(State, Dir, Debug, ExtraArgs) ->
    case safe_cmd_download:ensure_binary_available(Dir, Debug) of
        ok -> run_sca(State, Dir, ExtraArgs);
        {error, Reason} -> task_error(Reason)
    end.

%%====================================================================
%% Internal functions
%%====================================================================

run_sca(State, Dir, ExtraArgs) ->
    safe_print:status("* running SAFE SCA"),
    case safe_runner:sca(Dir, ExtraArgs) of
        ok ->
            safe_print:status("* SAFE SCA complete - no known vulnerabilities found"),
            {ok, State};
        {error, {sca, 2}} ->
            safe_print:error("* SAFE SCA complete - vulnerable dependencies found"),
            {error, safe_errors:format_error(sca_vulnerabilities_found)};
        {error, {sca, 3}} ->
            safe_print:error("* SAFE SCA complete - warnings treated as errors"),
            {error, safe_errors:format_error({sca_warnings_as_errors, 3})};
        {error, {sca, ExitCode}} ->
            safe_print:error("SAFE SCA failed."),
            {error, safe_errors:format_error({sca_failed, ExitCode})}
    end.

task_error(Reason) ->
    safe_print:error(io_lib:format("~s", [safe_errors:format_error(Reason)])),
    {error, safe_errors:format_error(Reason)}.
