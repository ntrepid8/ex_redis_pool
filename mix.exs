defmodule ExRedisPool.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_redis_pool,
     version: "0.0.2",
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
            extras: ["README.md"]]
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
      {:ex_doc, "~> 0.13", only: :dev}
    ]
  end

  defp description do
    """
    Elixir Redis client with connection pools and hostname resolution.
    """
  end

  defp package do
    [name: :ex_redis_pool,
     files: ["lib", "mix.exs", "README.md", "LICENSE"],
     maintainers: ["Josh Austin"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/ntrepid8/ex_redis_pool"}]
  end
end
