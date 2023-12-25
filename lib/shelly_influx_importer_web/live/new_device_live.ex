defmodule ShellyInfluxImporterWeb.NewDeviceLive do
  use ShellyInfluxImporterWeb, :live_view

  alias ShellyInfluxImporter.Config
  alias ShellyInfluxImporter.Config.DeviceConfig
  alias ShellyInfluxImporter.ConfigManager
  alias ShellyInfluxImporter.ShellyDeviceInfo
  alias ShellyInfluxImporter.ShellyDeviceData

  @address_form_fields %{
    "address" => ""
  }

  @device_config_form_fields %{
    "update_interval" => nil,
    "data" => []
  }

  def render(assigns) do
    ~H"""
    <div class="mb-4 grid gap-4 grid-cols-[1fr_auto]">
      <h2 class="text-lg">New Device</h2>
    </div>

    <div class="grid gap-4 md:grid-cols-[400px_1fr]">
      <div class="pb-4 md:pb-0 md:pr-4 border-zinc-100 border-b-2 md:border-b-0 md:border-r-2">
        <div>
          <.form for={@address_form} phx-submit="submit_address">
            <div class="grid gap-4 grid-cols-[1fr_auto] items-start">
              <.input type="text" field={@address_form[:address]} placeholder="http://..." />
              <.button class="py-2 mt-2">Connect</.button>
            </div>
          </.form>
        </div>

        <div class="mt-4">
          <%= case @device_info do %>
            <% :loading -> %>
              <div>
                <.icon name="hero-arrow-path" class="h-4 w-4 mb-0.5 animate-spin" />
                Loading device info ...
              </div>
            <% %ShellyDeviceInfo{} -> %>
              <div class="text-green-700">
                <.icon name="hero-check-circle" class="h-4 w-4 mb-0.5" /> Device info loaded
              </div>
            <% {:error, reason} -> %>
              <div class="text-rose-700">
                <.icon name="hero-exclamation-circle" class="h-4 w-4 mb-0.5" />
                Device info could not be loaded. Reason: <%= inspect(reason) %>
              </div>
            <% _ -> %>
          <% end %>

          <div :if={@device_unique == false} class="text-rose-700">
            <.icon name="hero-exclamation-circle" class="h-4 w-4 mb-0.5" /> Device was already added
          </div>

          <%= case @device_data do %>
            <% :loading -> %>
              <div>
                <.icon name="hero-arrow-path" class="h-4 w-4 mb-0.5 animate-spin" />
                Loading device data ...
              </div>
            <% %ShellyDeviceData{} -> %>
              <div class="text-green-700">
                <.icon name="hero-check-circle" class="h-4 w-4 mb-0.5" /> Device data loaded
              </div>

              <div class="mt-4 pt-4 grid gap-x-4 grid-cols-[auto_1fr] text-sm border-zinc-100 border-t-2">
                <div>Device:</div>
                <div><%= @device_info.name %></div>

                <div>Mac:</div>
                <div><%= @device_info.mac %></div>

                <div>Type:</div>
                <div><%= @device_info.type %></div>

                <div>Generation:</div>
                <div><%= @device_info.generation %></div>
              </div>
            <% {:error, reason} -> %>
              <div class="text-rose-700">
                <.icon name="hero-exclamation-circle" class="h-4 w-4 mb-0.5" />
                Device data could not be loaded. Reason: <%= inspect(reason) %>
              </div>
            <% _ -> %>
          <% end %>
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

  def mount(_params, _session, socket) do
    {:ok, config} = ConfigManager.get_config()

    update_interval_options =
      [{"Default (#{Config.label_for_update_interval_option(config.update_interval)})", nil}] ++
        Config.update_interval_options()

    socket =
      socket
      |> assign(page_title: "New Device")
      |> assign(address_form: to_form(@address_form_fields))
      |> assign(device_config_form: to_form(@device_config_form_fields))
      |> assign(update_interval_options: update_interval_options)
      |> assign(device_info: nil)
      |> assign(device_unique: nil)
      |> assign(device_data: nil)

    {:ok, socket}
  end

  def handle_event("submit_address", %{"address" => address} = params, socket) do
    with {:not_empty, address} when address not in [nil, ""] <- {:not_empty, address},
         uri <- URI.parse(address),
         {:url_scheme, true} <- {:url_scheme, uri.scheme != nil && uri.host != nil} do
      load_device_info(address)

      socket =
        socket
        |> assign(address_form: to_form(params))
        |> assign(device_info: :loading)
        |> assign(device_unique: nil)
        |> assign(device_data: nil)

      {:noreply, socket}
    else
      {:not_empty, _} ->
        address_form = to_form(params, errors: [address: {"Can't be blank", []}])

        socket =
          socket
          |> assign(address_form: address_form)
          |> assign(device_info: nil)
          |> assign(device_unique: nil)
          |> assign(device_data: nil)

        {:noreply, socket}

      {:url_scheme, _} ->
        address_form = to_form(params, errors: [address: {"Must be a valid URL", []}])

        socket =
          socket
          |> assign(address_form: address_form)
          |> assign(device_info: nil)
          |> assign(device_unique: nil)
          |> assign(device_data: nil)

        {:noreply, socket}
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

    :ok = ConfigManager.add_device_config(device_config)

    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_info({:device_info, device_info}, socket) do
    socket =
      socket
      |> assign(device_info: device_info)

    socket =
      case device_info do
        %ShellyDeviceInfo{} ->
          {:ok, config} = ConfigManager.get_config()

          unique? =
            !Enum.any?(config.device_configs, fn device_config ->
              device_config.device_info.mac == device_info.mac
            end)

          if unique? do
            load_device_data(device_info)
            socket |> assign(device_data: :loading)
          else
            socket |> assign(device_unique: false)
          end

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:device_data, device_data}, socket) do
    socket =
      socket
      |> assign(device_data: device_data)
      |> assign(device_config_form: to_form(@device_config_form_fields))

    {:noreply, socket}
  end

  def load_device_info(address) do
    liveview = self()

    spawn(fn ->
      case ShellyDeviceInfo.fetch_info(address) do
        {:ok, device_info} -> send(liveview, {:device_info, device_info})
        {:error, reason} -> send(liveview, {:device_info, {:error, reason}})
      end
    end)
  end

  def load_device_data(%ShellyDeviceInfo{} = device_info) do
    liveview = self()

    spawn(fn ->
      case ShellyDeviceData.fetch_data(device_info) do
        {:ok, device_data} -> send(liveview, {:device_data, device_data})
        {:error, reason} -> send(liveview, {:device_data, {:error, reason}})
      end
    end)
  end
end
