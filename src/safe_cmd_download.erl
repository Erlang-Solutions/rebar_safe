-module(safe_cmd_download).

%% Handles the 'download' task and provides ensure_binary_available/2
%% for use by other command modules that need the SAFE binary.

-export([handle/3, ensure_binary_available/2, read_lock_file/1, write_lock_file/2]).

-define(SAFE_VERSION_REQUIREMENT, <<"~> 1.5.0">>).
-define(SAFE_LOCK_FILE, "safe.lock").

-spec handle(safe_rebar_interface:state(), string(), boolean()) ->
    {ok, safe_rebar_interface:state()} | {error, string()}.
handle(State, Dir, Debug) ->
    case ensure_binary_available(Dir, Debug) of
        ok -> {ok, State};
        {error, Reason} -> task_error(Reason)
    end.

%% @doc Ensure a SAFE binary is available, downloading if needed.
-spec ensure_binary_available(string(), boolean()) -> ok | {error, term()}.
ensure_binary_available(Dir, Debug) ->
    BinaryPath = safe_rel:get_safe_binary_path(Dir),
    safe_print:debug(Debug, "Binary path: ~s", [BinaryPath]),
    case filelib:is_file(BinaryPath) of
        true ->
            safe_print:status("* SAFE binary already available"),
            ok;
        false ->
            safe_print:debug(Debug, "Binary not found, checking for lock file", []),
            case read_lock_file(Dir) of
                {ok, LockedVersion} ->
                    safe_print:debug(Debug, "Found locked version: ~s", [LockedVersion]),
                    download_locked_version(Dir, LockedVersion, Debug);
                {error, not_found} ->
                    safe_print:debug(Debug, "No lock file found, using version requirement: ~s", [
                        ?SAFE_VERSION_REQUIREMENT
                    ]),
                    download_latest_compatible(Dir, Debug);
                {error, invalid_format} ->
                    safe_print:debug(
                        Debug, "Invalid lock file format, using version requirement: ~s", [
                            ?SAFE_VERSION_REQUIREMENT
                        ]
                    ),
                    download_latest_compatible(Dir, Debug)
            end
    end.

%%====================================================================
%% Internal functions
%%====================================================================

download_locked_version(Dir, Version, Debug) ->
    safe_print:status(io_lib:format("* Downloading locked SAFE ~s", [Version])),
    case safe_rel:fetch_versions() of
        {ok, VersionMap} ->
            case maps:get(Version, VersionMap, undefined) of
                undefined ->
                    {error, {locked_version_not_found, Version}};
                Checksums ->
                    safe_print:debug(Debug, "Checksums: ~p", [Checksums]),
                    case download_and_verify(Dir, Version, Checksums, Debug) of
                        % Version is already locked, no need to update lock file
                        ok -> ok;
                        {error, _} = Err -> Err
                    end
            end;
        {error, Reason} ->
            {error, Reason}
    end.

download_latest_compatible(Dir, Debug) ->
    safe_print:debug(Debug, "Version requirement: ~s", [?SAFE_VERSION_REQUIREMENT]),
    case safe_rel:get_latest_compatible_version(?SAFE_VERSION_REQUIREMENT) of
        {ok, Version, Checksums} ->
            safe_print:debug(Debug, "Resolved version: ~s", [Version]),
            safe_print:debug(Debug, "Checksums: ~p", [Checksums]),
            case download_and_verify(Dir, Version, Checksums, Debug) of
                ok ->
                    % Write the resolved version to lock file for future reproducible builds
                    case write_lock_file(Dir, Version) of
                        ok ->
                            ok;
                        {error, WriteError} ->
                            safe_print:debug(Debug, "Warning: Failed to write lock file: ~p", [
                                WriteError
                            ]),
                            % Don't fail the download just because lock file write failed
                            ok
                    end;
                {error, _} = Err ->
                    Err
            end;
        {error, Reason} ->
            {error, Reason}
    end.

download_and_verify(Dir, Version, Checksums, Debug) ->
    safe_print:status(io_lib:format("* Downloading SAFE ~s", [Version])),
    case safe_rel:download_version(Dir, Version, Checksums) of
        {ok, BinaryPath} ->
            safe_print:debug(Debug, "Binary saved to: ~s", [BinaryPath]),
            safe_print:status("* SAFE binary ready"),
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

task_error(Reason) ->
    safe_print:error(io_lib:format("~s", [safe_errors:format_error(Reason)])),
    {error, safe_errors:format_error(Reason)}.

%%====================================================================
%% Safe lock file functions
%%====================================================================

%% @doc Read the locked version from safe.lock file if it exists.
-spec read_lock_file(string()) -> {ok, binary()} | {error, not_found | invalid_format}.
read_lock_file(Dir) ->
    LockPath = filename:join(Dir, ?SAFE_LOCK_FILE),
    case file:read_file(LockPath) of
        {ok, Content} ->
            try
                LockData = jsx:decode(Content, [return_maps]),
                case maps:get(<<"version">>, LockData, undefined) of
                    undefined -> {error, invalid_format};
                    Version when is_binary(Version) -> {ok, Version};
                    _ -> {error, invalid_format}
                end
            catch
                _:_ ->
                    {error, invalid_format}
            end;
        {error, enoent} ->
            {error, not_found};
        {error, _} ->
            {error, not_found}
    end.

%% @doc Write the resolved version to safe.lock file.
-spec write_lock_file(string(), binary()) -> ok | {error, term()}.
write_lock_file(Dir, Version) ->
    LockPath = filename:join(Dir, ?SAFE_LOCK_FILE),
    LockData = #{<<"version">> => Version},
    Encoded = jsx:encode(LockData, [{space, 1}, {indent, 2}]),
    file:write_file(LockPath, Encoded).
