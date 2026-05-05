import Config

config :aura_log_web, AuraLogWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4_000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  secret_key_base: "dev-secret-key-base-dev-secret-key-base",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:aura_log_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:aura_log_web, ~w(--watch)]}
  ]

config :aura_log_web, AuraLogWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/aura_log_web/(controllers|live|components)/.*\.(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
