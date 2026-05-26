{:ok, _} = Application.ensure_all_started(:aura_log)

exclude =
  if AuraLog.DataCase.duckdb_available?() do
    []
  else
    [duckdb: true]
  end

ExUnit.start(exclude: exclude)
