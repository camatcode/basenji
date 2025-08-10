# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
alias Basenji.Worker.HourlyWorker
alias BasenjiWeb.FTP.ComicConnector
alias ExFTP.Auth.NoAuth
alias Swoosh.Adapters.Local

config :basenji, Basenji.Mailer, adapter: Local

config :basenji, Basenji.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: [host: System.get_env("GRAFANA_HOST", "http://localhost:3000")],
  metrics_server: :disabled

# Configures the endpoint
config :basenji, BasenjiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BasenjiWeb.ErrorHTML, json: BasenjiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Basenji.PubSub,
  live_view: [signing_salt: "Zg+rRITw"]

config :basenji, Oban,
  engine: Oban.Engines.Basic,
  queues: [comic: 15, comic_low: 5, collection: 25, schedule: 10],
  repo: Basenji.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: to_timeout(hour: 6)},
    {Oban.Plugins.Lifeline, rescue_after: to_timeout(hour: 1)},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", HourlyWorker, queue: :scheduled}
     ]},
    Oban.Plugins.Reindexer
  ]

config :basenji,
  ecto_repos: [Basenji.Repo],
  generators: [timestamp_type: :utc_datetime]

config :error_tracker,
  repo: Basenji.Repo,
  otp_app: :basenji,
  enabled: true

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  basenji: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure FTP interface
config :ex_ftp,
  server_name: :basenji,
  min_passive_port: "MIN_PASSIVE_PORT" |> System.get_env("41002") |> String.to_integer(),
  max_passive_port: "MAX_PASSIVE_PORT" |> System.get_env("42000") |> String.to_integer(),
  authenticator: NoAuth,
  authenticator_config: %{},
  storage_connector: ComicConnector

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :mime, :extensions, %{
  "json_api" => "application/vnd.api+json"
}

config :mime, :types, %{
  "application/vnd.api+json" => ["json_api"]
}

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  basenji: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),

    # Import environment specific config. This must remain at the bottom
    # of this file so it overrides the configuration defined above.
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
