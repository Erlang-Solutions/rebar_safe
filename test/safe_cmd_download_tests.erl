-module(safe_cmd_download_tests).
-include_lib("eunit/include/eunit.hrl").

%% Test reading lock file
read_lock_file_test() ->
    % Test with non-existent file
    ?assertEqual({error, not_found}, safe_cmd_download:read_lock_file("/nonexistent")),

    % Test with valid lock file content
    TempDir = "/tmp/safe_test_" ++ integer_to_list(erlang:system_time()),
    ok = file:make_dir(TempDir),
    LockPath = filename:join(TempDir, "safe.lock"),
    LockContent = jsx:encode(#{<<"version">> => <<"1.5.0">>}, [{space, 1}, {indent, 2}]),
    ok = file:write_file(LockPath, LockContent),

    ?assertEqual({ok, <<"1.5.0">>}, safe_cmd_download:read_lock_file(TempDir)),

    % Cleanup
    file:delete(LockPath),
    file:del_dir(TempDir).

%% Test reading invalid lock file
read_lock_file_invalid_test() ->
    TempDir = "/tmp/safe_test_invalid_" ++ integer_to_list(erlang:system_time()),
    ok = file:make_dir(TempDir),
    LockPath = filename:join(TempDir, "safe.lock"),

    % Test with invalid JSON
    ok = file:write_file(LockPath, <<"invalid json">>),
    ?assertEqual({error, invalid_format}, safe_cmd_download:read_lock_file(TempDir)),

    % Test with missing version field
    ok = file:write_file(
        LockPath, jsx:encode(#{<<"other">> => <<"field">>}, [{space, 1}, {indent, 2}])
    ),
    ?assertEqual({error, invalid_format}, safe_cmd_download:read_lock_file(TempDir)),

    % Cleanup
    file:delete(LockPath),
    file:del_dir(TempDir).

%% Test writing lock file
write_lock_file_test() ->
    TempDir = "/tmp/safe_test_write_" ++ integer_to_list(erlang:system_time()),
    ok = file:make_dir(TempDir),
    LockPath = filename:join(TempDir, "safe.lock"),

    % Write lock file
    ok = safe_cmd_download:write_lock_file(TempDir, <<"1.5.0">>),

    % Verify content
    {ok, Content} = file:read_file(LockPath),
    Expected = jsx:encode(#{<<"version">> => <<"1.5.0">>}, [{space, 1}, {indent, 2}]),
    ?assertEqual(Expected, Content),

    % Cleanup
    file:delete(LockPath),
    file:del_dir(TempDir).
