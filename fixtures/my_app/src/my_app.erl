-module(my_app).

-export([hello/0, add/2]).

hello() ->
    <<"Hello from my_app">>.

add(A, B) ->
    A + B.
