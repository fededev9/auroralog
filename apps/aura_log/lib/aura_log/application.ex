defmodule AuraLog.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: AuraLog.Registry},
      {Phoenix.PubSub, name: AuraLog.PubSub},
      {Task.Supervisor, name: AuraLog.Parser.TaskSupervisor},
      AuraLog.Metrics.RuntimeCounters,
      AuraLog.Search.TokenIndex,
      AuraLog.Ingest.RateLimiter,
      AuraLog.Storage.DuckDBWriter,
      AuraLog.Ingest.UDPListener,
      AuraLog.Ingest.Dispatcher
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: AuraLog.Supervisor)
  end
end
