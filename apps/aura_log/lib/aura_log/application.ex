defmodule AuraLog.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Registry, keys: :duplicate, name: AuraLog.Registry},
        {Phoenix.PubSub, name: AuraLog.PubSub},
        {Task.Supervisor, name: AuraLog.Parser.TaskSupervisor},
        AuraLog.Metrics.RuntimeCounters,
        AuraLog.Ingest.RateLimiter,
        AuraLog.Storage.DuckDBWriter
      ] ++ maybe_udp_listener() ++ [AuraLog.Ingest.Dispatcher]

    Supervisor.start_link(children, strategy: :one_for_one, name: AuraLog.Supervisor)
  end

  defp maybe_udp_listener do
    if Application.get_env(:aura_log, :start_udp_listener, true) do
      [AuraLog.Ingest.UDPListener]
    else
      []
    end
  end
end
