defmodule ExRedisPool do
  use Application
  import Supervisor.Spec, warn: false

  @type reason :: binary
  @type pool_name :: atom
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
  @type redis_query :: [binary]
  @type redis_result :: binary | :undefined

  @timeout 5_000

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(ExRedisPool.Worker, [arg1, arg2, arg3]),
      supervisor(ExRedisPool.PoolsSupervisor, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExRedisPool.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Start a new redis connection pool.
  """
  @spec new(pool_name, [redis_pool_option] | nil) :: {:ok, pool_name} | {:error, reason}
  def new(pool_name, opts \\ []) do
    worker_opts = [
      id: :erlang.make_ref()
    ]
    child_spec = worker(ExRedisPool.RedisPool, [pool_name, opts], worker_opts)
    {:ok, pid} = Supervisor.start_child(ExRedisPool.Supervisor, child_spec)
    pid
  end

  @doc """
  Run a synchronous redis query.
  """
  @spec q(atom, redis_query, integer) :: [redis_result] | {:error, reason}
  def q(pool_name, query, timeout \\ @timeout) do
    ExRedisPool.RedisPool.q(pool_name, query, timeout)
  end

  @doc """
  Run an asynchronous redis query.

  This function takes the requested query and queues it in a separate pool from the
  synchronous queries so bulk asynchronous queries do not degrade quality of service
  for synchronous queries.
  """
  @spec q_noreply(atom, redis_query) :: [redis_result] | {:error, reason}
  def q_noreply(pool_name, query) do
    
  end

  @doc """
  Run a synchronous query pipeline.
  """
  @spec qp(atom, [redis_query], integer) :: [redis_result] | {:error, reason}
  def qp(pool_name, query_pipeline, timeout \\ @timeout) do
    ExRedisPool.RedisPool.qp(pool_name, query_pipeline, timeout)
  end

  @doc """
  Run an asynchronous query pipeline.

  This function takes the requested query pipeline and queues it in a separate pool from the
  synchronous query pipelines so bulk asynchronous query pipelines do not degrade quality of service
  for synchronous query pipelines.
  """
  @spec qp_noreply(atom, [redis_query]) :: [redis_result] | {:error, reason}
  def qp_noreply(pool_name, query_pipeline) do
    
  end
end
