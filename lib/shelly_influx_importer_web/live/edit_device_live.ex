defmodule ShellyInfluxImporterWeb.EditDeviceLive do
  use ShellyInfluxImporterWeb, :live_view

  alias ShellyInfluxImporter.Config
  alias ShellyInfluxImporter.Config.DeviceConfig
  alias ShellyInfluxImporter.ConfigManager
  alias ShellyInfluxImporter.ShellyDeviceInfo
  alias ShellyInfluxImporter.ShellyDeviceData
  alias ShellyInfluxImporterWeb.DeviceNotFoundError

  def render(assigns) do
    ~H"""
    <div class="mb-4 grid gap-4 grid-cols-[1fr_auto]">
      <h2 class="text-lg">Edit Device: <%= @device_info.name %></h2>
    </div>

    <div class="grid gap-4 md:grid-cols-[400px_1fr]">
      <div class="pb-4 md:pb-0 md:pr-4 border-zinc-100 border-b-2 md:border-b-0 md:border-r-2">
        <div class="grid gap-x-4 grid-cols-[auto_1fr] text-sm">
          <div>Device:</div>
          <div><%= @device_info.name %></div>

          <div>Mac:</div>
          <div><%= @device_info.mac %></div>

          <div>Type:</div>
          <div><%= @device_info.type %></div>

          <div>Generation:</div>
          <div><%= @device_info.generation %></div>
        </div>
      </div>

      <div>
        <%= case @device_data do %>
          <% %ShellyDeviceData{} -> %>
            <.form for={@device_config_form} phx-submit="submit_device_config">
              <div class="grid gap-4">
                <.input
                  type="select"
                  label="Update interval"
                  field={@device_config_form[:update_interval]}
                  options={@update_interval_options}
                />

                <.device_data_checkgroup
                  field={@device_config_form[:data]}
                  label="Data to collect"
                  options={@device_data.flat_data}
                />

                <.button>Save</.button>
              </div>
            </.form>
          <% _ -> %>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(params, _session, socket) do
    with {:ok, config} <- ConfigManager.get_config(),
         {:device_config, %Config.DeviceConfig{device_info: device_info} = device_config} <-
           {:device_config, find_device_config(config, params["mac"])},
         {:ok, device_data} <- ShellyDeviceData.fetch_data(device_info) do
      update_interval_options =
        [{"Default (#{Config.label_for_update_interval_option(config.update_interval)})", nil}] ++
          Config.update_interval_options()

      if connected?(socket) do
        Phoenix.PubSub.subscribe(
          ShellyInfluxImporter.PubSub,
          Config.DeviceConfig.pub_sub_topic(device_config)
        )
      end

      socket =
        socket
        |> assign(page_title: "Edit Device: #{device_info.name}}")
        |> assign(device_config_form: create_device_config_form(device_config))
        |> assign(update_interval_options: update_interval_options)
        |> assign(device_info: device_info)
        |> assign(device_data: device_data)

      {:ok, socket}
    else
      {:device_config, nil} ->
        raise DeviceNotFoundError

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Something went wrong while loading device data")
         |> redirect(to: ~p"/")}
    end
  end

  def handle_event(
        "submit_device_config",
        %{"update_interval" => update_interval, "data" => data},
        socket
      ) do
    update_interval = if update_interval == "", do: nil, else: update_interval
    data = Enum.filter(data, fn value -> value != "" end)

    device_config = %DeviceConfig{
      device_info: socket.assigns.device_info,
      update_interval: update_interval,
      data: data
    }

    :ok = ConfigManager.update_device_config(device_config)

    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_info({:update, %DeviceConfig{device_info: device_info} = device_config}, socket) do
    socket =
      socket
      |> assign(device_config_form: create_device_config_form(device_config))
      |> assign(device_info: device_info)

    {:noreply, socket}
  end

  def find_device_config(config, mac) do
    Enum.find(config.device_configs, fn device_config ->
      device_config.device_info.mac == mac
    end)
  end

  def create_device_config_form(%Config.DeviceConfig{} = device_config) do
    to_form(%{
      "update_interval" => device_config.update_interval,
      "data" => device_config.data
    })
  end
end
