-module(safe_print).

-export([status/1, error/1, debug/3]).

-spec status(iodata()) -> ok.
status(Msg) ->
    io:format("\x1b[1;32m~s\x1b[0m~n", [Msg]).

-spec error(iodata()) -> ok.
error(Msg) ->
    io:format("\x1b[1;31m~s\x1b[0m~n", [Msg]).

-spec debug(boolean(), string(), list()) -> ok.
debug(false, _Fmt, _Args) -> ok;
debug(true, Fmt, Args) -> io:format("\x1b[90m[debug] " ++ Fmt ++ "\x1b[0m~n", Args).
