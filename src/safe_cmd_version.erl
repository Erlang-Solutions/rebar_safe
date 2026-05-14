-module(safe_cmd_version).

%% Handles the 'version' task.
%% Prints the plugin version and, if the SAFE binary is present, its version too.

-export([handle/2]).

-spec handle(safe_rebar_interface:state(), string()) ->
    {ok, safe_rebar_interface:state()} | {error, string()}.
handle(State, Dir) ->
    PluginVersion = resolve_plugin_version(),
    safe_print:status(io_lib:format("* safe-rebar-plugin version: ~s", [PluginVersion])),
    report_binary_version(State, Dir).

%%====================================================================
%% Internal functions
%%====================================================================

resolve_plugin_version() ->
    case application:get_key(rebar_safe, vsn) of
        {ok, V} -> V;
        undefined -> "unknown"
    end.

report_binary_version(State, Dir) ->
    BinaryPath = safe_rel:get_safe_binary_path(Dir),
    case filelib:is_file(BinaryPath) of
        true ->
            run_version_command(State, Dir);
        false ->
            safe_print:status(
                "* SAFE binary not yet downloaded (run 'rebar3 safe download' to install)"
            ),
            {ok, State}
    end.

run_version_command(State, Dir) ->
    case safe_runner:version(Dir) of
        ok ->
            {ok, State};
        {error, {version, ExitCode}} ->
            safe_print:error("SAFE version command failed."),
            {error, safe_errors:format_error({version_failed, ExitCode})}
    end.
