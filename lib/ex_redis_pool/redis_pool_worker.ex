defmodule ExRedisPool.RedisPoolWorker do
  @moduledoc """
  Worker for redis connection pools.
  """
  use GenServer
  require Logger

  @default_noreply_timeout 300_000  # 5 minutes

  defstruct [
    # message callback timeout
    msg_timeout: 5_000,

    # query noreply timeout
    noreply_timeout: 300_000,

    # redis connection info
    host: nil,
    port: nil,
    database: :undefined,
    password: "",
    reconnect_sleep: 100,
    connect_timeout: 5_000,

    # redis client
    client: nil,

    # query_counter
    query_count: 0,

    # recycle_count
    # recycle the worker after this many queries
    # help the GC on busy systems
    recycle_count: 10_000,
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def init(opts) do
    # initialize state
    state = struct(%__MODULE__{}, opts)

    # debug startup log
    Logger.debug("#{__MODULE__} #{state.host}:#{state.port} starting up")

    # client opts
    client_opts = [
      host:            Keyword.get(opts, :host),
      port:            Keyword.get(opts, :port),
      database:        Keyword.get(opts, :database),
      password:        Keyword.get(opts, :password),
      reconnect_sleep: Keyword.get(opts, :reconnect_sleep),
      connect_timeout: Keyword.get(opts, :connect_timeout),
    ]

    # start the client
    {:ok, client} = start_client(client_opts)

    # update state
    state = struct(state, %{client: client})

    # finish init
    {:ok, state, state.msg_timeout}
  end

  # API

  def q(pid, query, from, timeout) do
    GenServer.call(pid, {:handle_q, [query, from, timeout]}, timeout)
  end

  def q_noreply(pid, query) do
    GenServer.call(pid, {:handle_q_noreply, [query]}, @default_noreply_timeout)
  end

  def qp(pid, query_pipeline, from, timeout) do
    GenServer.call(pid, {:handle_qp, [query_pipeline, from, timeout]}, timeout)
  end

  def qp_noreply(pid, query_pipeline) do
    GenServer.call(pid, {:handle_qp_noreply, [query_pipeline]}, @default_noreply_timeout)
  end

  # Callbacks
  def handle_call({:handle_q, [query, from, timeout]}, _from, state) do
    Logger.debug("query: #{inspect query}")
    # run query
    result = :eredis.q(state.client, query, timeout)
    # reply directly to original process
    GenServer.reply(from, result)
    # update query counts
    state = struct(state, %{query_count: state.query_count+1})
    # done
    return_reply_helper(:reply, :ok, state)
  end

  def handle_call({:handle_q_noreply, [query]}, _from, state) do
    Logger.debug("query (noreply): #{inspect query}")
    # run query
    :eredis.q(state.client, query, state.noreply_timeout)
    # update query counts
    state = struct(state, %{query_count: state.query_count+1})
    # done
    return_reply_helper(:reply, :ok, state)
  end

  def handle_call({:handle_qp, [query_pipeline, from, timeout]}, _from, state) do
    Logger.debug("query_pipeline: #{inspect query_pipeline}")
    # run query_pipeline
    result = :eredis.qp(state.client, query_pipeline, timeout)
    # reply directly to original process
    GenServer.reply(from, result)
    # update query counts
    state = struct(state, %{query_count: state.query_count+1})
    # done
    return_reply_helper(:reply, :ok, state)
  end

  def handle_call({:handle_qp_noreply, [query_pipeline]}, _from, state) do
    Logger.debug("query_pipeline (noreply): #{inspect query_pipeline}")
    # run query_pipeline
    :eredis.qp(state.client, query_pipeline, state.noreply_timeout)
    # update query counts
    state = struct(state, %{query_count: state.query_count+1})
    # done
    return_reply_helper(:reply, :ok, state)
  end

  def handle_info(:timeout, state) do
    # process has become idle, hibernate
    Logger.debug("#{__MODULE__} #{state.host}:#{state.port} hibernating")
    {:noreply, state, :hibernate}
  end

  def handle_info(msg, state) do
    Logger.warn("unhandled_message: #{inspect msg}")
    {:noreply, state, state.msg_timeout}
  end

  # Helpers

  ## return helper
  defp return_reply_helper(status, reply, state) do
    case state.query_count > state.recycle_count do
      false ->
        # it's not time to recycle yet, normal return
        {status, :ok, state, state.msg_timeout}
      true ->
        # many queries have been run, recycle this worker
        Logger.debug("#{__MODULE__} #{state.host}:#{state.port} recycling")
        {:stop, :normal, reply, state}
    end
  end

  ## start eredis client
  defp start_client([
    host: host,
    port: port,
    database: database,
    password: password,
    reconnect_sleep: reconnect_sleep,
    connect_timeout: connect_timeout
  ]) do
    :eredis.start_link(
      to_char_list(host),
      port,
      database,
      to_char_list(password),
      reconnect_sleep,
      connect_timeout)
  end

end
