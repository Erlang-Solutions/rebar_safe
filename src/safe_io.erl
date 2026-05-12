-module(safe_io).

-export([bool_prompt/1, bool_prompt/2]).

bool_prompt(Prompt) ->
    bool_prompt(Prompt, fun io:get_line/1).

bool_prompt(Prompt, GetLineFun) ->
    % append [y/N] postfix to the prompt
    RawPrompt = io_lib:format("~s [Y/n]: ", [Prompt]),
    % ANSI blue for the question, reset after
    Blue = "\x1b[34m",
    Reset = "\x1b[0m",
    AppendedPrompt = [Blue, RawPrompt, Reset],

    case GetLineFun(AppendedPrompt) of
        eof ->
            false;
        {error, _} ->
            false;
        ResponseStr ->
            % normalize possible binary input to a list for string functions
            ResponseList =
                case ResponseStr of
                    Bin when is_binary(Bin) -> binary_to_list(Bin);
                    List -> List
                end,
            FormattedResponse = string:to_lower(string:trim(ResponseList)),
            case FormattedResponse of
                "" ->
                    true;
                "y" ->
                    true;
                "yes" ->
                    true;
                _ ->
                    false
            end
    end.
