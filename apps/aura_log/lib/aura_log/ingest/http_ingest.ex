defmodule AuraLog.Ingest.HTTPIngest do
  @moduledoc """
  Plug endpoint for HTTP log ingestion.
  """
  use Plug.Router
  require Logger

  alias AuraLog.Ingest.Auth
  alias AuraLog.Ingest.Dispatcher
  alias AuraLog.Ingest.RateLimiter

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    length: Application.compile_env(:aura_log, :ingest_max_body_bytes, 1_000_000)
  )

  plug(:match)
  plug(:dispatch)

  post "/ingest" do
    case authorize_and_limit(conn) do
      {:ok, claims, tenant} ->
        body = conn.body_params
        event = normalize(body, "http", tenant, claims)
        Dispatcher.dispatch(event)
        send_resp(conn, 202, ~s({"status":"accepted"}))

      {:error, :unauthorized} ->
        send_resp(conn, 401, ~s({"error":"unauthorized"}))

      {:error, :forbidden} ->
        send_resp(conn, 403, ~s({"error":"forbidden"}))

      {:error, :rate_limited} ->
        send_resp(conn, 429, ~s({"error":"rate_limited"}))
    end
  end

  match _ do
    send_resp(conn, 404, ~s({"error":"not_found"}))
  end

  defp authorize_and_limit(conn) do
    with {:ok, claims, tenant} <- Auth.authorize(conn),
         token <- bearer_token(conn),
         ip <- conn_ip(conn),
         :ok <- RateLimiter.allow?(tenant, token, ip) do
      {:ok, claims, tenant}
    else
      {:error, reason} ->
        Logger.warning("Ingest auth/rate-limit rejected: #{inspect(reason)} ip=#{conn_ip(conn)}")
        {:error, reason}
    end
  end

  defp normalize(body, source, tenant, claims) do
    %{
      tenant: tenant,
      source: source,
      timestamp: Map.get(body, "timestamp", DateTime.utc_now() |> DateTime.to_iso8601()),
      raw_line: Map.get(body, "raw", ""),
      metadata:
        Map.merge(
          Map.get(body, "metadata", %{}),
          %{
            "auth_sub" => Map.get(claims, "sub"),
            "auth_tenant" => tenant
          }
        )
    }
  end

  defp bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> ""
    end
  end

  defp conn_ip(conn) do
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
  end
end
