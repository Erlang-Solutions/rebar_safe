-module(safe_cmd_fingerprint).

%% Handles the 'fingerprint' task.
%%
%% Config resolution for fingerprint:
%%   - If .safe/config.json exists, use it directly.
%%   - Otherwise, generate config, show it to the user, and ask for confirmation.
%%     If the user confirms, run fingerprint with the inline JSON.
%%     If the user rejects, save the config to disk and abort so they can edit it.

-export([handle/3]).

-spec handle(safe_rebar_interface:state(), string(), boolean()) ->
    {ok, safe_rebar_interface:state()} | {error, string()}.
handle(State, Dir, Debug) ->
    case safe_cmd_download:ensure_binary_available(Dir, Debug) of
        ok -> fingerprint_with_config(State, Dir, Debug);
        {error, Reason} -> task_error(Reason)
    end.

%%====================================================================
%% Internal functions
%%====================================================================

fingerprint_with_config(State, Dir, Debug) ->
    case resolve_config(State, Dir, Debug) of
        {ok, ConfigSpec} ->
            run_fingerprint(State, Dir, ConfigSpec);
        {aborted, Msg} ->
            safe_print:status(Msg),
            {ok, State};
        {error, Reason} ->
            task_error(Reason)
    end.

run_fingerprint(State, Dir, ConfigSpec) ->
    safe_print:status("* running SAFE fingerprint"),
    case safe_runner:fingerprint(Dir, ConfigSpec) of
        ok ->
            safe_print:status("* SAFE fingerprint complete"),
            {ok, State};
        {error, {fingerprint, ExitCode}} ->
            safe_print:error("SAFE fingerprint failed."),
            {error, safe_errors:format_error({fingerprint_failed, ExitCode})}
    end.

resolve_config(State, Dir, Debug) ->
    ConfigFile = safe_cmd_util:config_file_path(Dir),
    case filelib:is_file(ConfigFile) of
        true -> safe_cmd_util:use_existing_config(ConfigFile, Debug);
        false -> generate_and_confirm_config(State, Dir, Debug)
    end.

generate_and_confirm_config(State, Dir, Debug) ->
    case safe_cmd_util:get_config(State, Debug) of
        {ok, ConfigMap} -> confirm_config(ConfigMap, Dir);
        {error, _} = Err -> Err
    end.

confirm_config(ConfigMap, Dir) ->
    Encoded = jsx:encode(ConfigMap, [{space, 1}, {indent, 2}]),
    io:format("~s~n", [Encoded]),
    case safe_io:bool_prompt("Would you like to proceed with this configuration?") of
        true ->
            Compact = lists:flatten(io_lib:format("~s", [jsx:encode(ConfigMap)])),
            {ok, {config_json, Compact}};
        false ->
            save_and_abort(ConfigMap, Dir)
    end.

save_and_abort(ConfigMap, Dir) ->
    ConfigFile = safe_cmd_util:config_file_path(Dir),
    case safe_config:save(ConfigFile, ConfigMap) of
        ok ->
            {aborted,
                "Config saved to .safe/config.json. "
                "Edit it as needed, then re-run 'rebar3 safe fingerprint'.\n"
                "See https://safe-docs.erlang-solutions.com/ for configuration reference."};
        {error, _} = Err ->
            Err
    end.

task_error(Reason) ->
    safe_print:error(io_lib:format("~s", [safe_errors:format_error(Reason)])),
    {error, safe_errors:format_error(Reason)}.
