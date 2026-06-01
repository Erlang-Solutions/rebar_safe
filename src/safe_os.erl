%% @doc
%% Port-based process execution — no shell, ever — args list only.
%%
%% Use shell_passthrough/3 to run a binary directly with an explicit
%% args list. Output is forwarded to standard_io as it arrives; only
%% the exit code is returned.
%% @end

-module(safe_os).

-export([shell_passthrough/3]).

-export_type([shell_options/0, exit_code/0]).

-type exit_code() :: non_neg_integer().
-type shell_options() :: [shell_option()].
-type shell_option() ::
    {cd, file:filename_all()}
    | {env, [{string(), string() | false}]}.

%% @doc Execute an executable directly with an explicit args list (no shell involved).
-spec shell_passthrough(
    Executable :: file:filename_all(), Args :: [string()], Options :: shell_options()
) ->
    exit_code().
shell_passthrough(Executable, Args, Options) ->
    PortOptions = extract_port_options(Options),

    PortSettings =
        [
            exit_status,
            stream,
            use_stdio,
            stderr_to_stdout,
            binary,
            {args, Args}
        ] ++ PortOptions,

    %% safe-ignore erlang:open_port/2
    Port = erlang:open_port({spawn_executable, Executable}, PortSettings),
    try
        passthrough_loop(Port)
    after
        catch port_close(Port)
    end.

-spec passthrough_loop(port()) -> exit_code().
passthrough_loop(Port) ->
    receive
        {Port, {data, Data}} ->
            io:put_chars(standard_io, Data),
            passthrough_loop(Port);
        {Port, {exit_status, ExitCode}} ->
            ExitCode
    end.

-spec extract_port_options(shell_options()) -> [term()].
extract_port_options(Options) ->
    lists:filtermap(
        fun
            ({cd, Dir}) -> {true, {cd, Dir}};
            ({env, Env}) -> {true, {env, Env}};
            (_) -> false
        end,
        Options
    ).
