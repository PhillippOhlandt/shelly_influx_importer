defmodule ShellyInfluxImporter.ShellyDeviceData do
  @moduledoc false

  alias ShellyInfluxImporter.ShellyDeviceInfo

  defstruct device_info: nil,
            raw_data: nil,
            flat_data: nil,
            timestamp: nil

  def fetch_data(%ShellyDeviceInfo{generation: 1} = device_info) do
    with {:ok, %Req.Response{status: 200, body: body}} <-
           Req.get(Path.join(device_info.address, "/status")) do
      device_data = %__MODULE__{
        device_info: device_info,
        raw_data: body,
        flat_data: flatten(body),
        timestamp: DateTime.now!("Etc/UTC")
      }

      {:ok, device_data}
    else
      {_, error} -> {:error, error}
    end
  end

  def fetch_data(%ShellyDeviceInfo{generation: 2} = device_info) do
    with {:ok, %Req.Response{status: 200, body: body}} <-
           Req.get(Path.join(device_info.address, "/rpc/Shelly.GetStatus")) do
      device_data = %__MODULE__{
        device_info: device_info,
        raw_data: body,
        flat_data: flatten(body),
        timestamp: DateTime.now!("Etc/UTC")
      }

      {:ok, device_data}
    else
      {_, error} -> {:error, error}
    end
  end

  def flatten(data) when is_map(data) do
    data
    |> Enum.map(fn {key, value} ->
      values = flatten(value)

      Enum.map(values, fn
        {child_key, value} -> {"#{key}.#{child_key}", value}
        value -> {"#{key}", value}
      end)
    end)
    |> List.flatten()
  end

  def flatten(list) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.map(fn {value, index} ->
      {index, value}
    end)
    |> Map.new()
    |> flatten()
  end

  def flatten(value), do: [value]
end
