defmodule ExRedisPool.RedisPoolTest do
  use ExUnit.Case, async: true

  test "ExRedisPool.RedisPool.q/3 [basic operation]" do
    {:ok, pid} = ExRedisPool.RedisPool.start_link(:rpt1)
    key = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    {:ok, "OK"} = ExRedisPool.RedisPool.q(pid, ["SET", key, val], 5_000)
    {:ok, result} = ExRedisPool.RedisPool.q(pid, ["GET", key], 5_000)
    assert result == val
    {:ok, result} = ExRedisPool.RedisPool.q(pid, ["DEL", key], 5_000)
    assert result == "1"
  end

  test "ExRedisPool.RedisPool.q/3 [use with atom name]" do
    {:ok, _} = ExRedisPool.RedisPool.start_link(:rpt2)
    key = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    {:ok, "OK"} = ExRedisPool.RedisPool.q(:rpt2, ["SET", key, val], 5_000)
    {:ok, result} = ExRedisPool.RedisPool.q(:rpt2, ["GET", key], 5_000)
    assert result == val
    {:ok, result} = ExRedisPool.RedisPool.q(:rpt2, ["DEL", key], 5_000)
    assert result == "1"
  end

  test "ExRedisPool.RedisPool.q/3 [key does not exist]" do
    {:ok, pid} = ExRedisPool.RedisPool.start_link(:rpt3)
    key = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    {:ok, result} = ExRedisPool.RedisPool.q(pid, ["GET", key], 5_000)
    assert result == :undefined
    {:ok, result} = ExRedisPool.RedisPool.q(pid, ["DEL", key], 5_000)
    assert result == "0"
  end

  test "ExRedisPool.RedisPool.q/3 [pid only, no atom name]" do
    {:ok, pid} = ExRedisPool.RedisPool.start_link()
    key = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    {:ok, result} = ExRedisPool.RedisPool.q(pid, ["GET", key], 5_000)
    assert result == :undefined
    {:ok, result} = ExRedisPool.RedisPool.q(pid, ["DEL", key], 5_000)
    assert result == "0"
  end
end
