defmodule ExRedisPool.PoolsRegistry do
  @moduledoc """
  Keep track of existing connection pools so they can be re-used rather than duplicated.
  """
  use GenServer
  require Logger

  defstruct [
    # registered pools
    pools: %{},

    # msg timeout
    msg_timeout: 15_000,
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, [name: __MODULE__])
  end

  def init(opts) do
    Logger.debug("#{__MODULE__} starting up...")

    # initialize state, pull in any opts
    state = struct(%__MODULE__{}, opts)

    # finish init
    {:ok, state, state.msg_timeout}
  end

  # API

  def lookup(pool, pool_type, pool_opts, worker_opts) do
    GenServer.call(__MODULE__, {:lookup, [pool, pool_type, pool_opts, worker_opts]})
  end

  def register(pool, pool_type, pool_opts, worker_opts, pool_ref) do
    GenServer.call(__MODULE__, {:register, [pool, pool_type, pool_opts, worker_opts, pool_ref]})
  end

  # Callbacks

  def handle_call({:lookup, [pool, pool_type, pool_opts, worker_opts]}, _from, state) do
    hash_key = hash_opts(pool, pool_type, pool_opts, worker_opts)
    resp =
      case Map.get(state.pools, hash_key, :undefined) do
        :undefined -> {:error, :undefined}
        nil        -> {:error, nil}
        pool_ref   -> {:ok, pool_ref}
      end
    {:reply, resp, state, state.msg_timeout}
  end

  def handle_call({:register, [pool, pool_type, pool_opts, worker_opts, pool_ref]}, _from, state) do
    hash_key = hash_opts(pool, pool_type, pool_opts, worker_opts)
    {resp, state} =
      case Map.has_key?(state.pools, hash_key) do
        true ->
          {{:error, :pool_already_exists}, state}
        false ->
          state = struct(state, %{pools: Map.put(state.pools, hash_key, pool_ref)})
          {{:ok, :pool_regsitered}, state}
      end
    {:reply, resp, state, state.msg_timeout}
  end

  def handle_info(:timeout, state) do
    # process has become idle, hibernate
    Logger.debug("#{__MODULE__} hibernating...")
    {:noreply, state, :hibernate}
  end

  def handle_info(msg, state) do
    Logger.warn("unhandled_message: #{inspect msg}")
    {:noreply, state, state.msg_timeout}
  end

  # Helpers
  def hash_opts(pool, pool_type, pool_opts, worker_opts) do
    data = Enum.join([
      "#{pool}:#{pool_type}",
      serialize_pool_opts(pool_opts),
      serialize_worker_opts(worker_opts)
      ], ":")
    :crypto.hash(:sha256, data)
  end

  def serialize_pool_opts(opts) do
    size         = Keyword.get(opts, :size)
    max_overflow = Keyword.get(opts, :max_overflow)
    "#{size}:#{max_overflow}"
  end

  def serialize_worker_opts(opts) do
    host = Keyword.get(opts, :host)
    port = Keyword.get(opts, :port)
    db   = Keyword.get(opts, :database)
    pass = Keyword.get(opts, :password)
    rs   = Keyword.get(opts, :reconnect_sleep)
    ct   = Keyword.get(opts, :connect_timeout)
    "#{host}:#{port}:#{db}:#{pass}:#{rs}:#{ct}"
  end

end
