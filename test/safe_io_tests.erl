-module(safe_io_tests).
-include_lib("eunit/include/eunit.hrl").

%% Test for 'y' input
bool_prompt_y_test() ->
    MockGetLine = fun(_) -> "y\n" end,
    ?assertEqual(true, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for 'Y' input
bool_prompt_y_upper_test() ->
    MockGetLine = fun(_) -> "Y\n" end,
    ?assertEqual(true, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for 'yes' input
bool_prompt_yes_test() ->
    MockGetLine = fun(_) -> "yes\n" end,
    ?assertEqual(true, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for 'YES' input
bool_prompt_yes_upper_test() ->
    MockGetLine = fun(_) -> "YES\n" end,
    ?assertEqual(true, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for 'n' input
bool_prompt_n_test() ->
    MockGetLine = fun(_) -> "n\n" end,
    ?assertEqual(false, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for empty input (Enter = default = yes)
bool_prompt_empty_test() ->
    MockGetLine = fun(_) -> "\n" end,
    ?assertEqual(true, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for random input
bool_prompt_random_test() ->
    MockGetLine = fun(_) -> "maybe\n" end,
    ?assertEqual(false, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for eof
bool_prompt_eof_test() ->
    MockGetLine = fun(_) -> eof end,
    ?assertEqual(false, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for io error
bool_prompt_error_test() ->
    MockGetLine = fun(_) -> {error, some_error} end,
    ?assertEqual(false, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for binary input
bool_prompt_binary_test() ->
    MockGetLine = fun(_) -> <<"y\n">> end,
    ?assertEqual(true, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for input with whitespace
bool_prompt_whitespace_test() ->
    MockGetLine = fun(_) -> "  y  \n" end,
    ?assertEqual(true, safe_io:bool_prompt("Test prompt", MockGetLine)).

%% Test for input with tabs
bool_prompt_tabs_test() ->
    MockGetLine = fun(_) -> "\tyes\t\n" end,
    ?assertEqual(true, safe_io:bool_prompt("Test prompt", MockGetLine)).
