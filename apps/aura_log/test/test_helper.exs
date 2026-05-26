test_db =
  Application.fetch_env!(:aura_log, AuraLog.Storage.DuckDBWriter)[:database_path]

File.rm(test_db)

duckdb_cli = Path.expand("priv/duckdb/duckdb", File.cwd!())

if File.exists?(duckdb_cli) do
  :ok
else
  IO.warn("DuckDB CLI missing at #{duckdb_cli}; run: mix duckdb_ex.install")
end

{:ok, _} = Application.ensure_all_started(:aura_log)

exclude =
  if AuraLog.DataCase.duckdb_available?() do
    []
  else
    [duckdb: true]
  end

ExUnit.start(exclude: exclude)
