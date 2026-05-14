-module(rebar_safe).

-export([init/1]).

-spec init(safe_rebar_interface:state()) -> {ok, safe_rebar_interface:state()}.
init(State) ->
    {ok, State1} = safe_prv:init(State),
    {ok, State1}.
