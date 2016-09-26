defmodule ExRedisPoolTest do
  use ExUnit.Case, async: true
  doctest ExRedisPool

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "ExRedisPool.q/2 [basic operation]" do
    pid = ExRedisPool.new(:erpt1)
    assert is_pid(pid) == true
    key = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    {:ok, "OK"} = ExRedisPool.q(:erpt1, ["SET", key, val])
    {:ok, result} = ExRedisPool.q(:erpt1, ["GET", key])
    assert result == val
    {:ok, result} = ExRedisPool.q(:erpt1, ["DEL", key])
    assert result == "1"
  end

  test "ExRedisPool.qp/2 [basic operation]" do
    pid = ExRedisPool.new(:erpt2)
    assert is_pid(pid) == true
    key1 = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    key2 = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val1 = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val2 = "#{:crypto.rand_uniform(0, 1_000_000_000)}"

    query_pipeline1 = [
      ["SET", key1, val1],
      ["SET", key2, val2],
    ]
    resp1 = ExRedisPool.qp(:erpt2, query_pipeline1)
    assert resp1 == [
      {:ok, "OK"},
      {:ok, "OK"},
    ]

    query_pipeline2 = [
      ["GET", key1],
      ["GET", key2],
    ]
    resp2 = ExRedisPool.qp(:erpt2, query_pipeline2)
    assert resp2 == [
      {:ok, val1},
      {:ok, val2},
    ]

    query_pipeline3 = [
      ["DEL", key1],
      ["DEL", key2],
    ]
    resp3 = ExRedisPool.qp(:erpt2, query_pipeline3)
    assert resp3 == [
      {:ok, "1"},
      {:ok, "1"},
    ]
  end

  test "ExRedisPool.new/2 [start more than once process]" do
    pid1 = ExRedisPool.new(:erpt3)
    pid2 = ExRedisPool.new(:erpt4)
    pid3 = ExRedisPool.new(:erpt5)
  end

  test "ExRedisPool.q/2 [pid only]" do
    pid = ExRedisPool.new()
    assert is_pid(pid) == true
    key = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    {:ok, "OK"} = ExRedisPool.q(pid, ["SET", key, val])
    {:ok, result} = ExRedisPool.q(pid, ["GET", key])
    assert result == val
    {:ok, result} = ExRedisPool.q(pid, ["DEL", key])
    assert result == "1"
  end

  test "ExRedisPool.new/2 [start host localhost rather than 127.0.0.1]" do
    pid = ExRedisPool.new(host: "localhost")
    assert is_pid(pid) == true
    key = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    {:ok, "OK"} = ExRedisPool.q(pid, ["SET", key, val])
    {:ok, result} = ExRedisPool.q(pid, ["GET", key])
    assert result == val
    {:ok, result} = ExRedisPool.q(pid, ["DEL", key])
    assert result == "1"
  end

  test "ExRedisPool.start_client/2 [start host localhost rather than 127.0.0.1]" do
    {:ok, pid} = ExRedisPool.start_client(host: "localhost")
    assert is_pid(pid) == true
    key = "test_#{:crypto.rand_uniform(0, 1_000_000_000)}"
    val = "#{:crypto.rand_uniform(0, 1_000_000_000)}"
    {:ok, "OK"} = ExRedisPool.q(pid, ["SET", key, val])
    {:ok, result} = ExRedisPool.q(pid, ["GET", key])
    assert result == val
    {:ok, result} = ExRedisPool.q(pid, ["DEL", key])
    assert result == "1"
    :ok = ExRedisPool.stop_client(pid)
  end
end
