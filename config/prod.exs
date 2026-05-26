import Config

config :aura_log, AuraLog.Storage.DuckDBWriter,
  database_path: System.get_env("AURALOG_DUCKDB_PATH", "/data/auralog.duckdb")

config :aura_log_web, AuraLogWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true
