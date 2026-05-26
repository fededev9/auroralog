defmodule AuraLogCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :aura_log,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      rustler_crates: [
        auralog_core: [
          path: "../../native/auralog_core",
          mode: if(Mix.env() == :prod, do: :release, else: :debug)
        ]
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AuraLog.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:broadway, "~> 1.1"},
      {:plug, "~> 1.15"},
      {:jason, "~> 1.4"},
      {:phoenix_pubsub, "~> 2.1"},
      {:rustler, "~> 0.36"},
      {:telemetry, "~> 1.3"},
      {:duckdb_ex, "~> 0.2.0"},
      {:joken, "~> 2.6"}
    ]
  end
end
