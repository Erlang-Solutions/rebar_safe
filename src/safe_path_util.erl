-module(safe_path_util).

-export([longest_common_prefix/1]).

-spec longest_common_prefix([binary()]) -> binary().
longest_common_prefix(Paths) ->
    case Paths of
        [] ->
            <<>>;
        [Path | Rest] ->
            lists:foldl(
                fun(CurrentPath, CommonAcc) -> common_prefix(CommonAcc, CurrentPath) end,
                Path,
                Rest
            )
    end.

%% Join segments back with /
join_segments(Segments) ->
    join_segments(Segments, []).

join_segments([], Acc) ->
    lists:reverse(Acc);
join_segments([Seg | Rest], []) ->
    join_segments(Rest, [Seg]);
join_segments([Seg | Rest], Acc) ->
    join_segments(Rest, [Seg, <<"/">> | Acc]).

%% Compare two paths and return common prefix
common_prefix(Path1, Path2) ->
    Segs1 = binary:split(Path1, <<"/">>, [global]),
    Segs2 = binary:split(Path2, <<"/">>, [global]),
    CommonSegs = match_segments(Segs1, Segs2, []),
    case CommonSegs of
        [] ->
            <<>>;
        _ ->
            list_to_binary(join_segments(lists:reverse(CommonSegs)))
    end.

%% Match segments from two paths
match_segments([], _, Acc) ->
    Acc;
match_segments(_, [], Acc) ->
    Acc;
match_segments([Seg | Rest1], [Seg | Rest2], Acc) ->
    match_segments(Rest1, Rest2, [Seg | Acc]);
match_segments(_, _, Acc) ->
    Acc.
