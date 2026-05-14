-module(safe_rel).

-export([
    download_version/3, detect_os/0, detect_arch/0, get_safe_binary_path/1
]).
-export([fetch_versions/0, get_latest_compatible_version/1]).
-export([compute_checksum_data/1, verify_checksum/2]).
-export([sort_versions_desc/1]).

-define(DOWNLOAD_URL, "https://safe-releases.s3.eu-central-1.amazonaws.com/").
-define(MANIFEST_URL, ?DOWNLOAD_URL ++ "versions.json").

%%====================================================================
%% Manifest Fetching
%%====================================================================

%% @doc Fetch available versions from S3 manifest.
%% The versions.json format is: {"1.0.0": {"macos-x86_64": "sha256", "linux-x86_64": "sha256"}, ...}
-spec fetch_versions() -> {ok, map()} | {error, term()}.
fetch_versions() ->
    case download_file(?MANIFEST_URL) of
        {ok, JsonBinary} ->
            try
                VersionMap = jsx:decode(JsonBinary),
                {ok, VersionMap}
            catch
                _:Reason ->
                    {error, {manifest_parse_failed, Reason}}
            end;
        {error, Reason} ->
            {error, {manifest_fetch_failed, Reason}}
    end.

%% @doc Get latest version satisfying a constraint, optionally including prereleases.
%% Constraint format: &lt;&lt;"~&gt; 1.3"&gt;&gt; (&gt;= 1.3.0, &lt; 2.0.0)
%% or &lt;&lt;"~&gt; 1.3.1"&gt;&gt; (&gt;= 1.3.1, &lt; 1.4.0)
-spec get_latest_compatible_version(Constraint :: binary()) ->
    {ok, binary(), map()} | {error, term()}.
get_latest_compatible_version(Constraint) ->
    ConstraintStr = binary_to_list(Constraint),
    %% If the constraint itself pins a prerelease (e.g. "~> 1.5.0-rc-0"),
    %% prereleases must be included — otherwise the required minimum can never be satisfied.
    IncludeRc = constraint_requires_prerelease(ConstraintStr),
    case fetch_versions() of
        {ok, VersionMap} -> find_latest(VersionMap, ConstraintStr, IncludeRc);
        {error, Reason} -> {error, Reason}
    end.

find_latest(VersionMap, ConstraintStr, IncludeRc) ->
    Versions = maps:keys(VersionMap),
    Compatible = [V || V <- Versions, samovar:check(binary_to_list(V), ConstraintStr)],
    Filtered = filter_prereleases(Compatible, IncludeRc),
    case sort_versions_desc(Filtered) of
        [Latest | _] ->
            Checksums = maps:get(Latest, VersionMap),
            {ok, Latest, Checksums};
        [] ->
            {error, no_compatible_version}
    end.

filter_prereleases(Versions, true) -> Versions;
filter_prereleases(Versions, false) -> [V || V <- Versions, not is_prerelease(V)].

%%====================================================================
%% Download Functions
%%====================================================================

%% @doc Download specific SAFE version with checksum verification.
-spec download_version(string(), binary(), map()) -> {ok, string()} | {error, term()}.
download_version(Dir, Version, Checksums) ->
    case {detect_os(), detect_arch()} of
        {"unsupported", _} -> {error, unsupported_platform};
        {_, "unsupported"} -> {error, unsupported_platform};
        {Os, Arch} -> download_for_platform(Dir, Os, Arch, Version, Checksums)
    end.

download_for_platform(Dir, Os, Arch, Version, Checksums) ->
    PlatformKey = list_to_binary(Os ++ "-" ++ Arch),
    try maps:get(PlatformKey, Checksums, undefined) of
        undefined ->
            {error, {no_checksum_for_platform, PlatformKey}};
        ExpectedChecksum ->
            download_extract_cleanup(Dir, Os, Arch, Version, ExpectedChecksum)
    catch
        error:{badmap, _} ->
            {error, {invalid_checksums, Checksums}}
    end.

