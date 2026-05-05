defmodule AuraLog.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  defp releases do
    [
      auralog: [
        applications: [
          aura_log: :permanent,
          aura_log_web: :permanent
        ]
      ]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.36"}
    ]
  end
end
