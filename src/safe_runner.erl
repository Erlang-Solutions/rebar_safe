-module(safe_runner).

%% Handles execution of the installed SAFE binary.
%% Path resolution delegates to safe_rel to avoid duplicating download-directory knowledge.

-export([fingerprint/2, analyse/2, version/1, sca/2]).

-spec fingerprint(string(), {config_path, string()} | {config_json, string()}) ->
    ok | {error, {fingerprint, non_neg_integer()}}.
fingerprint(ProjectDir, ConfigSpec) ->
    {SafeExe, Dir} = safe_exe_and_dir(ProjectDir),
    Args = ["fingerprint"] ++ config_spec_to_args(ConfigSpec) ++ ["--project-root", ProjectDir],
    debug_print_command(SafeExe, Args),
    case safe_os:shell_passthrough(SafeExe, Args, [{cd, Dir}]) of
        0 -> ok;
        ExitCode -> {error, {fingerprint, ExitCode}}
    end.

-spec analyse(string(), {config_path, string()} | {config_json, string()}) ->
    ok | {error, {analyse, non_neg_integer()}}.
analyse(ProjectDir, ConfigSpec) ->
    {SafeExe, Dir} = safe_exe_and_dir(ProjectDir),
    Args = ["analyse"] ++ config_spec_to_args(ConfigSpec) ++ ["--project-root", ProjectDir],
    debug_print_command(SafeExe, Args),
    case safe_os:shell_passthrough(SafeExe, Args, [{cd, Dir}]) of
        0 -> ok;
        ExitCode -> {error, {analyse, ExitCode}}
    end.

-spec sca(string(), [string()]) -> ok | {error, {sca, non_neg_integer()}}.
sca(ProjectDir, ExtraArgs) ->
    % The `sca` subcommand does not accept --project-root or --config flags.
    % Run with cd: ProjectDir so the binary auto-discovers rebar.lock/mix.lock.
    {SafeExe, _Dir} = safe_exe_and_dir(ProjectDir),
    Args = ["sca"] ++ ExtraArgs,
    debug_print_command(SafeExe, Args),
    case safe_os:shell_passthrough(SafeExe, Args, [{cd, ProjectDir}]) of
        0 -> ok;
        ExitCode -> {error, {sca, ExitCode}}
    end.

-spec version(string()) -> ok | {error, {version, non_neg_integer()}}.
version(ProjectDir) ->
    {SafeExe, Dir} = safe_exe_and_dir(ProjectDir),
    Args = ["version"],
    debug_print_command(SafeExe, Args),
    case safe_os:shell_passthrough(SafeExe, Args, [{cd, Dir}]) of
        0 -> ok;
        ExitCode -> {error, {version, ExitCode}}
    end.

%%====================================================================
%% Internal functions
%%====================================================================

config_spec_to_args({config_path, Path}) -> ["--config-path", Path];
config_spec_to_args({config_json, Json}) -> ["--config-json", Json].

-spec safe_exe_and_dir(string()) -> {string(), string()}.
safe_exe_and_dir(ProjectDir) ->
    SafeExe = ensure_string(safe_rel:get_safe_binary_path(ProjectDir)),
    Dir = filename:dirname(SafeExe),
    {SafeExe, Dir}.

debug_print_command(SafeExe, Args) ->
    safe_print:debug(os:getenv("DEBUG") =:= "1", "SAFE command: ~s ~s", [
        SafeExe, string:join(Args, " ")
    ]).

-spec ensure_string(file:filename_all()) -> string().
ensure_string(Path) when is_binary(Path) -> binary_to_list(Path);
ensure_string(Path) when is_list(Path) -> Path.
