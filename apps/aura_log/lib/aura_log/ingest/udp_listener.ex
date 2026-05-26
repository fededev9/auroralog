defmodule AuraLog.Ingest.UDPListener do
  @moduledoc """
  UDP ingestion listener for fire-and-forget log shipping.

  When `AURALOG_UDP_INGEST_TOKEN` is set, payloads must be JSON:

      {"token":"<secret>","tenant":"<tenant>","raw":"<log line>"}

  Without a token (local dev only), plain-text payloads are accepted on the default tenant.
  """
  use GenServer
  require Logger

  alias AuraLog.Ingest.Dispatcher

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    port = Application.get_env(:aura_log, :udp_port, 9_000)

    case :gen_udp.open(port, [:binary, active: true, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("AuraLog UDP listener started on #{port}")
        {:ok, Map.put(state, :socket, socket)}

      {:error, reason} ->
        Logger.error("Failed to start UDP listener: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info({:udp, _socket, ip, _port, payload}, state) do
    case decode_payload(payload, format_ip(ip)) do
      {:ok, event} ->
        Dispatcher.dispatch(event)

      {:error, reason} ->
        Logger.warning("UDP ingest rejected from #{format_ip(ip)}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  defp decode_payload(payload, client_ip) when is_binary(payload) do
    trimmed = String.trim(payload)

    cond do
      String.starts_with?(trimmed, "{") ->
        decode_json_payload(trimmed, client_ip)

      token_required?() ->
        {:error, :token_required}

      true ->
        {:ok, build_event(trimmed, "default", %{"ip" => client_ip})}
    end
  end

  defp decode_json_payload(json, client_ip) do
    case Jason.decode(json) do
      {:ok, %{"token" => token, "tenant" => tenant, "raw" => raw}}
      when is_binary(token) and is_binary(tenant) and is_binary(raw) ->
        with :ok <- verify_token(token),
             true <- tenant != "" do
          {:ok, build_event(raw, tenant, %{"ip" => client_ip, "udp_auth" => "token"})}
        else
          :error -> {:error, :invalid_token}
          false -> {:error, :missing_tenant}
        end

      {:ok, _} ->
        {:error, :invalid_payload}

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  defp build_event(raw_line, tenant, metadata) do
    %{
      tenant: tenant,
      source: "udp",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      raw_line: raw_line,
      metadata: metadata
    }
  end

  defp verify_token(token) do
    expected = Application.get_env(:aura_log, :udp_ingest_token)

    cond do
      is_nil(expected) or expected == "" ->
        if token_required?(), do: :error, else: :ok

      Plug.Crypto.secure_compare(token, expected) ->
        :ok

      true ->
        :error
    end
  end

  defp token_required? do
    case Application.get_env(:aura_log, :udp_ingest_token) do
      secret when is_binary(secret) and secret != "" -> true
      _ -> Application.get_env(:aura_log, :udp_ingest_token_required, false)
    end
  end

  defp format_ip(ip), do: ip |> :inet.ntoa() |> to_string()
end
