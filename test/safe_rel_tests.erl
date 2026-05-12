-module(safe_rel_tests).
-include_lib("eunit/include/eunit.hrl").

%% Test checksums
compute_checksum_data_test() ->
    Expected = <<"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855">>,
    ?assertEqual(Expected, safe_rel:compute_checksum_data(<<>>)).

verify_checksum_match_test() ->
    Hash = <<"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855">>,
    ?assert(safe_rel:verify_checksum(Hash, Hash)).

verify_checksum_mismatch_test() ->
    A = <<"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855">>,
    B = <<"0000000000000000000000000000000000000000000000000000000000000000">>,
    ?assertNot(safe_rel:verify_checksum(A, B)).

%% Test detect_os
detect_os_test() ->
    Os = safe_rel:detect_os(),
    ?assert(lists:member(Os, ["linux", "macos", "unsupported"])).

detect_arch_test() ->
    Arch = safe_rel:detect_arch(),
    ?assert(lists:member(Arch, ["x86_64", "unsupported"])).

%% Test get_safe_binary_path
get_safe_binary_path_test() ->
    Path = safe_rel:get_safe_binary_path("/my/project"),
    ?assert(string:str(Path, "safe") > 0),
    ?assert(string:str(Path, "_build") > 0),
    ?assert(string:str(Path, "/my/project") > 0).

%% Test compute_checksum_data with non-empty data
compute_checksum_nonempty_test() ->
    Data = <<"hello world">>,
    Checksum = safe_rel:compute_checksum_data(Data),
    ?assert(is_binary(Checksum)),
    ?assertEqual(64, byte_size(Checksum)).

%% Test verify_checksum case-insensitive
verify_checksum_case_insensitive_test() ->
    Lower = <<"abc123def456">>,
    Upper = <<"ABC123DEF456">>,
    ?assert(safe_rel:verify_checksum(Lower, Upper)).

%% Test verify_checksum with leading/trailing whitespace
verify_checksum_whitespace_test() ->
    Hash = <<"  abc123  ">>,
    ?assert(safe_rel:verify_checksum(Hash, <<"abc123">>)).

%%====================================================================
%% fetch_versions tests (mock httpc)
%%====================================================================

fetch_versions_success_test() ->
    meck:new(hackney, [passthrough]),
    Body = jsx:encode(#{
        <<"1.4.0">> => #{<<"linux-x86_64">> => <<"abc">>, <<"macos-x86_64">> => <<"def">>}
    }),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {ok, 200, [], Body}
    end),
    try
        Result = safe_rel:fetch_versions(),
        ?assertMatch({ok, _}, Result),
        {ok, Map} = Result,
        ?assert(maps:is_key(<<"1.4.0">>, Map))
    after
        meck:unload(hackney)
    end.

fetch_versions_http_error_test() ->
    meck:new(hackney, [passthrough]),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {ok, 500, [], <<>>}
    end),
    try
        Result = safe_rel:fetch_versions(),
        ?assertMatch({error, {manifest_fetch_failed, _}}, Result)
    after
        meck:unload(hackney)
    end.

fetch_versions_request_failed_test() ->
    meck:new(hackney, [passthrough]),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {error, {failed_connect, []}}
    end),
    try
        Result = safe_rel:fetch_versions(),
        ?assertMatch({error, {manifest_fetch_failed, _}}, Result)
    after
        meck:unload(hackney)
    end.

fetch_versions_parse_failed_test() ->
    meck:new(hackney, [passthrough]),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {ok, 200, [], <<"not valid json!!">>}
    end),
    try
        Result = safe_rel:fetch_versions(),
        ?assertMatch({error, {manifest_parse_failed, _}}, Result)
    after
        meck:unload(hackney)
    end.

%%====================================================================
%% get_latest_compatible_version tests
%%====================================================================

get_latest_compatible_version_success_test() ->
    meck:new(hackney, [passthrough]),
    Body = jsx:encode(#{
        <<"1.4.1">> => #{<<"linux-x86_64">> => <<"abc">>, <<"macos-x86_64">> => <<"def">>},
        <<"1.4.0">> => #{<<"linux-x86_64">> => <<"ghi">>, <<"macos-x86_64">> => <<"jkl">>},
        <<"1.3.0">> => #{<<"linux-x86_64">> => <<"mno">>, <<"macos-x86_64">> => <<"pqr">>}
    }),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {ok, 200, [], Body}
    end),
    try
        Result = safe_rel:get_latest_compatible_version(<<"~> 1.4">>),
        ?assertMatch({ok, _, _}, Result),
        {ok, Version, _Checksums} = Result,
        ?assertEqual(<<"1.4.1">>, Version)
    after
        meck:unload(hackney)
    end.

