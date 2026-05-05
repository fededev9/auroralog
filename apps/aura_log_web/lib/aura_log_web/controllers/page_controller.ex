defmodule AuraLogWeb.PageController do
  use AuraLogWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: "/dashboard")
  end
end
