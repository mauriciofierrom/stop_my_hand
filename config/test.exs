import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :stop_my_hand, StopMyHand.Repo,
  username: System.get_env("POSTGRES_USER") || "mauricio",
  hostname: "localhost",
  database: "stop_my_hand_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :stop_my_hand, StopMyHandWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "7WD/n8yD9HY850bw9i5T1HtIX8AIbVaWU0c04a1sYWiP+N1wAzXGNzQEek50f9/9",
  server: false

# In test we don't send emails.
config :stop_my_hand, StopMyHand.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
