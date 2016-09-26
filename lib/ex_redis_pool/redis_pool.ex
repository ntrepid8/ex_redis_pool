defmodule ExRedisPool.RedisPool do
  @moduledoc """
  Server for individual connection pools.
  """
  use GenServer
  alias ExRedisPool.{PoolsSupervisor, RedisPoolWorker, HostUtil, PoolsRegistry}
  require Logger

  @noreply_timeout 300_000  # 5 minutes

  def start_link(), do: start_link([])
  def start_link(pool) when is_atom(pool), do: start_link(pool, [])
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, [nil, opts], [])
  end
  def start_link(pool, opts) when is_atom(pool) and is_list(opts) do
    GenServer.start_link(__MODULE__, [pool, opts], [name: pool])
  end

  def start(), do: start([])
  def start(pool) when is_atom(pool), do: start(pool, [])
  def start(opts) when is_list(opts) do
    GenServer.start(__MODULE__, [nil, opts], [])
  end
  def start(pool, opts) when is_atom(pool) and is_list(opts) do
    GenServer.start(__MODULE__, [pool, opts], [name: pool])
  end

  def init([pool, opts]) do
    Logger.debug("#{__MODULE__} pool=#{pool} starting up...")
    # startup for the synchronous pool
    ## resolve the host
    sync_pool_ref = {:global, :erlang.make_ref()}
    sync_pool_opts = [
      name:          sync_pool_ref,
      worker_module: ExRedisPool.RedisPoolWorker,
      size:          Keyword.get(opts, :sync_pool_size, 25),
      max_overflow:  Keyword.get(opts, :sync_pool_max_overflow, 100),
    ]
    sync_worker_opts = [
      host:            Keyword.get(opts, :host, "127.0.0.1") |> HostUtil.resolve(),
      port:            Keyword.get(opts, :port, 6379),
      database:        Keyword.get(opts, :database, :undefined),
      password:        Keyword.get(opts, :password, ""),
      reconnect_sleep: Keyword.get(opts, :reconnect_sleep, 100),
      connect_timeout: Keyword.get(opts, :connect_timeout, 5_000),
    ]
    # check for existing pool reconnect
    {sync_pool_ref, sync_pool_status} =
      case PoolsRegistry.lookup(pool, :synchronous, sync_pool_opts, sync_worker_opts) do
        {:ok, pool_ref} ->
          # pool already exists, use it rather than making a new one
          Logger.debug("using existing pool_ref=#{inspect pool_ref} for pool=#{inspect pool} sync_pool")
          {pool_ref, :existing}
        {:error, _} ->
          # pool does not already exist, make it
          Logger.debug("create new pool pool_ref=#{inspect sync_pool_ref} for pool=#{inspect pool} sync_pool")
          {:ok, _} = PoolsSupervisor.new_pool(sync_pool_ref, sync_pool_opts, sync_worker_opts)
          {:ok, _} = PoolsRegistry.register(pool, :synchronous, sync_pool_opts, sync_worker_opts, sync_pool_ref)
          {sync_pool_ref, :new}
      end

    # startup for the asynchronous pool
    async_pool_ref = {:global, :erlang.make_ref()}
    async_pool_opts = [
      name:          async_pool_ref,
      worker_module: ExRedisPool.RedisPoolWorker,
      size:          Keyword.get(opts, :async_pool_size, 25),
      max_overflow:  Keyword.get(opts, :async_pool_max_overflow, 100),
    ]
    async_worker_opts = [
      host:            Keyword.get(opts, :host, "127.0.0.1") |> HostUtil.resolve(),
      port:            Keyword.get(opts, :port, 6379),
      database:        Keyword.get(opts, :database, :undefined),
      password:        Keyword.get(opts, :password, ""),
      reconnect_sleep: Keyword.get(opts, :reconnect_sleep, 100),
      connect_timeout: Keyword.get(opts, :connect_timeout, 5_000),
    ]
    # check for existing pool reconnect
    {async_pool_ref, async_pool_status} =
      case PoolsRegistry.lookup(pool, :asynchronous, async_pool_opts, async_worker_opts) do
        {:ok, pool_ref} ->
          # pool already exists, use it rather than making a new one
          Logger.debug("using existing pool_ref=#{inspect pool_ref} for pool=#{inspect pool} async_pool")
          {pool_ref, :existing}
        {:error, _} ->
          # pool does not already exist, make it
          Logger.debug("create new pool pool_ref=#{inspect async_pool_ref} for pool=#{inspect pool} async_pool")
          {:ok, _} = PoolsSupervisor.new_pool(async_pool_ref, async_pool_opts, async_worker_opts)
          {:ok, _} = PoolsRegistry.register(pool, :asynchronous, async_pool_opts, async_worker_opts, async_pool_ref)
          {async_pool_ref, :new}
      end

    state = %{
      sync_pool_ref: sync_pool_ref,
      sync_pool_status: sync_pool_status,
      async_pool_ref: async_pool_ref,
      async_pool_status: async_pool_status,
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

  def stop(pool) do
    GenServer.stop(pool, :normal, 5_000)
  end
  def stop(pool, timeout) do
    GenServer.stop(pool, :normal, timeout)
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