download_extract_cleanup(Dir, Os, Arch, Version, ExpectedChecksum) ->
    case do_download_with_checksum(Dir, Os, Arch, Version, ExpectedChecksum) of
        {ok, FilePath} -> extract_and_cleanup(Dir, FilePath);
        {error, _} = Err -> Err
    end.

extract_and_cleanup(Dir, FilePath) ->
    case un_tar(FilePath) of
        {ok, _DestDir} ->
            ok = remove_file(FilePath),
            BinaryPath = get_safe_binary_path(Dir),
            ok = file:change_mode(BinaryPath, 8#755),
            {ok, BinaryPath};
        {error, _} = Err ->
            Err
    end.

-spec detect_os() -> string().
detect_os() ->
    case os:type() of
        {unix, linux} ->
            "linux";
        {unix, darwin} ->
            "macos";
        _ ->
            "unsupported"
    end.

-spec detect_arch() -> string().
detect_arch() ->
    SysArch = erlang:system_info(system_architecture),
    [Head | _] = string:split(SysArch, "-"),
    normalise_arch(Head).

% typically Intel/AMD
normalise_arch("x86_64") -> "x86_64";
% Debian/Ubuntu use "amd64" for x86_64
normalise_arch("amd64") -> "x86_64";
% ARM64 architectures, including Apple Silicon (we transform for x86_64 because
% SAFE uses a universal binary that runs natively on both Intel and Apple Silicon Macs)
normalise_arch("aarch64") -> "x86_64";
normalise_arch("arm64") -> "x86_64";
normalise_arch(_) -> "unsupported".

%%====================================================================
%% Checksum Functions
%%====================================================================

%% @doc Compute SHA256 checksum of binary data, returns lowercase hex binary.
-spec compute_checksum_data(binary()) -> binary().
compute_checksum_data(Data) ->
    Hash = crypto:hash(sha256, Data),
    list_to_binary(binary_to_hex(Hash)).

%% Helper: Convert binary hash to hex string
binary_to_hex(Bin) ->
    lists:flatten([io_lib:format("~2.16.0b", [B]) || <<B>> <= Bin]).

%% @doc Verify checksum matches expected value (case-insensitive, trimmed).
-spec verify_checksum(binary(), binary()) -> boolean().
verify_checksum(Actual, Expected) ->
    NormalizedActual = string:lowercase(string:trim(Actual)),
    NormalizedExpected = string:lowercase(string:trim(Expected)),
    NormalizedActual =:= NormalizedExpected.

%%====================================================================
%% Internal Download Functions
%%====================================================================

%% @doc Download binary and verify its SHA256 checksum.
-spec do_download_with_checksum(string(), string(), string(), binary(), binary()) ->
    {ok, string()} | {error, term()}.
do_download_with_checksum(Dir, Os, Arch, Version, ExpectedChecksum) ->
    VersionStr = binary_to_list(Version),
    FileName = lists:flatten(io_lib:format("safe-~s-~s-~s.tar.gz", [VersionStr, Os, Arch])),
    TarUrl = ?DOWNLOAD_URL ++ VersionStr ++ "/" ++ FileName,
    DestPath = filename:join([download_dir(Dir), FileName]),
    ok = filelib:ensure_dir(DestPath),
    case download_file(TarUrl) of
        {ok, BinaryData} ->
            verify_and_write(DestPath, BinaryData, ExpectedChecksum);
        {error, Reason} ->
            file:delete(DestPath),
            {error, {download_failed, TarUrl, Reason}}
    end.

verify_and_write(DestPath, BinaryData, ExpectedChecksum) ->
    ActualChecksum = compute_checksum_data(BinaryData),
    case verify_checksum(ActualChecksum, ExpectedChecksum) of
        true ->
            write_binary_file(DestPath, BinaryData);
        false ->
            {error, {checksum_mismatch, #{expected => ExpectedChecksum, actual => ActualChecksum}}}
    end.

write_binary_file(DestPath, BinaryData) ->
    case file:write_file(DestPath, BinaryData, [raw]) of
        ok ->
            {ok, DestPath};
        {error, E} ->
            file:delete(DestPath),
            {error, {write_error, E}}
    end.

%% @doc Download file from URL
-spec download_file(string()) -> {ok, binary()} | {error, term()}.
download_file(Url) ->
    application:ensure_all_started(hackney),
    #{host := Host} = uri_string:parse(Url),
    HostStr = unicode:characters_to_list(Host),
    SslOpts = [
        {verify, verify_peer},
        {depth, 3},
        {cacerts, certifi:cacerts()},
        {server_name_indication, HostStr},
        {customize_hostname_check, [
            {match_fun, public_key:pkix_verify_hostname_match_fun(https)}
        ]}
    ],
    case
        hackney:get(Url, [], <<>>, [
            with_body,
            {pool, false},
            {ssl_options, SslOpts},
            {connect_timeout, 10000},
            {recv_timeout, 60000}
        ])
    of
        {ok, 200, _Headers, Body} ->
            {ok, iolist_to_binary(Body)};
        {ok, Code, _Headers, _Body} ->
            {error, {http_error, Code, <<>>}};
        {error, Reason} ->
            {error, {request_failed, Reason}}
    end.

-spec un_tar(string()) -> {ok, string()} | {error, {untar_failed, term()}}.
un_tar(FilePath) ->
    DestDir = ensure_string(filename:dirname(FilePath)),
    case erl_tar:extract(FilePath, [compressed, {cwd, DestDir}, keep_old_files]) of
        ok ->
            {ok, DestDir};
        {error, Reason} ->
            file:delete(FilePath),
            {error, {untar_failed, Reason}}
    end.

%% Internal helper to ensure we have a string (not binary)
-spec ensure_string(file:filename_all()) -> string().
ensure_string(Path) when is_binary(Path) ->
    binary_to_list(Path);
ensure_string(Path) when is_list(Path) ->
    Path.

-spec remove_file(string()) -> ok | {error, {delete_failed, any()}}.
remove_file(FilePath) ->
    case file:delete(FilePath) of
        ok ->
            ok;
        {error, Reason} ->
            {error, {delete_failed, Reason}}
    end.

download_dir(Dir) ->
    filename:join([Dir, "_build", "safe"]).

%%====================================================================
%% Semver Helpers
%%====================================================================

%% @doc Returns true if the constraint string itself pins a prerelease version
%% (e.g. "~> 1.5.0-rc-0"), meaning prereleases must be included in the search.
-spec constraint_requires_prerelease(string()) -> boolean().
constraint_requires_prerelease(ConstraintStr) ->
    %% Strip leading operator ("~> ", ">= ", etc.) to get the version part,
    %% then check whether that version is itself a prerelease.
    VersionPart = string:trim(re:replace(ConstraintStr, "^[~><=! ]+", "", [{return, list}])),
    case samovar:prerelease(VersionPart) of
        [] -> false;
        {error, _} -> false;
        _ -> true
    end.

%% @doc Returns true if version contains a prerelease tag (e.g. &lt;&lt;"1.4.0-rc1"&gt;&gt;).
-spec is_prerelease(binary()) -> boolean().
is_prerelease(Version) ->
    case samovar:prerelease(binary_to_list(Version)) of
        [] -> false;
        {error, _} -> false;
        _ -> true
    end.

%% @doc Sort versions descending (highest first) using semver comparison.
-spec sort_versions_desc([binary()]) -> [binary()].
sort_versions_desc(Versions) ->
    lists:sort(
        fun(A, B) ->
            try
                AParsed = ec_semver:parse(binary_to_list(A)),
                BParsed = ec_semver:parse(binary_to_list(B)),
                ec_semver:gt(AParsed, BParsed)
            catch
                _:_ -> A > B
            end
        end,
        Versions
    ).

%% @doc Get path to safe binary
get_safe_binary_path(ProjectDir) ->
    filename:join([download_dir(ProjectDir), "safe"]).
