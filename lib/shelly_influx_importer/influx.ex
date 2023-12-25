defmodule ShellyInfluxImporter.Influx do
  def setup() do
    :ok = InfluxDB.query(config(), "create database smart_home")
  end

  def config() do
    host = Keyword.get(Application.get_env(:shelly_influx_importer, __MODULE__), :host)

    InfluxDB.Config.new(%{host: host})
  end

  def database() do
    Map.put(config(), :database, ~c"smart_home")
  end
end
