defmodule AuraLog.Query.ServiceTest do
  use AuraLog.DataCase, async: false

  @moduletag :duckdb

  alias AuraLog.Query.Service

  test "multi-term search requires all terms" do
    ingest_row!(~s({"service":"billing","message":"invoice paid","status_code":200}))
    ingest_row!(~s({"service":"auth","message":"login failed","status_code":401}))

    assert [] = Service.search("invoice login")
    assert length(Service.search("invoice paid")) >= 1
  end
end
