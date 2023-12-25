defmodule ShellyInfluxImporter.ShellyDeviceDataImport do
  alias ShellyInfluxImporter.Config.DeviceConfig
  alias ShellyInfluxImporter.ConfigManager
  alias ShellyInfluxImporter.ShellyDeviceDataImportTaskSupervisor
  alias ShellyInfluxImporter.ShellyDeviceInfo
  alias ShellyInfluxImporter.ShellyDeviceData
  alias ShellyInfluxImporter.Influx

  def run() do
    now = DateTime.now!("Etc/UTC")
    {:ok, config} = ConfigManager.get_config()

    device_configs =
      Enum.filter(config.device_configs, fn device_config ->
        interval = device_config.update_interval || config.update_interval
        Cron.match?(Cron.new!(interval), now)
      end)

    Task.Supervisor.async_stream_nolink(
      ShellyDeviceDataImportTaskSupervisor,
      device_configs,
      __MODULE__,
      :import,
      [],
      max_concurrency: 10
    )
    |> Enum.to_list()
  end

  def import(%DeviceConfig{} = device_config) do
    {:ok, device_info} = ShellyDeviceInfo.fetch_info(device_config.device_info.address)
    {:ok, device_data} = ShellyDeviceData.fetch_data(device_info)

    if ShellyDeviceInfo.changed?(device_config.device_info, device_info) do
      new_device_config = %DeviceConfig{device_config | device_info: device_info}
      :ok = ConfigManager.update_device_config(new_device_config)
    end

    data = Enum.filter(device_data.flat_data, fn {name, _} -> name in device_config.data end)

    data_tuples =
      Enum.map(data, fn {name, value} ->
        tags = %{
          "device_name" => device_info.name,
          "device_address" => device_info.address,
          "device_mac" => device_info.mac,
          "device_type" => device_info.type,
          "device_generation" => to_string(device_info.generation),
          "data_point" => name
        }

        value_key = value_key(value)

        fields = %{
          value_key => value
        }

        timestamp = DateTime.to_unix(device_data.timestamp) * 1_000_000_000

        {"shelly_devices", tags, fields, timestamp}
      end)

    :ok = InfluxDB.write(Influx.database(), data_tuples)

    :ok
  end

  def value_key(value) when is_integer(value), do: "value_integer"
  def value_key(value) when is_float(value), do: "value_float"
  def value_key(value) when is_binary(value), do: "value_string"
  def value_key(value) when is_boolean(value), do: "value_boolean"
end
