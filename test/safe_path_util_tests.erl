-module(safe_path_util_tests).
-include_lib("eunit/include/eunit.hrl").

%% Test longest_common_prefix
longest_common_prefix_empty_test() ->
    ?assertEqual(<<>>, safe_path_util:longest_common_prefix([])).

longest_common_prefix_single_test() ->
    P = <<"/a/b/c">>,
    ?assertEqual(P, safe_path_util:longest_common_prefix([P])).

longest_common_prefix_basic_test() ->
    ?assertEqual(
        <<"/a/b">>,
        safe_path_util:longest_common_prefix([<<"/a/b/c">>, <<"/a/b/d">>])
    ).

longest_common_prefix_no_common_test() ->
    ?assertEqual(<<>>, safe_path_util:longest_common_prefix([<<"foo">>, <<"bar">>])).

longest_common_prefix_relative_test() ->
    ?assertEqual(
        <<"a/b">>,
        safe_path_util:longest_common_prefix([<<"a/b/c">>, <<"a/b/d">>, <<"a/b">>])
    ).

longest_common_prefix_mixed_slash_test() ->
    ?assertEqual(<<>>, safe_path_util:longest_common_prefix([<<"/a/b">>, <<"a/b">>])).

longest_common_prefix_identical_test() ->
    ?assertEqual(
        <<"/a/b/c">>,
        safe_path_util:longest_common_prefix([<<"/a/b/c">>, <<"/a/b/c">>])
    ).
