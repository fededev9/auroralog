test_db =
  Application.fetch_env!(:aura_log, AuraLog.Storage.DuckDBWriter)[:database_path]

File.rm(test_db)

duckdb_cli =
  System.get_env("DUCKDB_PATH") ||
    Application.get_env(:duckdb_ex, :duckdb_path) ||
    Path.expand("priv/duckdb/duckdb", File.cwd!())

unless File.exists?(duckdb_cli) do
  IO.warn("""
  DuckDB CLI missing at #{duckdb_cli}.
  Install: chmod +x infra/scripts/install_duckdb_cli.sh && ./infra/scripts/install_duckdb_cli.sh priv/duckdb
  """)
end

{:ok, _} = Application.ensure_all_started(:aura_log)

exclude =
  if AuraLog.DataCase.duckdb_available?() do
    []
  else
    [duckdb: true]
  end

ExUnit.start(exclude: exclude)
