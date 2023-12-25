defmodule ShellyInfluxImporterWeb.DeviceNotFoundError do
  defexception message: "Device not found", plug_status: 404
end
