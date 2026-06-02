-module(safe_errors).

%% All user-facing error formatting for the safe plugin.

-export([format_error/1]).

-spec format_error(term()) -> io_lib:chars().
format_error({fingerprint_failed, ExitCode}) ->
    io_lib:format(
        "SAFE fingerprint failed with exit code ~B.~nCheck the output above for details.",
        [ExitCode]
    );
format_error(vulnerabilities_found) ->
    "SAFE analysis complete - vulnerabilities found. Review the output above.";
format_error({analyse_failed, _ExitCode}) ->
    io_lib:format("SAFE analysis failed.~nCheck the output above for details.", []);
format_error({checksum_mismatch, _}) ->
    "Downloaded file is corrupted (checksum mismatch). Please try again.";
format_error({no_checksum_for_platform, Platform}) ->
    io_lib:format("No checksum available for platform ~s", [Platform]);
format_error({download_failed, Url, Reason}) ->
    io_lib:format(
        "Failed to download SAFE from ~s~nReason: ~p~nCheck your internet "
        "connection and try again.",
        [Url, Reason]
    );
format_error({write_error, Reason}) ->
    io_lib:format(
        "Failed to write downloaded file~nReason: ~p~nCheck disk space and permissions.",
        [Reason]
    );
format_error({http_error, 404, _}) ->
    "SAFE version not found. Check version and try again.";
format_error({http_error, Code, Reason}) ->
    io_lib:format("HTTP error ~p: ~s", [Code, Reason]);
format_error(unsupported_platform) ->
    io_lib:format(
        "Unsupported platform: ~p~nSAFE currently supports Linux and macOS only.",
        [os:type()]
    );
format_error({manifest_fetch_failed, {request_failed, Reason}}) ->
    io_lib:format(
        "Failed to fetch SAFE versions manifest~nReason: ~p~nCheck your internet connection and firewall settings.",
        [Reason]
    );
format_error({manifest_fetch_failed, Reason}) ->
    io_lib:format(
        "Failed to fetch SAFE versions manifest~nReason: ~p",
        [Reason]
    );
format_error(no_compatible_version) ->
    "No compatible SAFE version found. Check version requirement and try again.";
format_error({app_file_outside_project, Path, ProjectDir}) ->
    io_lib:format(
        "App file is outside project directory~n  App file: ~s~n  Project "
        "root: ~s~nThis usually indicates a misconfigured project structure.",
        [Path, ProjectDir]
    );
format_error({invalid_checksums, _Checksums}) ->
    "Invalid checksums format. Contact support.";
format_error({config_read_error, Reason}) ->
    io_lib:format(
        "Failed to read .safe/config.json: ~p~nCheck file permissions.",
        [Reason]
    );
format_error({config_write_error, Reason}) ->
    io_lib:format(
        "Failed to write .safe/config.json: ~p~nCheck disk space and permissions.",
        [Reason]
    );
format_error({version_failed, ExitCode}) ->
    io_lib:format(
        "SAFE version command failed with exit code ~B.~nCheck the output above for details.",
        [ExitCode]
    );
format_error(sca_vulnerabilities_found) ->
    "SAFE SCA complete - vulnerable dependencies found. Review the output above.";
format_error({sca_warnings_as_errors, _}) ->
    "SAFE SCA exited with warnings treated as errors. Review the output above.";
format_error({sca_failed, ExitCode}) ->
    io_lib:format(
        "SAFE SCA failed with exit code ~B.~nCheck the output above for details.",
        [ExitCode]
    );
format_error({untar_failed, Reason}) ->
    io_lib:format(
        "Failed to extract SAFE archive.~nReason: ~p~nThe download may be corrupted; try again.",
        [Reason]
    );
format_error(Reason) ->
    io_lib:format("Unknown error: ~p", [Reason]).
