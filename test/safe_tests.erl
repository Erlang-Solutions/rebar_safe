-module(safe_tests).
-include_lib("eunit/include/eunit.hrl").

%% Test the main plugin module (safe.erl)
main_plugin_test() ->
    %% Test that safe:init calls safe_prv:init correctly
    meck:new(safe_prv, [passthrough]),
    meck:expect(safe_prv, init, fun(State) -> {ok, State} end),

    try
        State = rebar_state:new(),
        Result = safe:init(State),
        ?assertMatch({ok, _}, Result),
        ?assert(meck:called(safe_prv, init, ['_']))
    after
        meck:unload(safe_prv)
    end.
