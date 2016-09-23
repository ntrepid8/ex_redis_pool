defmodule ExRedisPool.RedisPool do
  @moduledoc """
  Server for individual connection pools.
  """
  use GenServer
  alias ExRedisPool.{PoolsSupervisor, RedisPoolWorker}
  require Logger

  def start_link(pool_name, opts \\ []) do
    GenServer.start_link(__MODULE__, opts, [name: pool_name])
  end

  def init(opts) do
    # startup for the synchronous pool
    ## resolve the host
    ## init eredis client
    # sync_pool_ref = :erlang.make_ref()
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
    # Logger.debug("sync_pool_pid=#{inspect sync_pool_pid}")
    # startup for the asynchronous pool
    ## build_unique atom for the pool
    ## resolve the host
    ## init eredis client
    ## start ets table to enqueue queries

    # startup for the pool router
    ## named with the atom the user supplied, routes request to correct pool

    state = %{
      sync_pool_ref: sync_pool_ref,
      async_pool_ref: nil,
    }
    {:ok, state}
  end

  # API

  def q(pool_name, query, timeout) do
    GenServer.call(pool_name, {:handle_q, [query, timeout]}, timeout)
  end

  def q_noreply() do
    
  end

  def qp(pool_name, query_pipeline, timeout) do
    GenServer.call(pool_name, {:handle_qp, [query_pipeline, timeout]}, timeout)
  end

  def qp_noreply() do
    
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

  def handle_cast({:handle_q_noreply, []}, state) do
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

  def handle_cast({:handle_qp_noreply, []}, state) do
    {:noreply, state}
  end

  # Helpers


end
