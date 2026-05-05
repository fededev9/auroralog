defmodule AuraLogCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :aura_log,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.16",
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
