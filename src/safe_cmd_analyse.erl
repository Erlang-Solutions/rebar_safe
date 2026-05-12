-module(safe_cmd_analyse).

%% Handles the 'analyse' task.
%%
%% Config resolution for analyse:
%%   - If .safe/config.json exists, use it directly.
%%   - Otherwise, generate config inline and pass it to SAFE without prompting.

-export([handle/3]).

-spec handle(safe_rebar_interface:state(), string(), boolean()) ->
    {ok, safe_rebar_interface:state()} | {error, string()}.
handle(State, Dir, Debug) ->
    case safe_cmd_download:ensure_binary_available(Dir, Debug) of
        ok -> analyse_with_config(State, Dir, Debug);
        {error, Reason} -> task_error(Reason)
    end.

%%====================================================================
%% Internal functions
%%====================================================================

analyse_with_config(State, Dir, Debug) ->
    case resolve_config(State, Dir, Debug) of
        {ok, ConfigSpec} -> run_analyse(State, Dir, ConfigSpec);
        {error, Reason} -> task_error(Reason)
    end.

run_analyse(State, Dir, ConfigSpec) ->
    safe_print:status("* running SAFE analysis"),
    case safe_runner:analyse(Dir, ConfigSpec) of
        ok ->
            safe_print:status("* SAFE analysis complete - no vulnerabilities found"),
            {ok, State};
        {error, {analyse, 2}} ->
            safe_print:error("* SAFE analysis complete - vulnerabilities found"),
            {error, safe_errors:format_error(vulnerabilities_found)};
        {error, {analyse, ExitCode}} ->
            safe_print:error("SAFE analysis failed."),
            {error, safe_errors:format_error({analyse_failed, ExitCode})}
    end.

resolve_config(State, Dir, Debug) ->
    ConfigFile = safe_cmd_util:config_file_path(Dir),
    case filelib:is_file(ConfigFile) of
        true -> safe_cmd_util:use_existing_config(ConfigFile, Debug);
        false -> generate_inline_config(State, Debug)
    end.

generate_inline_config(State, Debug) ->
    case safe_cmd_util:get_config(State, Debug) of
        {ok, ConfigMap} ->
            Compact = lists:flatten(io_lib:format("~s", [jsx:encode(ConfigMap)])),
            {ok, {config_json, Compact}};
        {error, _} = Err ->
            Err
    end.

task_error(Reason) ->
    safe_print:error(io_lib:format("~s", [safe_errors:format_error(Reason)])),
    {error, safe_errors:format_error(Reason)}.
