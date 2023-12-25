defmodule ShellyInfluxImporterWeb.HomeLive do
  use ShellyInfluxImporterWeb, :live_view

  alias ShellyInfluxImporter.Config
  alias ShellyInfluxImporter.ConfigManager

  def render(assigns) do
    ~H"""
    <div class="mb-4 grid gap-4 grid-cols-[1fr_auto]">
      <h2 class="text-lg">Devices</h2>
      <div>
        <.link
          navigate={~p"/device/new"}
          class="flex items-center gap-1 text-sm font-semibold leading-6 text-zinc-900 rounded-lg bg-zinc-100 px-2 py-1 hover:bg-sky-800 hover:text-white"
        >
          <.icon name="hero-plus-solid" class="h-4 w-4" />
          <span>Add Device</span>
        </.link>
      </div>
    </div>

    <div class="grid gap-2">
      <div
        :for={device <- @config.device_configs}
        navigate={~p"/"}
        class="border-zinc-200 border p-3 rounded grid gap-x-4 grid-cols-[1fr_auto]"
      >
        <div>
          <div>
            <%= device.device_info.name %>
            <span class="text-xs rounded-lg bg-zinc-100 px-2 py-1 ml-2">
              <%= device.device_info.type %>
            </span>
          </div>
          <div class="text-xs mt-1 flex flex-wrap gap-x-4">
            <div>
              Address:
              <a href={device.device_info.address} target="_blank" class="hover:text-sky-800">
                <%= device.device_info.address %>
              </a>
            </div>

            <div>Mac: <%= device.device_info.mac %></div>
          </div>
        </div>
        <div class="self-center items-center h-full grid gap-4 grid-cols-[auto_auto]">
          <div>
            <.link navigate={~p"/device/#{device.device_info}"} class="hover:text-sky-800">
              <.icon name="hero-pencil-square-solid" class="h-5 w-5" />
            </.link>
          </div>
          <div>
            <.button
              type="button"
              class="!bg-transparent !hover:bg-transparent !p-0 !text-black"
              phx-click={show_modal("delete-modal-#{device.device_info.mac}")}
            >
              <.icon name="hero-x-mark-solid" class="h-5 w-5 cursor-pointer hover:text-sky-800" />
            </.button>
          </div>
        </div>
        <.modal id={"delete-modal-#{device.device_info.mac}"}>
          <h3 class="text-xl mb-4">Delete <%= device.device_info.name %></h3>
          <p>
            Are you sure you want to delete <span class="font-semibold"><%= device.device_info.name %></span>?
          </p>
          <div class="mt-8">
            <.button
              phx-click={JS.push("delete_device", value: %{mac: device.device_info.mac})}
              type="button"
              class="!bg-red-700 !hover:bg-red-500"
              aria-label={gettext("close")}
            >
              Delete
            </.button>
            <.button
              phx-click={JS.exec("data-cancel", to: "#delete-modal-#{device.device_info.mac}")}
              type="button"
              class="!bg-transparent !hover:bg-transparent !text-black !hover:text-zinc-700"
              aria-label={gettext("close")}
            >
              Cancel
            </.button>
          </div>
        </.modal>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, config} = ConfigManager.get_config()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        ShellyInfluxImporter.PubSub,
        ShellyInfluxImporter.Config.pub_sub_topic(:device_configs)
      )
    end

    socket =
      socket
      |> assign(page_title: "Devices")

    {:ok, socket, temporary_assigns: [config: config]}
  end

  def handle_event("delete_device", %{"mac" => mac}, socket) do
    :ok = ConfigManager.delete_device_config(mac)

    {:noreply, socket}
  end

  def handle_info({:update, %Config{} = config}, socket) do
    IO.inspect("config update")

    socket =
      socket
      |> assign(:config, config)

    {:noreply, socket}
  end
end
