defmodule ShellyInfluxImporter.Config do
  @moduledoc false

  alias ShellyInfluxImporter.Config.DeviceConfig

  @derive Jason.Encoder
  defstruct update_interval: "* * * * *",
            device_configs: []

  def new() do
    %__MODULE__{}
  end

  def new(data) do
    %__MODULE__{
      update_interval: data["update_interval"] || data[:update_interval],
      device_configs: DeviceConfig.new(data["device_configs"] || data[:device_configs])
    }
  end

  def set_update_interval(%__MODULE__{} = config, update_interval) do
    {:ok, %__MODULE__{config | update_interval: update_interval}}
  end

  def add_device_config(%__MODULE__{} = config, device_config) do
    exists =
      Enum.any?(config.device_configs, fn c ->
        c.device_info.mac == device_config.device_info.mac
      end)

    case exists do
      true ->
        {:error, "Device exists already"}

      false ->
        device_configs = config.device_configs ++ [device_config]

        {:ok, %__MODULE__{config | device_configs: device_configs}}
    end
  end

  def update_device_config(%__MODULE__{} = config, device_config) do
    device_configs =
      config.device_configs
      |> Enum.map(fn c ->
        case c.device_info.mac == device_config.device_info.mac do
          false -> c
          true -> device_config
        end
      end)

    {:ok, %__MODULE__{config | device_configs: device_configs}}
  end

  def delete_device_config(%__MODULE__{} = config, %DeviceConfig{} = device_config) do
    delete_device_config(config, device_config.device_info.mac)
  end

  def delete_device_config(%__MODULE__{} = config, mac) do
    found_config =
      Enum.find(config.device_configs, fn c ->
        c.device_info.mac == mac
      end)

    case found_config do
      nil ->
        {:error, "Device not found"}

      %DeviceConfig{} = device_config ->
        device_configs =
          config.device_configs
          |> Enum.filter(fn c ->
            c.device_info.mac != device_config.device_info.mac
          end)

        {:ok, %__MODULE__{config | device_configs: device_configs}, device_config}
    end
  end

  def update_interval_options() do
    [
      "* * * * *",
      "*/2 * * * *",
      "*/3 * * * *",
      "*/4 * * * *",
      "*/5 * * * *",
      "*/10 * * * *",
      "*/30 * * * *",
      "0 * * * *"
    ]
    |> Enum.map(fn value -> {label_for_update_interval_option(value), value} end)
  end

  def label_for_update_interval_option(value) do
    case value do
      "* * * * *" -> "Every minute"
      "*/2 * * * *" -> "Every 2 minutes"
      "*/3 * * * *" -> "Every 3 minutes"
      "*/4 * * * *" -> "Every 4 minutes"
      "*/5 * * * *" -> "Every 5 minutes"
      "*/10 * * * *" -> "Every 10 minutes"
      "*/30 * * * *" -> "Every 30 minutes"
      "0 * * * *" -> "Every hour"
      value -> value
    end
  end

  def pub_sub_topic() do
    "config"
  end

  def pub_sub_topic(field) do
    "config:#{field}"
  end
end
