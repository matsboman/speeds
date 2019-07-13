-module(hello_handler).
-behavior(cowboy_handler).

-export([init/2]).

init(Req0, State) ->
  {ok, Body, _} = cowboy_req:read_body(Req0),
  DecodedBody = try jsone:decode(Body) of
                  Decoded -> Decoded
                catch
                  _:_ -> invalid_request
                end,
  handle_request(DecodedBody, Req0, State).

handle_request(#{<<"speed">> := _, <<"timestamp">> := _} = Body, Req0, State) ->
  cast_to_worker(Body),
  Reply = cowboy_req:reply(200,
    #{<<"content-type">> => <<"application/json">>},
    jsone:encode(#{<<"message">> =>
    <<"speed data received">>}),
    Req0),
  {ok, Reply, State};
handle_request(_, Req0, State) ->
  Reply = cowboy_req:reply(400,
    #{<<"content-type">> => <<"application/json">>},
    jsone:encode(#{<<"message">> =>
    <<"invalid request">>}),
    Req0),
  {ok, Reply, State}.

cast_to_worker(Body) ->
  [{ch3, Pid, worker, [ch3]}] =
    supervisor:which_children(hello_erlang_sup),
  gen_server:cast(Pid, Body).
