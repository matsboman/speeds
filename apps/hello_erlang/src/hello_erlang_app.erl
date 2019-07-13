%%%-------------------------------------------------------------------
%% @doc hello_erlang public API
%% @end
%%%-------------------------------------------------------------------

-module(hello_erlang_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================

start(_Type, _Args) ->
	Dispatch = cowboy_router:compile([
		{'_', [{"/speeds", hello_handler, []}]}
	]),
	{ok, _} = cowboy:start_clear(my_http_listener,
		[{port, 4567}],
		#{env => #{dispatch => Dispatch}}
	),
	hello_erlang_sup:start_link().

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================
