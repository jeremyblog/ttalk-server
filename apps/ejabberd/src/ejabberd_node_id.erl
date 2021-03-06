%%%-------------------------------------------------------------------
%%% @author Uvarov Michael <arcusfelis@gmail.com>
%%% @copyright (C) 2013, Uvarov Michael
%%% @doc Allocates unique ids for each node.
%%% @end
%%%-------------------------------------------------------------------
-module(ejabberd_node_id).
-export([start/0, node_id/0]).


-include("ejabberd.hrl").
-include("jlib.hrl").

%%====================================================================
%% API
%%====================================================================

-type nodeid() :: non_neg_integer().
-record(node, {name :: atom(),
               id :: nodeid()
              }).
%% 跟新Mneisa中的Node的ID
start() ->
    mnesia:create_table(node,
            [{ram_copies, [node()]},
             {type, set},
             {attributes, record_info(fields, node)}]),
    mnesia:add_table_copy(node, node(), ram_copies),
    register_node(node()),
    ok.
%% 使用事务，这样才能保证顺序
-spec register_node(atom()) -> 'ok'.
register_node(NodeName) ->
    {atomic, _} = mnesia:transaction(fun() ->
        case mnesia:read(node, NodeName) of
            [] ->
                mnesia:write(#node{name = NodeName, id = next_node_id()});
            [_] -> ok
        end
        end),
    ok.
%% 每个节点都适用mnesia存储一个自身的ID
%% 当任何进程查询的时候，都会缓存到进程字典中
%% @doc Return an integer node ID.
-spec node_id() -> {ok, nodeid()}.
node_id() ->
    %% Save result into the process's memory space.
    case get(node_id) of
        undefined ->
            {ok, NodeId} = select_node_id(node()),
            put(node_id, NodeId),
            {ok, NodeId};
        NodeId ->
            {ok, NodeId}
    end.

-spec next_node_id() -> nodeid().
next_node_id() ->
    max_node_id() + 1.
%% 使用Mnesia进行foldl找到最大的id
-spec max_node_id() -> nodeid().
max_node_id() ->
    mnesia:foldl(fun(#node{id=Id}, Max) -> max(Id, Max) end, 0, node).

-spec select_node_id(NodeName :: atom()
                    ) -> {'error','not_found'} | {'ok',nodeid()}.
select_node_id(NodeName) ->
    case mnesia:dirty_read(node, NodeName) of
        [#node{id=Id}] -> {ok, Id};
        [] -> {error, not_found}
    end.