get_latest_compatible_version_filters_rc_test() ->
    meck:new(hackney, [passthrough]),
    Body = jsx:encode(#{
        <<"1.4.0">> => #{<<"linux-x86_64">> => <<"abc">>},
        <<"1.4.1-rc1">> => #{<<"linux-x86_64">> => <<"def">>}
    }),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {ok, 200, [], Body}
    end),
    try
        %% a stable constraint should filter out rc versions
        Result = safe_rel:get_latest_compatible_version(<<"~> 1.4">>),
        ?assertMatch({ok, _, _}, Result),
        {ok, Version, _} = Result,
        ?assertEqual(<<"1.4.0">>, Version)
    after
        meck:unload(hackney)
    end.

get_latest_compatible_version_includes_rc_test() ->
    meck:new(hackney, [passthrough]),
    Body = jsx:encode(#{
        <<"1.4.0">> => #{<<"linux-x86_64">> => <<"abc">>},
        <<"1.4.1-rc1">> => #{<<"linux-x86_64">> => <<"def">>}
    }),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {ok, 200, [], Body}
    end),
    try
        %% a prerelease constraint should include rc versions
        Result = safe_rel:get_latest_compatible_version(<<"~> 1.4.1-rc1">>),
        ?assertMatch({ok, _, _}, Result),
        {ok, Version, _} = Result,
        ?assertEqual(<<"1.4.1-rc1">>, Version)
    after
        meck:unload(hackney)
    end.

get_latest_compatible_version_no_compatible_test() ->
    meck:new(hackney, [passthrough]),
    Body = jsx:encode(#{
        <<"2.0.0">> => #{<<"linux-x86_64">> => <<"abc">>}
    }),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {ok, 200, [], Body}
    end),
    try
        Result = safe_rel:get_latest_compatible_version(<<"~> 1.4">>),
        ?assertEqual({error, no_compatible_version}, Result)
    after
        meck:unload(hackney)
    end.

get_latest_compatible_version_fetch_error_test() ->
    meck:new(hackney, [passthrough]),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {error, {failed_connect, []}}
    end),
    try
        Result = safe_rel:get_latest_compatible_version(<<"~> 1.4">>),
        ?assertMatch({error, _}, Result)
    after
        meck:unload(hackney)
    end.

%%====================================================================
%% download_version tests
%%====================================================================

download_version_no_checksum_test() ->
    case {safe_rel:detect_os(), safe_rel:detect_arch()} of
        {"unsupported", _} ->
            ok;
        {_, "unsupported"} ->
            ok;
        {Os, Arch} ->
            PlatformKey = list_to_binary(Os ++ "-" ++ Arch),
            %% No entry for current platform in checksums
            Result = safe_rel:download_version("/dir", <<"1.4.0">>, #{}),
            ?assertEqual({error, {no_checksum_for_platform, PlatformKey}}, Result)
    end.

download_version_checksum_mismatch_test() ->
    case {safe_rel:detect_os(), safe_rel:detect_arch()} of
        {"unsupported", _} ->
            ok;
        {_, "unsupported"} ->
            ok;
        {Os, Arch} ->
            TempDir = filename:basedir(user_cache, "safe_rel_test_cm"),
            ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
            PlatformKey = list_to_binary(Os ++ "-" ++ Arch),
            WrongChecksum =
                <<"0000000000000000000000000000000000000000000000000000000000000000">>,
            Checksums = #{PlatformKey => WrongChecksum},
            meck:new(hackney, [passthrough]),
            meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
                {ok, 200, [], <<"some fake binary data">>}
            end),
            try
                Result = safe_rel:download_version(TempDir, <<"1.4.0">>, Checksums),
                ?assertMatch({error, {checksum_mismatch, _}}, Result)
            after
                meck:unload(hackney)
            end
    end.

download_version_download_error_test() ->
    case {safe_rel:detect_os(), safe_rel:detect_arch()} of
        {"unsupported", _} ->
            ok;
        {_, "unsupported"} ->
            ok;
        {Os, Arch} ->
            TempDir = filename:basedir(user_cache, "safe_rel_test_de"),
            ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
            PlatformKey = list_to_binary(Os ++ "-" ++ Arch),
            Checksums = #{PlatformKey => <<"anyvalue">>},
            meck:new(hackney, [passthrough]),
            meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
                {error, {failed_connect, []}}
            end),
            try
                Result = safe_rel:download_version(TempDir, <<"1.4.0">>, Checksums),
                ?assertMatch({error, {download_failed, _, _}}, Result)
            after
                meck:unload(hackney)
            end
    end.

