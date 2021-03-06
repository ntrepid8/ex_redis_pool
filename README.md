# ExRedisPool

A Elixir Redis client with connection pools.

[![Build Status](https://travis-ci.org/ntrepid8/ex_redis_pool.svg?branch=master)](https://travis-ci.org/ntrepid8/ex_redis_pool)

## Features

ExRedisPool implements several features with a slightly different twist than
other Erlang/Elixir Redis clients.

## Dual Connection Pools

ExRedisPool supports two worker pools per process, one for synchronous queries
and another for asynchronous queries. The goal is to provide high quality of
service for calls that are waiting on a response, but also provide high
throughput when a response is not needed immediately.

By varying the size of the two work pools a relative throttle can be placed on the
asynchronous requests.

## Hostname Resolution on Startup

By default some Redis clients resolve the DNS name of your Redis host every time they
attempt to connect. In certain situations this DNS resolution can become a bottleneck
and it's better to resolve names into IP addresses when the work pools start up,
and only resolve them at that time.

An added benefit is that if you want to switch over to a new Redis host, you can control
the exact timing of the switch-over by restarting the ExRedisPool process.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add ex_redis_pool to your list of dependencies in `mix.exs`:

        def deps do
          [{:ex_redis_pool, "~> 0.1.1"}]
        end

  2. Ensure ex_redis_pool is started before your application:

        def application do
          [applications: [:ex_redis_pool]]
        end

## Usage

Start a new connection to the default Redis instance on localhost with a name:

```elixir
iex(1)> pid = ExRedisPool.new(:redis_pool)
```

Or start a new connection to the default Redis instance on localhost without a name, just using the pid:

```elixir
iex(2)> pid = ExRedisPool.new()
```

Either the pid or the atom name can be used to reference the connection.

### query

Using the pid from one of the new connections from above:

```elixir
iex(3)> {:ok, "OK"} = ExRedisPool.q(pid, ["SET", "chuck", "norris"])
iex(4)> ExRedisPool.q(pid, ["GET", "chuck"])
"norris"
```

### query noreply

Using the pid from one of the new connections from above:

```elixir
iex(5)> :ok = ExRedisPool.q_noreply(pid, ["SET", "chuck", "norris"])
iex(7)> :timer.sleep(100)
iex(8)> ExRedisPool.q(pid, ["GET", "chuck"])
"norris"
```

### query pipeline

Using the pid from one of the new connections from above:

```elixir
iex(9)> [{:ok, "OK"}, {:ok, "OK"}] = ExRedisPool.qp(pid, [["SET", "chuck", "norris"], ["SET", "afraid", "nope"]])
iex(10)> ExRedisPool.q(pid, ["GET", "chuck"])
"norris"
iex(11)> ExRedisPool.q(pid, ["GET", "afraid"])
"nope"
```

### query pipeline noreply

Using the pid from one of the new connections from above:

```elixir
iex(12)> :ok = ExRedisPool.qp_noreply(pid, [["SET", "chuck", "norris"], ["SET", "afraid", "nope"]])
iex(13)> :timer.sleep(100)
iex(14)> ExRedisPool.q(pid, ["GET", "chuck"])
"norris"
iex(15)> ExRedisPool.q(pid, ["GET", "afraid"])
"nope"
```

## Sharded Pools

Shard mapping was added in version `0.1.0`. Redis is single threaded, and using more than one
instance of Redis can be important for performance in some contexts. The `Shard` module will
help construct several connection pools, each able to take their own connection options. Then
queries are mapped to the appropriate shard based on the given `shard_key` like this:

```elixir
iex(1)> shard_opts_list = [[database: 10], [database: 11], [database: 12], [database: 13]]
[[database: 10], [database: 11], [database: 12], [database: 13]]
iex(2)> pid = ExRedisPool.Shard.new(shard_opts_list)
#PID<0.575.0>
iex(3)> ExRedisPool.Shard.q(pid, ["SET", "chuck", "norris"], "texas")
{:ok, "OK"}
iex(4)> ExRedisPool.Shard.q(pid, ["GET", "chuck"], "texas")
{:ok, "norris"}
```

In the above example our workload will be mapped onto the 4 instances of Redis we supplied
connection options for.

Note: in this example and in our tests we create shards by using a different database in the same
Redis instance. This allows us to simulate sharding for tests, but you will likely want to run
several Redis instances, perhaps on different ports or even different hosts to get the best performance.

Also, if we try to query with a different `shard_key` it's possible the query will
map to another shard. It's important to have a sound shard key strategy before attempting
to shard your Redis cluster.

```elixir
iex(6)> ExRedisPool.Shard.q(pid, ["GET", "chuck"], "oklahoma")  
{:ok, :undefined}
```

## TODO

- add read-only backup connections for fail-over
