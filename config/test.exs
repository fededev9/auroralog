import Config

config :aura_log_web, AuraLogWeb.Endpoint,
  server: false,
  secret_key_base: "test-secret-key-base-test-secret-key-base"

config :aura_log,
  ingest_jwt_secret: "test-jwt-secret-for-ci",
  start_udp_listener: false

config :aura_log, AuraLog.Storage.DuckDBWriter,
  database_path: Path.join(System.tmp_dir!(), "auralog_test.duckdb")

config :phoenix_live_view, :colocated_js, disable_symlink_warning: true
