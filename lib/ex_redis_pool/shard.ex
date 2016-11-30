defmodule ExRedisPool.Shard do
  @moduledoc """
  Interface module for working with sharded Redis clusters.

  Supervisor for ShardMappers.

  Each child of this supervisor is a process that maps
  queries to their appropriate Redis shard.

  In this context, a shard is simply a RedisPool process. By 
  combining a group of RedisPool processes we can map a workload
  onto more than one instance of Redis.

  """
  import Supervisor.Spec, warn: false
  use Supervisor
  alias ExRedisPool.RedisPool
  require Logger

  @type mapper :: atom | pid
  @type reason :: binary
  @type pool :: atom | pid
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

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, [name: __MODULE__])
  end

  def init(opts) do
    Logger.debug("#{__MODULE__} starting up...")
    children = []
    supervise(children, strategy: :one_for_one)
  end

  @doc """
  Start a new shard_mapper.

  Takes a list of connection options for each shard. Each shard is assigned an
  index based on the order of the connection options.
  """
  @spec new([redis_pool_options]) :: pid
  def new(shard_opts_list) do
    shards = start_shards(shard_opts_list)
    worker_opts = [id: :erlang.make_ref()]
    {:ok, child} =
      Supervisor.start_child(__MODULE__, worker(ExRedisPool.ShardMapper, [shards], worker_opts))
    child
  end

  @doc """
  Like `new/1` but with the option to give an atom name.
  """
  @spec new(mapper, [redis_pool_options]) :: pid
  def new(mapper, shard_opts_list) do
    shards = start_shards(shard_opts_list)
    worker_opts = [id: :erlang.make_ref()]
    {:ok, child} =
      Supervisor.start_child(__MODULE__, worker(ExRedisPool.ShardMapper, [mapper, shards], worker_opts))
    child
  end

  @doc """
  Run a synchronous redis query (sharded).
  """
  @spec q(mapper, redis_query, binary, integer) :: {:ok, redis_result} | {:error, reason}
  def q(mapper, query, shard_key, timeout \\ @timeout) do
    ExRedisPool.ShardMapper.q(mapper, query, shard_key, timeout)
  end

  @doc """
  Like q/3 except returns the result directly or raises an error (sharded).
  """
  @spec q!(mapper, redis_query, binary, integer) :: redis_result | no_return
  def q!(mapper, query, shard_key, timeout \\ @timeout) do
    case ExRedisPool.ShardMapper.q(mapper, query, shard_key, timeout) do
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
  @spec q_noreply(mapper, redis_query, binary) :: :ok | {:error, reason}
  def q_noreply(mapper, query, shard_key) do
    ExRedisPool.ShardMapper.q_noreply(mapper, query)
  end

  @doc """
  Run a synchronous query pipeline.
  """
  @spec qp(mapper, [redis_query], binary, integer) :: [{:ok, redis_result}] | {:error, reason}
  def qp(mapper, query_pipeline, shard_key, timeout \\ @timeout) do
    ExRedisPool.ShardMapper.qp(mapper, query_pipeline, shard_key, timeout)
  end

  @doc """
  Like qp/3 except returns the result directly or raises an error.
  """
  @spec qp!(mapper, [redis_query], binary, integer) :: [redis_result] | no_return
  def qp!(mapper, query_pipeline, shard_key, timeout \\ @timeout) do
    case ExRedisPool.ShardMapper.qp(mapper, query_pipeline, timeout) do
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
  @spec qp_noreply(mapper, [redis_query], binary) :: :ok | {:error, reason}
  def qp_noreply(mapper, query_pipeline, shard_key) do
    ExRedisPool.ShardMapper.qp_noreply(mapper, query_pipeline, shard_key)
  end

  # Helpers

  defp start_shards(shard_opts_list) do
    Enum.map(shard_opts_list, fn(shard_opts) ->
      {:ok, pid} = ExRedisPool.RedisPool.start_link(shard_opts)
    end)
    |> Enum.map(fn({:ok, pid}) -> pid end)
  end
end
