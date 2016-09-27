defmodule ExRedisPool.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_redis_pool,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package()]
  end

  def application do
    [applications: [
      :eredis,
      :logger,
      :poolboy,
      ],
     mod: {ExRedisPool, []}]
  end

  defp deps do
    [
      {:eredis, "~> 1.0"},
      {:poolboy, "~> 1.5"},
    ]
  end

  defp description do
    """
    Elixir Redis client with connection pools and hostname resolution.
    """
  end

  defp package do
    [name: :ex_redis_pool,
     files: ["lib", "priv", "mix.exs", "README.md", "LICENSE"],
     maintainers: ["Josh Austin"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/ntrepid8/ex_redis_pool"}]
  end
end