download_version_success_test() ->
    case {safe_rel:detect_os(), safe_rel:detect_arch()} of
        {"unsupported", _} ->
            ok;
        {_, "unsupported"} ->
            ok;
        {Os, Arch} ->
            TempDir = filename:basedir(user_cache, "safe_rel_test_ok"),
            ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
            PlatformKey = list_to_binary(Os ++ "-" ++ Arch),
            TmpBin = filename:join(TempDir, "safe_tmp_bin"),
            ok = file:write_file(TmpBin, <<"fake binary">>),
            TmpTar = filename:join(TempDir, "safe_tmp.tar.gz"),
            ok = erl_tar:create(TmpTar, [{"safe", TmpBin}], [compressed]),
            _ = file:delete(TmpBin),
            {ok, FakeTarGz} = file:read_file(TmpTar),
            _ = file:delete(TmpTar),
            RealChecksum = safe_rel:compute_checksum_data(FakeTarGz),
            Checksums = #{PlatformKey => RealChecksum},
            meck:new(hackney, [passthrough]),
            meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
                {ok, 200, [], FakeTarGz}
            end),
            try
                Result = safe_rel:download_version(TempDir, <<"1.4.0">>, Checksums),
                ?assertMatch({ok, _}, Result)
            after
                meck:unload(hackney),
                DownloadDir = filename:join([TempDir, "_build", "safe"]),
                file:del_dir_r(DownloadDir)
            end
    end.

download_version_untar_error_test() ->
    case {safe_rel:detect_os(), safe_rel:detect_arch()} of
        {"unsupported", _} ->
            ok;
        {_, "unsupported"} ->
            ok;
        {Os, Arch} ->
            TempDir = filename:basedir(user_cache, "safe_rel_test_ut"),
            ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
            PlatformKey = list_to_binary(Os ++ "-" ++ Arch),
            FakeData = <<"not a valid tar.gz">>,
            RealChecksum = safe_rel:compute_checksum_data(FakeData),
            Checksums = #{PlatformKey => RealChecksum},
            meck:new(hackney, [passthrough]),
            meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
                {ok, 200, [], FakeData}
            end),
            try
                Result = safe_rel:download_version(TempDir, <<"1.4.0">>, Checksums),
                ?assertMatch({error, {untar_failed, _}}, Result)
            after
                meck:unload(hackney),
                DownloadDir = filename:join([TempDir, "_build", "safe"]),
                file:del_dir_r(DownloadDir)
            end
    end.

%%====================================================================
%% download_file tests (via fetch_versions which calls download_file)
%%====================================================================

%%====================================================================
%% sort_versions_desc tests
%%====================================================================

sort_versions_desc_distinct_test() ->
    Input = [<<"1.2.0">>, <<"2.0.0">>, <<"1.10.0">>, <<"1.3.5">>],
    Expected = [<<"2.0.0">>, <<"1.10.0">>, <<"1.3.5">>, <<"1.2.0">>],
    ?assertEqual(Expected, safe_rel:sort_versions_desc(Input)).

sort_versions_desc_duplicates_test() ->
    Input = [<<"1.0.0">>, <<"2.0.0">>, <<"1.0.0">>],
    Result = safe_rel:sort_versions_desc(Input),
    ?assertEqual(3, length(Result)),
    ?assertEqual(<<"2.0.0">>, hd(Result)).

sort_versions_desc_empty_test() ->
    ?assertEqual([], safe_rel:sort_versions_desc([])).

sort_versions_desc_single_test() ->
    ?assertEqual([<<"1.2.3">>], safe_rel:sort_versions_desc([<<"1.2.3">>])).

sort_versions_desc_non_semver_test() ->
    %% Falls back to binary lexicographic ordering; must not crash
    Input = [<<"abc">>, <<"xyz">>, <<"def">>],
    Result = safe_rel:sort_versions_desc(Input),
    ?assertEqual(3, length(Result)),
    ?assertEqual(<<"xyz">>, hd(Result)).

download_file_http_404_test() ->
    meck:new(hackney, [passthrough]),
    meck:expect(hackney, get, fun(_Url, [], <<>>, _Opts) ->
        {ok, 404, [], <<>>}
    end),
    try
        %% fetch_versions calls download_file internally
        Result = safe_rel:fetch_versions(),
        ?assertMatch({error, {manifest_fetch_failed, {http_error, 404, _}}}, Result)
    after
        meck:unload(hackney)
    end.
