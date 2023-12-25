defmodule ShellyInfluxImporter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  require Logger

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShellyInfluxImporterWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:shelly_influx_importer, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ShellyInfluxImporter.PubSub},
      {Task.Supervisor, name: ShellyInfluxImporter.ShellyDeviceDataImportTaskSupervisor},
      # Start a worker by calling: ShellyInfluxImporter.Worker.start_link(arg)
      # {ShellyInfluxImporter.Worker, arg},
      {ShellyInfluxImporter.ConfigManager, []},
      setup_influx_db(),
      ShellyInfluxImporter.Scheduler,
      # Start to serve requests, typically the last entry
      ShellyInfluxImporterWeb.Endpoint,
      :systemd.ready()
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShellyInfluxImporter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShellyInfluxImporterWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def setup_influx_db() do
    {Task,
     fn ->
       Process.sleep(1000)
       Logger.info("Setup InfluxDB")
       ShellyInfluxImporter.Influx.setup()
     end}
  end
end
