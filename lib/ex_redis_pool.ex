defmodule ExRedisPool do
  use Application
  import Supervisor.Spec, warn: false

  @type pool :: atom | pid
  @type reason :: binary
  @type reconnect_sleep :: :no_reconnect | integer
  @type redis_pool_option :: {:host, binary} |
                             {:port, integer} |
                             {:database, binary} |
                             {:password, binary} |
                             {:reconnect_sleep, reconnect_sleep} |
                             {:sync_pool_size, integer} |
                             {:sync_pool_max_overflow, integer} |
                             {:async_pool_size, integer} |
                             {:async_pool_max_overflow, integer}
  @type redis_pool_options :: [redis_pool_option]
  @type redis_query :: [binary]
  @type redis_result :: binary | :undefined

  @timeout 5_000

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # pools supervisor
      supervisor(ExRedisPool.PoolsSupervisor, []),
      # pool registry
      worker(ExRedisPool.PoolsRegistry, []),
      # shard mapper supervisor
      supervisor(ExRedisPool.Shard, []),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExRedisPool.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Start a new redis connection pool within ExRedisPools own supervision tree..
  """
  @spec new(pool, [redis_pool_option]) :: pid
  def new(pool, opts) when is_atom(pool) and is_list(opts) do
    worker_opts = [
      id: :erlang.make_ref()
    ]
    child_spec = worker(ExRedisPool.RedisPool, [pool, opts], worker_opts)
    {:ok, pid} = Supervisor.start_child(ExRedisPool.Supervisor, child_spec)
    pid
  end

  @spec new([redis_pool_option]) :: pid
  def new(opts) when is_list(opts) do
    worker_opts = [
      id: :erlang.make_ref()
    ]
    child_spec = worker(ExRedisPool.RedisPool, [opts], worker_opts)
    {:ok, pid} = Supervisor.start_child(ExRedisPool.Supervisor, child_spec)
    pid
  end

  @spec new(pool) :: pid
  def new(pool) when is_atom(pool) do
    new(pool, [])
  end

  @spec new() :: pid
  def new() do
    new([])
  end

  @doc """
  Start a new redis connection pool client linked to the caller.
  """
  @spec start_client(pool, [redis_pool_option]) :: {:ok, pool} | {:error, reason}
  def start_client(pool, opts) when is_atom(pool) and is_list(opts) do
    ExRedisPool.RedisPool.start_link(pool, opts)
  end

  @spec start_client([redis_pool_option]) :: {:ok, pool} | {:error, reason}
  def start_client(opts) when is_list(opts) do
    ExRedisPool.RedisPool.start_link(opts)
  end

  @spec start_client(pool) :: {:ok, pool} | {:error, reason}
  def start_client(pool) when is_atom(pool) do
    start_client(pool, [])
  end

  @spec start_client() :: {:ok, pool} | {:error, reason}
  def start_client() do
    start_client([])
  end

  def stop_client(pool, timeout \\ @timeout) do
    ExRedisPool.RedisPool.stop(pool, timeout)
  end

  @doc """
  Run a synchronous redis query.
  """
  @spec q(pool, redis_query, integer) :: {:ok, redis_result} | {:error, reason}
  def q(pool, query, timeout \\ @timeout) do
    ExRedisPool.RedisPool.q(pool, query, timeout)
  end

  @doc """
  Like q/3 except returns the result directly or raises an error.
  """
  @spec q!(pool, redis_query, integer) :: redis_result | no_return
  def q!(pool, query, timeout \\ @timeout) do
    case ExRedisPool.RedisPool.q(pool, query, timeout) do
      {:error, reason} -> raise reason
      {:ok, result}    -> result
    end
  end

  @doc """
  Run an asynchronous redis query.

  This function takes the requested query and queues it in a separate pool from the
  synchronous queries so bulk asynchronous queries do not degrade quality of service
  for synchronous queries.
  """
  @spec q_noreply(pool, redis_query) :: :ok | {:error, reason}
  def q_noreply(pool, query) do
    ExRedisPool.RedisPool.q_noreply(pool, query)
  end

  @doc """
  Run a synchronous query pipeline.
  """
  @spec qp(atom, [redis_query], integer) :: [{:ok, redis_result}] | {:error, reason}
  def qp(pool, query_pipeline, timeout \\ @timeout) do
    ExRedisPool.RedisPool.qp(pool, query_pipeline, timeout)
  end

  @doc """
  Like qp/3 except returns the result directly or raises an error.
  """
  @spec qp!(pool, [redis_query], integer) :: [redis_result] | no_return
  def qp!(pool, query_pipeline, timeout \\ @timeout) do
    case ExRedisPool.RedisPool.qp(pool, query_pipeline, timeout) do
      {:error, reason} -> raise reason
      results          -> Enum.map(results, fn({:ok, result}) -> result end)
    end
  end

  @doc """
  Run an asynchronous query pipeline.

  This function takes the requested query pipeline and queues it in a separate pool from the
  synchronous query pipelines so bulk asynchronous query pipelines do not degrade quality of service
  for synchronous query pipelines.
  """
  @spec qp_noreply(pool, [redis_query]) :: :ok | {:error, reason}
  def qp_noreply(pool, query_pipeline) do
    ExRedisPool.RedisPool.qp_noreply(pool, query_pipeline)
  end
end
