defmodule AuraLogWeb.Router do
  use AuraLogWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AuraLogWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/" do
    pipe_through(:api)
    get("/health", AuraLogWeb.HealthController, :show)
    forward("/api", AuraLog.Ingest.HTTPIngest)
  end

  scope "/", AuraLogWeb do
    pipe_through(:browser)
    get("/", PageController, :home)

    live_session :default do
      live("/dashboard", DashboardLive)
    end
  end
end
