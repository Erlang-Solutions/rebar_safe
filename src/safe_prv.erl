-module(safe_prv).

-export([init/1, do/1, format_error/1]).

-define(PROVIDER, safe).
-define(DEPS, [compile]).
-define(OPTS, []).

%% ===================================================================
%% Public API
%% ===================================================================

-spec init(safe_rebar_interface:state()) -> {ok, safe_rebar_interface:state()}.
init(State) ->
    Attrs =
        [
            {name, ?PROVIDER},
            {module, ?MODULE},
            {bare, true},
            {deps, ?DEPS},
            {example, "rebar3 safe fingerprint | rebar3 safe analyse | rebar3 safe sca"},
            {opts, ?OPTS},
            {short_desc, "SAFE security vulnerability scanner for Erlang/Elixir projects"},
            {desc, "Runs SAFE security analysis on your Erlang/OTP or Elixir project"}
        ],
    Provider = providers:create(Attrs),
    {ok, safe_rebar_interface:add_provider_to_state(State, Provider)}.

-spec do(safe_rebar_interface:state()) ->
    {ok, safe_rebar_interface:state()} | {error, string()}.
do(State) ->
    {ParsedOpts, ExtraArgs} = safe_rebar_interface:command_parsed_args_from_state(State),
    Task = proplists:get_value(task, ParsedOpts, undefined),
    Debug = os:getenv("DEBUG") =:= "1",
    Dir = safe_rebar_interface:dir_from_state(State),

    safe_print:debug(Debug, "Task: ~p", [Task]),
    safe_print:debug(Debug, "Project dir: ~s", [Dir]),
    safe_print:debug(Debug, "Options: ~p", [ParsedOpts]),

    case Task of
        undefined ->
            safe_print:error(
                "Error: No task specified. Use 'rebar3 safe help' for usage information."
            ),
            {error, "No task specified"};
        "help" ->
            handle_help(),
            {ok, State};
        "fingerprint" ->
            safe_cmd_fingerprint:handle(State, Dir, Debug);
        "analyse" ->
            safe_cmd_analyse:handle(State, Dir, Debug);
        "version" ->
            safe_cmd_version:handle(State, Dir);
        "download" ->
            safe_cmd_download:handle(State, Dir, Debug);
        "sca" ->
            safe_cmd_sca:handle(State, Dir, Debug, ExtraArgs);
        _ ->
            safe_print:error(
                "Error: Unrecognised task. Use 'rebar3 safe help' for usage information."
            ),
            {error, "Unrecognised task"}
    end.

-spec format_error(term()) -> io_lib:chars().
format_error(Reason) ->
    safe_errors:format_error(Reason).

%%====================================================================
%% Internal functions
%%====================================================================

handle_help() ->
    Help =
        "SAFE security vulnerability scanner for Erlang/Elixir projects\n\n" ++
            "USAGE:\n" ++
            "  rebar3 safe <task>\n\n" ++
            "TASKS:\n" ++
            "  fingerprint              Run the fingerprint phase\n" ++
            "  analyse                  Run the analysis phase\n" ++
            "  sca                      Scan dependencies for known vulnerabilities\n" ++
            "  download                 Download the SAFE binary\n" ++
            "  version                  Print plugin and SAFE binary versions\n" ++
            "  help                     Show this help information\n\n" ++
            "OPTIONS:\n" ++
            "  (set DEBUG=1 to print debug information)\n\n" ++
            "EXAMPLES:\n" ++
            "  rebar3 safe download                 Download SAFE binary\n" ++
            "  rebar3 safe fingerprint              Run fingerprint\n" ++
            "  rebar3 safe analyse                  Run analysis\n" ++
            "  rebar3 safe sca                      Scan dependencies\n" ++
            "  rebar3 safe sca --warnings-as-errors Fail on non-hex deps\n" ++
            "  rebar3 safe version                  Show versions\n",
    io:format("~s", [Help]).
