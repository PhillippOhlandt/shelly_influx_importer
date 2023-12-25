defmodule ShellyInfluxImporter.Config.DeviceConfig do
  alias ShellyInfluxImporter.ShellyDeviceInfo

  @derive Jason.Encoder
  defstruct device_info: nil,
            update_interval: nil,
            data: []

  def new(data) when is_map(data) do
    %__MODULE__{
      device_info: ShellyDeviceInfo.new(data["device_info"] || data[:device_info]),
      update_interval: data["update_interval"] || data[:update_interval],
      data: data["data"] || data[:data] || []
    }
  end

  def new(items) when is_list(items) do
    Enum.map(items, &new/1)
  end

  def pub_sub_topic() do
    "device_config"
  end

  def pub_sub_topic(%__MODULE__{} = dc) do
    "device_config:#{dc.device_info.mac}"
  end
end
