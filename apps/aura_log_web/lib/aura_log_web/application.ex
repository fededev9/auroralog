defmodule AuraLogWeb.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    {:ok, _} = Application.ensure_all_started(:aura_log)

    children = [
      AuraLogWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: AuraLogWeb.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AuraLogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
