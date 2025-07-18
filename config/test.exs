import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
alias Swoosh.Adapters.Test

# In test we don't send emails
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :basenji, Basenji.Mailer, adapter: Test

config :basenji, Basenji.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "basenji_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  pool_size: System.schedulers_online() * 2

config :basenji, BasenjiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "IV8/00d3IZSFHI0pUEn407oWHstUv8Vmnwjz0oDuDr2iPElYYSmA4UpVNXLFbfQr",
  server: false

config :basenji, Oban, testing: :manual

config :basenji,
  comics_dir: "test/support/data/basenji/formats/",
  allow_delete_resources: false

config :ex_ftp,
  ftp_port: "FTP_PORT" |> System.get_env("4042") |> String.to_integer()

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
