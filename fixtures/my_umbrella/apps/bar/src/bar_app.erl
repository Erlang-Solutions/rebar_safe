%%%-------------------------------------------------------------------
%% @doc bar public API
%% @end
%%%-------------------------------------------------------------------

-module(bar_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    bar_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
