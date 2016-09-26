defmodule ExRedisPool.PoolsRegsitryTest do
  use ExUnit.Case, async: true

  @test_mod "ExRedisPool.PoolsRegistry"

  test "#{@test_mod}.lookup/3 [find ref after pool is created, named pools]" do
    # start our pool
    {:ok, pid} = ExRedisPool.RedisPool.start_link(:rprt1)

    # verify the new pools
    state = :sys.get_state(pid)
    assert state.sync_pool_status == :new
    assert state.async_pool_status == :new

    # verify basic operation
    assert verify_basic_operation(pid)

    # verify these pools are registered
    reg_state = :sys.get_state(ExRedisPool.PoolsRegistry)
    assert length(Map.keys(reg_state.pools)) >= 2

    # stop the RedisPool
    ExRedisPool.RedisPool.stop(pid, 5_000)
    assert Process.alive?(pid) == false

    # start it up again
    {:ok, pid} = ExRedisPool.RedisPool.start_link(:rprt1)

    # verify basic operation
    assert verify_basic_operation(pid)

    # verify the new pools
    state = :sys.get_state(pid)
    assert state.sync_pool_status == :existing
    assert state.async_pool_status == :existing
  end

  @tag require_isolation: true
  test "#{@test_mod}.lookup/3 [find ref after pool is created, unnamed pools]" do
    # start our pool
    {:ok, pid} = ExRedisPool.RedisPool.start_link()

    # verify the new pools
    state = :sys.get_state(pid)
    assert state.sync_pool_status == :new
    assert state.async_pool_status == :new

    # verify basic operation
    assert verify_basic_operation(pid)

    # verify these pools are registered
    reg_state = :sys.get_state(ExRedisPool.PoolsRegistry)
    assert length(Map.keys(reg_state.pools)) >= 2

    # stop the RedisPool
    ExRedisPool.RedisPool.stop(pid, 5_000)
    assert Process.alive?(pid) == false

    # start it up again
    {:ok, pid} = ExRedisPool.RedisPool.start_link()

    # verify basic operation
    assert verify_basic_operation(pid)

    # verify the new pools
    state = :sys.get_state(pid)
    assert state.sync_pool_status == :existing
    assert state.async_pool_status == :existing
  end

  defp verify_basic_operation(pid) do
    key = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    {:ok, "OK"} = ExRedisPool.RedisPool.q(pid, ["SET", key, val], 5_000)
    {:ok, result} = ExRedisPool.RedisPool.q(pid, ["GET", key], 5_000)
    assert result == val
    {:ok, result} = ExRedisPool.RedisPool.q(pid, ["DEL", key], 5_000)
    assert result == "1"
  end
end
