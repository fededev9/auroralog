defmodule AuraLog.Ingest.HTTPIngestTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias AuraLog.Ingest.HTTPIngest

  test "returns 202 with valid JWT" do
    opts = HTTPIngest.init([])

    conn =
      :post
      |> conn("/ingest", Jason.encode!(%{raw: "service=test status_code=200 message=hello"}))
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{jwt()}")

    conn = HTTPIngest.call(conn, opts)
    assert conn.status == 202
  end

  test "returns 401 without authorization" do
    opts = HTTPIngest.init([])

    conn =
      :post
      |> conn("/ingest", Jason.encode!(%{raw: "x"}))
      |> put_req_header("content-type", "application/json")

    conn = HTTPIngest.call(conn, opts)
    assert conn.status == 401
  end

  defp jwt do
    secret = Application.fetch_env!(:aura_log, :ingest_jwt_secret)
    signer = Joken.Signer.create("HS256", secret)

    claims = %{
      "sub" => "http-ingest-test",
      "tenant" => "demo",
      "exp" => System.system_time(:second) + 600
    }

    {:ok, token, _} = Joken.encode_and_sign(claims, signer)
    token
  end
end
