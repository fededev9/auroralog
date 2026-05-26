defmodule AuraLog.Storage.WriterTest do
  use AuraLog.DataCase, async: false

  @moduletag :duckdb

  alias AuraLog.Query.Service
  alias AuraLog.Storage.DuckDBWriter

  test "persists logs, log_terms, and logs_1m rollup" do
    ingest_row!(
      ~s({"service":"api","message":"hello searchterm","status_code":404}),
      "tenant-a"
    )

    assert {:ok, [%{"total" => total}]} =
             DuckDBWriter.query_rows("SELECT count(*)::BIGINT AS total FROM logs", [])

    assert total >= 1

    assert {:ok, terms} =
             DuckDBWriter.query_rows(
               "SELECT term FROM log_terms WHERE term = 'searchterm'",
               []
             )

    assert length(terms) >= 1

    assert {:ok, [%{"events" => events}]} =
             DuckDBWriter.query_rows("SELECT sum(events)::BIGINT AS events FROM logs_1m", [])

    assert events >= 1

    results = Service.search("searchterm")
    assert length(results) >= 1
    assert hd(results)["service"] == "api"
  end

  test "rollup-backed throughput uses logs_1m when populated" do
    ingest_row!(~s({"service":"api","message":"ok","status_code":200}), "tenant-a")

    snapshot = Service.throughput(60)
    assert snapshot.total >= 1
  end
end
