defmodule AuraLog.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import AuraLog.DataCase
    end
  end

  setup tags do
    if tags[:clean_db] != false and duckdb_available?() do
      clean_database!()
    end

    :ok
  end

  def duckdb_available? do
    case AuraLog.Storage.DuckDBWriter.query_rows("SELECT 1 AS one", []) do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  catch
    :exit, _ -> false
    _, _ -> false
  end

  def clean_database! do
    for table <- ["log_terms", "logs_1m", "logs"] do
      AuraLog.Storage.DuckDBWriter.query_rows("DELETE FROM #{table}", [])
    end
  end

  def flush_writer!(timeout \\ 200) do
    Process.sleep(timeout)
  end

  def ingest_row!(raw, tenant \\ "test") do
    event = %{
      tenant: tenant,
      source: "test",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      raw_line: raw,
      metadata: %{}
    }

    AuraLog.Ingest.Dispatcher.dispatch(event)
    flush_writer!()
  end
end
