defmodule AuraLog.Parser.ServiceTest do
  use ExUnit.Case, async: true

  alias AuraLog.Parser.Service

  test "parse_batch returns rows and errors buckets" do
    input = [
      %{
        tenant: "default",
        source: "http",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        raw_line: ~s({"service":"api","message":"ok","status_code":200}),
        metadata: %{}
      }
    ]

    result = Service.parse_batch(input)
    assert is_list(result.rows)
    assert is_list(result.errors)
  end
end
