defmodule ExRedisPool.ShardMapper do
  @moduledoc """
  Server process to map queries onto individual pool shards.
  """
  use GenServer
  require Logger
  alias ExRedisPool.{RedisPool}

  def start_link(shards) do
    GenServer.start_link(__MODULE__, [nil, shards], [])
  end
  def start_link(mapper, shards) do
    GenServer.start_link(__MODULE__, [mapper, shards], [name: mapper])
  end

  def init([_mapper, shards]) do
    state = %{
      shards:      shards,
      shard_count: length(shards)
    }
    {:ok, state}
  end

  # API

  def q(mapper, query, shard_key, timeout) do
    GenServer.call(mapper, {:handle_q, [query, shard_key, timeout]}, timeout)
  end

  def q_noreply(mapper, query, shard_key) do
    GenServer.cast(mapper, {:handle_q_noreply, [query, shard_key]})
  end

  def qp(mapper, query_pipeline, shard_key, timeout) do
    GenServer.call(mapper, {:handle_qp, [query_pipeline, shard_key, timeout]}, timeout)
  end

  def qp_noreply(mapper, query_pipeline, shard_key) do
    GenServer.cast(mapper, {:handle_qp_noreply, [query_pipeline, shard_key]})
  end

  # Callbacks

  def handle_call({:handle_q, [query, shard_key, timeout]}, from, state) do
    spawn(fn ->
      # map the shard (pid of redis_pool connected to that shard)
      pool = lookup_shard(shard_key, state.shard_count, state.shards)
      # run the query on the mapped shard
      result = RedisPool.q(pool, query, timeout)
      # send the response
      GenServer.reply(from, result)
    end)
    {:noreply, state}
  end

  def handle_cast({:handle_q_noreply, [query, shard_key]}, state) do
    spawn(fn ->
      # map the shard (pid of redis_pool connected to that shard)
      pool = lookup_shard(shard_key, state.shard_count, state.shards)
      # run the query on the mapped shard
      RedisPool.q_noreply(pool, query)
    end)
    {:noreply, state}
  end

  def handle_call({:handle_qp, [query_pipeline, shard_key, timeout]}, from, state) do
    spawn(fn ->
      # map the shard (pid of redis_pool connected to that shard)
      pool = lookup_shard(shard_key, state.shard_count, state.shards)
      # run the query on the mapped shard
      result = RedisPool.qp(pool, query_pipeline, timeout)
      # send the response
      GenServer.reply(from, result)
    end)
    {:noreply, state}
  end

  def handle_cast({:handle_qp_noreply, [query_pipeline, shard_key]}, state) do
    spawn(fn ->
      # map the shard (pid of redis_pool connected to that shard)
      pool = lookup_shard(shard_key, state.shard_count, state.shards)
      # run the query on the mapped shard
      RedisPool.qp_noreply(pool, query_pipeline)
    end)
    {:noreply, state}
  end

  # Helpers

  defp lookup_shard(shard_key, shard_count, shards) do
    # hash the shard key and cast as an integer of same size
    << shard_key_int::integer-256 >> = :crypto.hash(:sha256, shard_key)
    # shard_key_int mod shard_count
    shard_index = rem(shard_key_int, shard_count)
    Logger.debug("shard_index: #{inspect shard_index}")
    # return the mapped shard
    Enum.at(shards, shard_index)
  end
end
