-module(speed_handler).
-behaviour(gen_server).

%% API.
-export([start_link/0, loop/1, send_timeout/1, write_to_file/1]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-define(TIMEOUT, 60).
-define(MAXSIZE, 1000).

%======================================================================================================
% API
%======================================================================================================

-spec start_link() -> {ok, pid()}.
start_link() ->
  io:fwrite("start_link speed_handler...~n", []),
  gen_server:start_link(?MODULE, [], []).

loop(DataList) ->
  io:fwrite("loop: ~p~n", [DataList]),
  receive
    {cache, Data} ->
      loop([Data | DataList]);
    {eof, Data} ->
      flush_data(lists:reverse([Data | DataList]));
    timeout ->
      io:fwrite("timeout received~n", []),
      flush_data(lists:reverse(DataList))
  end.

send_timeout(Pid) ->
  Pid ! timeout.

write_to_file(DataList) ->
  {ok, File} = file:open("speeds." ++ utc_time(), [write]),
  write_to_file(DataList, File).
write_to_file([], File) ->
  file:close(File),
  ok;
write_to_file([H | T], File) ->
  io:format(File, "~s~n", [binary_to_list(H)]),
  write_to_file(T, File).

%======================================================================================================
% gen_server stuff
%======================================================================================================

init([]) ->
  {ok, []}.

handle_call(_Request, _From, State) ->
  {reply, ignored, State}.

handle_cast(Data, State) ->
  handle_data(jsone:encode(Data), State).

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%======================================================================================================
% Internal functions
%======================================================================================================

handle_data(Data, []) ->
  {ok, {Pid, StartTime}} = start_cache(Data),
  {noreply, [{Pid, StartTime}, iolist_size([Data])]};
handle_data(Data, [{Pid, StartTime}, Size]) ->
  handle_ongoing_cache(Data, {Pid, StartTime}, iolist_size([Data]) + Size, is_expired(StartTime), is_process_alive(Pid)).

start_cache(Data) ->
  Pid = spawn(?MODULE, loop, [[]]),
  Pid ! {cache, Data},
  timer:apply_after(timer:seconds(?TIMEOUT), ?MODULE, send_timeout, [Pid]),
  io:fwrite("spawned process: ~p~n", [Pid]),
  {ok, {Pid, erlang:system_time(millisecond)}}.

handle_ongoing_cache(Data, {OldPid, _StartTime}, _, true, _) ->
  io:fwrite("expired process: ~p~n", [OldPid]),
  {ok, {Pid, StartTime}} = start_cache(Data),
  {noreply, [{Pid, StartTime}, iolist_size([Data])]};
handle_ongoing_cache(Data, {OldPid, _StartTime}, _, _, false) ->
  io:fwrite("process timed out: ~p~n", [OldPid]),
  {ok, {Pid, StartTime}} = start_cache(Data),
  {noreply, [{Pid, StartTime}, iolist_size([Data])]};
handle_ongoing_cache(Data, {Pid, _StartTime}, Size, _, _) when Size > ?MAXSIZE ->
  io:fwrite("handle request size reached limit: ~p~n", [Size]),
  Pid ! {eof, Data},
  {noreply, []};
handle_ongoing_cache(Data, {Pid, StartTime}, Size, _, _) ->
  io:fwrite("keep going Pid: ~p Size: ~p~n", [Pid, Size]),
  Pid ! {cache, Data},
  {noreply, [{Pid, StartTime}, Size]}.

flush_data(DataList) ->
  io:fwrite("writing batch to interface: ~p~n", [DataList]),
  %% Handle writing in its own process
  spawn(?MODULE, write_to_file, [DataList]).

utc_time() ->
  calendar:system_time_to_rfc3339(erlang:system_time(millisecond),
    [{unit, millisecond}, {offset, "Z"}]).

is_expired(StartTimeInMilliSeconds) ->
  (erlang:system_time(millisecond) - StartTimeInMilliSeconds) > timer:seconds(?TIMEOUT).
