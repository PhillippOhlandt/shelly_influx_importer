defmodule ShellyInfluxImporter.ShellyDeviceInfo do
  @moduledoc false

  @derive {Phoenix.Param, key: :mac}
  @derive Jason.Encoder
  defstruct name: nil,
            address: nil,
            mac: nil,
            type: nil,
            generation: nil

  def new(data) when is_map(data) do
    %__MODULE__{
      name: data["name"] || data[:name],
      address: data["address"] || data[:address],
      mac: data["mac"] || data[:mac],
      type: data["type"] || data[:type],
      generation: data["generation"] || data[:generation]
    }
  end

  def changed?(%__MODULE__{} = info1, %__MODULE__{} = info2) do
    !(info1.name == info2.name &&
        info1.address == info2.address &&
        info1.mac == info2.mac &&
        info1.type == info2.type &&
        info1.generation == info2.generation)
  end

  def fetch_info(address) do
    with {:ok, info} <- fetch_gen1_info(address) do
      {:ok, info}
    else
      _ -> fetch_gen2_info(address)
    end
  end

  defp fetch_gen1_info(address) do
    with {:ok, %Req.Response{status: 200, body: body}} <- Req.get(Path.join(address, "/settings")) do
      info = %__MODULE__{
        name: body["name"] || body["device"]["hostnames"] || "",
        address: address,
        mac: body["device"]["mac"],
        type: body["device"]["type"],
        generation: 1
      }

      {:ok, info}
    else
      {_, error} -> {:error, error}
    end
  end

  defp fetch_gen2_info(address) do
    with {:ok, %Req.Response{status: 200, body: body}} <-
           Req.get(Path.join(address, "/rpc/Shelly.GetDeviceInfo")) do
      info = %__MODULE__{
        name: body["name"] || body["id"] || "",
        address: address,
        mac: body["mac"],
        type: body["app"],
        generation: 2
      }

      {:ok, info}
    else
      {_, error} -> {:error, error}
    end
  end
end
