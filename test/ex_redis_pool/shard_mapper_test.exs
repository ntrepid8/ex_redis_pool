defmodule ExRedisPool.ShardMapperTest do
  use ExUnit.Case, async: true

  test "ExRedisPool.ShardMapper.q/3 [basic operation]" do
    # shard connection options
    shard_opts_list = [
      [database: 10],
      [database: 11],
      [database: 12],
      [database: 13],
    ]

    pid = ExRedisPool.Shard.new(shard_opts_list)
    assert is_pid(pid)

    # run a few iterations to make sure we distribute across the shards
    for _ <- 0..100 do
      shard_key = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
      key =       "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
      val =       "#{:crypto.rand_uniform(0, 1_000_000_000)}"

      {:ok, "OK"} = ExRedisPool.Shard.q(pid, ["SET", key, val], shard_key, 5_000)
      {:ok, result} = ExRedisPool.Shard.q(pid, ["GET", key], shard_key, 5_000)
      assert result == val
      {:ok, result} = ExRedisPool.Shard.q(pid, ["DEL", key], shard_key, 5_000)
      assert result == "1"
    end
  end

  test "ExRedisPool.ShardMapper.q/3 [basic operation (reuse existing connections)]" do
    # this test might actually run before the [basic operation] test, but the
    # connections should only be created once.
    # shard connection options
    shard_opts_list = [
      [database: 10],
      [database: 11],
      [database: 12],
      [database: 13],
    ]

    pid = ExRedisPool.Shard.new(shard_opts_list)
    assert is_pid(pid)

    # run a few iterations to make sure we distribute across the shards
    for _ <- 0..100 do
      shard_key = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
      key =       "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
      val =       "#{:crypto.rand_uniform(0, 1_000_000_000)}"

      {:ok, "OK"} = ExRedisPool.Shard.q(pid, ["SET", key, val], shard_key, 5_000)
      {:ok, result} = ExRedisPool.Shard.q(pid, ["GET", key], shard_key, 5_000)
      assert result == val
      {:ok, result} = ExRedisPool.Shard.q(pid, ["DEL", key], shard_key, 5_000)
      assert result == "1"
    end
  end

  test "ExRedisPool.ShardMapper.q/3 [named shard mapper]" do
    # shard connection options
    shard_opts_list = [
      [database: 14],
      [database: 15],
    ]

    pid = ExRedisPool.Shard.new(:test_shard_map, shard_opts_list)
    assert is_pid(pid)

    # run a few iterations to make sure we distribute across the shards
    for _ <- 0..10 do
      shard_key = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
      key =       "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
      val =       "#{:crypto.rand_uniform(0, 1_000_000_000)}"

      {:ok, "OK"} = ExRedisPool.Shard.q(:test_shard_map, ["SET", key, val], shard_key, 5_000)
      {:ok, result} = ExRedisPool.Shard.q(:test_shard_map, ["GET", key], shard_key, 5_000)
      assert result == val
      {:ok, result} = ExRedisPool.Shard.q(:test_shard_map, ["DEL", key], shard_key, 5_000)
      assert result == "1"
    end
  end
end
