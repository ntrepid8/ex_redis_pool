defmodule ExRedisPool.ShardMapperTest do
  use ExUnit.Case, async: true

  test "ExRedisPool.ShardMapper.q/3 [basic operation]" do
    # start shards
    {:ok, rp0_pid} = ExRedisPool.RedisPool.start_link(database: 10)
    {:ok, rp1_pid} = ExRedisPool.RedisPool.start_link(database: 11)
    {:ok, rp2_pid} = ExRedisPool.RedisPool.start_link(database: 12)
    {:ok, rp3_pid} = ExRedisPool.RedisPool.start_link(database: 13)

    # start shard mapper
    shards = [rp0_pid, rp1_pid]
    {:ok, pid} = ExRedisPool.ShardMapper.start_link(shards)

    # run a few iterations to make sure we distribute across the shards
    for _ <- 0..10 do
      shard_key = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
      key =       "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
      val =       "#{:crypto.rand_uniform(0, 1_000_000_000)}"

      {:ok, "OK"} = ExRedisPool.ShardMapper.q(pid, ["SET", key, val], shard_key, 5_000)
      {:ok, result} = ExRedisPool.ShardMapper.q(pid, ["GET", key], shard_key, 5_000)
      assert result == val
      {:ok, result} = ExRedisPool.ShardMapper.q(pid, ["DEL", key], shard_key, 5_000)
      assert result == "1"
    end
  end
end
