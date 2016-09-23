defmodule ExRedisPool.PoolsSupervisor do
  @moduledoc """
  Supervisor (simple-one-for-one) for connection pools.

  Each child of this supervisor is a supervisor containing
  two connection pools, a synchronous pool for `q` and `qp`,
  and an asynchronous pool for `q_noreply` and `qp_noreply`.

  This supervisor holds all of the pools for each RedisPool
  process.
  """
  import Supervisor.Spec, warn: false
  use Supervisor
  alias ExRedisPool.RedisPool
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, [name: __MODULE__])
  end

  def init(opts) do
    children = []
    supervise(children, strategy: :one_for_one)
  end

  def new_pool(pool_ref, pool_opts, worker_opts) do
    {:ok, child} =
      Supervisor.start_child(__MODULE__, :poolboy.child_spec(pool_ref, pool_opts, worker_opts))
  end

end
