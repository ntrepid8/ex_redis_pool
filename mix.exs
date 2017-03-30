defmodule ExRedisPool.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_redis_pool,
     version: "0.2.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package(),

     # docs
     name: "ExRedisPool",
     source_url: "https://github.com/ntrepid8/ex_redis_pool",
     docs: [cannonical: "https://hexdocs.com/ex_redis_pool",
            extras: ["README.md", "CHANGELOG.md"]]
   ]
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
      {:ex_doc, "~> 0.14", only: :dev}
    ]
  end

  defp description do
    """
    Elixir Redis client with sync/async connection pools, sharding, and one-time hostname resolution.
    """
  end

  defp package do
    [name: :ex_redis_pool,
     files: ["lib", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md"],
     maintainers: ["Josh Austin"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/ntrepid8/ex_redis_pool"}]
  end
end
