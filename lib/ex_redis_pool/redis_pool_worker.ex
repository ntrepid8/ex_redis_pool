defmodule ExRedisPool.RedisPoolWorker do
  @moduledoc """
  Worker for redis connection pools.
  """
  use GenServer
  require Logger

  @noreply_timeout 300_000  # 5 minutes

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def init(opts) do
    {:ok, client} = start_client(opts)
    state = %{
      client: client
    }
    {:ok, state}
  end

  # API

  def q(pid, query, from, timeout) do
    GenServer.call(pid, {:handle_q, [query, from, timeout]}, timeout)
  end

  def q_noreply(pid, query) do
    GenServer.call(pid, {:handle_q_noreply, [query]}, @noreply_timeout)
  end

  def qp(pid, query_pipeline, from, timeout) do
    GenServer.call(pid, {:handle_qp, [query_pipeline, from, timeout]}, timeout)
  end

  def qp_noreply(pid, query_pipeline) do
    GenServer.call(pid, {:handle_qp_noreply, [query_pipeline]}, @noreply_timeout)
  end

  # Callbacks
  def handle_call({:handle_q, [query, from, timeout]}, _from, state) do
    Logger.debug("query: #{inspect query}")
    # run query
    result = :eredis.q(state[:client], query, timeout)
    # reply directly to original process
    GenServer.reply(from, result)
    {:reply, :ok, state}
  end

  def handle_call({:handle_q_noreply, [query]}, _from, state) do
    Logger.debug("query (noreply): #{inspect query}")
    # run query
    :eredis.q(state[:client], query, @noreply_timeout)
    {:reply, :ok, state}
  end

  def handle_call({:handle_qp, [query_pipeline, from, timeout]}, _from, state) do
    Logger.debug("query_pipeline: #{inspect query_pipeline}")
    # run query_pipeline
    result = :eredis.qp(state[:client], query_pipeline, timeout)
    # reply directly to original process
    GenServer.reply(from, result)
    {:reply, :ok, state}
  end

  def handle_call({:handle_qp_noreply, [query_pipeline]}, _from, state) do
    Logger.debug("query_pipeline (noreply): #{inspect query_pipeline}")
    # run query_pipeline
    :eredis.qp(state[:client], query_pipeline, @noreply_timeout)
    {:reply, :ok, state}
  end

  # Helpers
  defp start_client([
    host: host,
    port: port, 
    database: database,
    password: password,
    reconnect_sleep: reconnect_sleep,
    connect_timeout: connect_timeout
  ]) do
    :eredis.start_link(to_char_list(host), port, database, to_char_list(password), reconnect_sleep, connect_timeout)
  end
end
