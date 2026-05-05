defmodule AuraLogWeb.HealthController do
  use AuraLogWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok", at: DateTime.utc_now()})
  end
end
