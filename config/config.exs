import Config

config :aura_log,
  ecto_repos: [],
  parser_batch_size: 1_000,
  udp_port: 9_000,
  ingest_http_port: 4_000,
  ingest_max_body_bytes: 1_000_000,
  ingest_rate_limit_per_minute: 3_000,
  ingest_jwt_secret: System.get_env("AURALOG_INGEST_JWT_SECRET", "dev-jwt-secret-change-me")

config :aura_log, AuraLog.Storage.DuckDBWriter,
  flush_interval_ms: 2_000,
  max_batch_size: 1_000

config :aura_log_web, AuraLogWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: AuraLogWeb.ErrorHTML, json: AuraLogWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AuraLog.PubSub,
  live_view: [signing_salt: "aura-log-salt"]

config :esbuild,
  version: "0.25.4",
  aura_log_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/aura_log_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.1.12",
  aura_log_web: [
    args: ~w(--input=assets/css/app.css --output=priv/static/assets/css/app.css),
    cd: Path.expand("../apps/aura_log_web", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
