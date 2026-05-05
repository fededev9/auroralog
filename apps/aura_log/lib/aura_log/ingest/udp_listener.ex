defmodule AuraLog.Ingest.UDPListener do
  @moduledoc """
  UDP ingestion listener for high-throughput fire-and-forget log shipping.
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
    event = %{
      tenant: "default",
      source: "udp",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      raw_line: payload,
      metadata: %{ip: :inet.ntoa(ip) |> to_string()}
    }

    Dispatcher.dispatch(event)
    {:noreply, state}
  end
end
