defmodule ExCollision.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_collision,
      version: "1.0.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      name: "ExCollision",
      deps: deps(),
      description: "A library for server-side collisions, physics world simulation, tilemap pathfinding, and Tiled TMX parsing.",
      package: package(),
      source_url: "https://github.com/Valh88/ex_collision",
      docs: docs(),
    ]
  end

  defp package do
    [
      name: :ex_collision,
      files: ["lib", "mix.exs", "README.md", "data", "test"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Valh88/ex_collision"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExCollision.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:sweet_xml, "~> 0.7"}
    ]
  end
end
