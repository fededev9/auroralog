import Config

config :aura_log_web, AuraLogWeb.Endpoint,
  server: false,
  secret_key_base: String.duplicate("t", 64)

config :aura_log,
  ingest_jwt_secret: "test-jwt-secret-for-ci",
  start_udp_listener: false

test_db =
  Path.join(System.tmp_dir!(), "auralog_test_#{System.system_time(:second)}.duckdb")

config :duckdb_ex,
  duckdb_path: Path.expand("priv/duckdb/duckdb", File.cwd!())

config :aura_log, AuraLog.Storage.DuckDBWriter,
  database_path: test_db,
  flush_interval_ms: 50

config :phoenix_live_view, :colocated_js, disable_symlink_warning: true
