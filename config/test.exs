import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :shelly_influx_importer, ShellyInfluxImporterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "qvpeCNsoewyzI/4AsAfHDzHCS9Ax6Gwi/NlySX/OOkqt6n+EhqMJCo7GPY2ulPHg",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
