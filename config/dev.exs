import Config

config :aura_log_web, AuraLogWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4_000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  secret_key_base: "dev-secret-key-base-dev-secret-key-base",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:aura_log_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:aura_log_web, ~w(--watch)]}
  ]

config :aura_log_web, AuraLogWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/aura_log_web/(controllers|live|components)/.*\.(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

udp_ingest_enabled? =
  case System.get_env("AURALOG_UDP_INGEST_ENABLED", "true")
       |> String.trim()
       |> String.downcase() do
    "0" -> false
    "false" -> false
    "no" -> false
    _ -> true
  end

config :aura_log, :start_udp_listener, udp_ingest_enabled?

config :aura_log, AuraLog.Storage.DuckDBWriter,
  database_path:
    System.get_env("AURALOG_DUCKDB_PATH") ||
      Path.expand("../priv/data/auralog.duckdb", __DIR__)

config :phoenix_live_view, :colocated_js, disable_symlink_warning: true

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
