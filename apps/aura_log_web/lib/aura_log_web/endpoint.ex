defmodule AuraLogWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :aura_log_web

  @session_options [
    store: :cookie,
    key: "_aura_log_web_key",
    signing_salt: "auralog-signing-salt",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]
  )

  plug(Plug.Static,
    at: "/",
    from: :aura_log_web,
    gzip: not code_reloading?,
    only: AuraLogWeb.static_paths(),
    raise_on_missing_only: code_reloading?
  )

  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    length: Application.compile_env(:aura_log, :ingest_max_body_bytes, 1_000_000)
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(AuraLogWeb.Router)
end
