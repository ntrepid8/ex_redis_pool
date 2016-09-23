defmodule ExRedisPool.RedisPool do
  @moduledoc """
  Server for individual connection pools.
  """
  use GenServer
  alias ExRedisPool.{PoolsSupervisor, RedisPoolWorker}
  require Logger

  @noreply_timeout 300_000  # 5 minutes

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def start_link(pool) when is_atom(pool) do
    GenServer.start_link(__MODULE__, [], [name: pool])
  end

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def start_link(pool, opts) when is_atom(pool) and is_list(opts) do
    GenServer.start_link(__MODULE__, opts, [name: pool])
  end

  def init(opts) do
    # startup for the synchronous pool
    ## resolve the host
    sync_pool_ref = {:global, :erlang.make_ref()}
    sync_pool_opts = [
      name:          sync_pool_ref,
      worker_module: ExRedisPool.RedisPoolWorker,
      size:          Keyword.get(opts, :sync_pool_size, 10),
      max_overflow:  Keyword.get(opts, :sync_pool_max_overflow, 10),
    ]
    sync_worker_opts = [
      host:            Keyword.get(opts, :host, "127.0.0.1"),  # TODO - resolve host if name rather than IP
      port:            Keyword.get(opts, :port, 6379),
      database:        Keyword.get(opts, :database, :undefined),
      password:        Keyword.get(opts, :password, ""),
      reconnect_sleep: Keyword.get(opts, :reconnect_sleep, 100),
      connect_timeout: Keyword.get(opts, :connect_timeout, 5_000),
    ]
    {:ok, _} = PoolsSupervisor.new_pool(sync_pool_ref, sync_pool_opts, sync_worker_opts)

    # startup for the asynchronous pool
    async_pool_ref = {:global, :erlang.make_ref()}
    async_pool_opts = [
      name:          async_pool_ref,
      worker_module: ExRedisPool.RedisPoolWorker,
      size:          Keyword.get(opts, :async_pool_size, 10),
      max_overflow:  Keyword.get(opts, :async_pool_max_overflow, 10),
    ]
    async_worker_opts = [
      host:            Keyword.get(opts, :host, "127.0.0.1"),  # TODO - resolve host if name rather than IP
      port:            Keyword.get(opts, :port, 6379),
      database:        Keyword.get(opts, :database, :undefined),
      password:        Keyword.get(opts, :password, ""),
      reconnect_sleep: Keyword.get(opts, :reconnect_sleep, 100),
      connect_timeout: Keyword.get(opts, :connect_timeout, 5_000),
    ]
    {:ok, _} = PoolsSupervisor.new_pool(async_pool_ref, async_pool_opts, async_worker_opts)

    state = %{
      sync_pool_ref: sync_pool_ref,
      async_pool_ref: async_pool_ref,
    }
    {:ok, state}
  end

  # API

  def q(pool, query, timeout) do
    GenServer.call(pool, {:handle_q, [query, timeout]}, timeout)
  end

  def q_noreply(pool, query) do
    GenServer.cast(pool, {:handle_q_noreply, [query]})
  end

  def qp(pool, query_pipeline, timeout) do
    GenServer.call(pool, {:handle_qp, [query_pipeline, timeout]}, timeout)
  end

  def qp_noreply(pool, query_pipeline) do
    GenServer.cast(pool, {:handle_q_noreply, [query_pipeline]})
  end

  # Callbacks

  def handle_call({:handle_q, [query, timeout]}, from, state) do
    # run the query and reply from the pool worker so we don't block this process
    spawn(fn -> :poolboy.transaction(
      state.sync_pool_ref,
      fn(pid) -> RedisPoolWorker.q(pid, query, from, timeout) end,
      timeout)
    end)
    {:noreply, state}
  end

  def handle_cast({:handle_q_noreply, [query]}, state) do
    spawn(fn -> :poolboy.transaction(
      state.async_pool_ref,
      fn(pid) -> RedisPoolWorker.q_noreply(pid, query) end,
      @noreply_timeout)
    end)
    {:noreply, state}
  end

  def handle_call({:handle_qp, [query_pipeline, timeout]}, from, state) do
    # run the query and reply in a task so we don't block this process
    spawn(fn -> :poolboy.transaction(
      state.sync_pool_ref,
      fn(pid) -> RedisPoolWorker.qp(pid, query_pipeline, from, timeout) end,
      timeout)
    end)
    {:noreply, state}
  end

  def handle_cast({:handle_qp_noreply, [query_pipeline]}, state) do
    spawn(fn -> :poolboy.transaction(
      state.async_pool_ref,
      fn(pid) -> RedisPoolWorker.qp(pid, query_pipeline) end,
      @noreply_timeout)
    end)
    {:noreply, state}
  end

  # Helpers


end
