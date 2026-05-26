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

  test "returns 403 when tenant claim is missing" do
    opts = HTTPIngest.init([])

    token =
      mint_direct(%{
        "sub" => "no-tenant",
        "exp" => System.system_time(:second) + 600
      })

    conn =
      :post
      |> conn("/ingest", Jason.encode!(%{raw: "x"}))
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    conn = HTTPIngest.call(conn, opts)
    assert conn.status == 403
  end

  test "returns 429 when rate limited" do
    Application.put_env(:aura_log, :ingest_rate_limit_per_minute, 1)
    on_exit(fn -> Application.put_env(:aura_log, :ingest_rate_limit_per_minute, 3_000) end)

    opts = HTTPIngest.init([])
    body = Jason.encode!(%{raw: "service=test status_code=200 message=rate"})
    token = jwt(%{"sub" => "rate-limit-subject", "tenant" => "rate-limit-tenant"})

    conn1 =
      :post
      |> conn("/ingest", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    assert HTTPIngest.call(conn1, opts).status == 202

    conn2 =
      :post
      |> conn("/ingest", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    assert HTTPIngest.call(conn2, opts).status == 429
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

  defp jwt(extra \\ %{}) do
    mint_direct(
      Map.merge(
        %{
          "sub" => "http-ingest-test",
          "tenant" => "demo",
          "exp" => System.system_time(:second) + 600
        },
        extra
      )
    )
  end

  defp mint_direct(claims) do
    secret = Application.fetch_env!(:aura_log, :ingest_jwt_secret)
    signer = Joken.Signer.create("HS256", secret)
    {:ok, token, _} = Joken.encode_and_sign(claims, signer)
    token
  end
end
