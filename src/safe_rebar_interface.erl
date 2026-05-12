-module(safe_rebar_interface).

-export([
    dir_from_state/1,
    project_apps_from_state/1,
    add_provider_to_state/2,
    app_info_name/1,
    app_info_ebin_dir/1,
    app_info_app_file/1,
    get_config/3,
    command_parsed_args_from_state/1
]).

-type state() :: any().
-type app_info() :: any().

-export_type([state/0, app_info/0]).

% Dialyzer would complain about these functions using "unknown" functions
% as rebar_state is typically compiled without Core Erlang / debug info.
-dialyzer({nowarn_function, dir_from_state/1}).
-dialyzer({nowarn_function, project_apps_from_state/1}).
-dialyzer({nowarn_function, add_provider_to_state/2}).
-dialyzer({nowarn_function, app_info_name/1}).
-dialyzer({nowarn_function, app_info_ebin_dir/1}).
-dialyzer({nowarn_function, app_info_app_file/1}).
-dialyzer({nowarn_function, get_config/3}).
-dialyzer({nowarn_function, command_parsed_args_from_state/1}).

dir_from_state(State) ->
    rebar_state:dir(State).

project_apps_from_state(State) ->
    rebar_state:project_apps(State).

add_provider_to_state(State, Provider) ->
    rebar_state:add_provider(State, Provider).

app_info_name(App) ->
    rebar_app_info:name(App).

app_info_ebin_dir(App) ->
    rebar_app_info:ebin_dir(App).

app_info_app_file(App) ->
    rebar_app_info:app_file(App).

%% @doc Get configuration value from rebar state
get_config(State, Key, Default) ->
    rebar_state:get(State, Key, Default).

command_parsed_args_from_state(State) ->
    rebar_state:command_parsed_args(State).
