defmodule ShellyInfluxImporter.ConfigManager do
  @moduledoc false

  alias ShellyInfluxImporter.Config
  alias ShellyInfluxImporter.ConfigManager.State

  require Logger

  use GenServer

  @config_file_name "config.json"

  defmodule State do
    defstruct config: nil
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_config() do
    GenServer.call(__MODULE__, :get_config)
  end

  def set_update_interval(update_interval) do
    GenServer.call(__MODULE__, {:set_update_interval, update_interval})
  end

  def add_device_config(device_config) do
    GenServer.call(__MODULE__, {:add_device_config, device_config})
  end

  def update_device_config(device_config) do
    GenServer.call(__MODULE__, {:update_device_config, device_config})
  end

  def delete_device_config(device_config_or_mac) do
    GenServer.call(__MODULE__, {:delete_device_config, device_config_or_mac})
  end

  @impl true
  def init(_opts) do
    Logger.info("ConfigManager: Init")

    case load_or_init_config() do
      {:error, error} ->
        Logger.error(
          "ConfigManager: Error while loading or initialising config: #{inspect(error)}}"
        )

        {:error, error}

      {:ok, config} ->
        state = %State{
          config: config
        }

        {:ok, state, {:continue, :store_config}}
    end
  end

  @impl true
  def handle_call(:get_config, _from, state) do
    {:reply, {:ok, state.config}, state}
  end

  @impl true
  def handle_call({:set_update_interval, update_interval}, _from, state) do
    case Config.set_update_interval(state.config, update_interval) do
      {:error, error} ->
        {:reply, {:error, error}, state}

      {:ok, config} ->
        new_state = %State{state | config: config}

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.pub_sub_topic(),
          {:update, config}
        )

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.pub_sub_topic(:update_interval),
          {:update, config}
        )

        {:reply, :ok, new_state, {:continue, :store_config}}
    end
  end

  @impl true
  def handle_call({:add_device_config, device_config}, _from, state) do
    case Config.add_device_config(state.config, device_config) do
      {:error, error} ->
        {:reply, {:error, error}, state}

      {:ok, config} ->
        new_state = %State{state | config: config}

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.pub_sub_topic(),
          {:update, config}
        )

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.pub_sub_topic(:device_configs),
          {:update, config}
        )

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.DeviceConfig.pub_sub_topic(),
          {:add, device_config}
        )

        {:reply, :ok, new_state, {:continue, :store_config}}
    end
  end

  @impl true
  def handle_call({:update_device_config, device_config}, _from, state) do
    case Config.update_device_config(state.config, device_config) do
      {:error, error} ->
        {:reply, {:error, error}, state}

      {:ok, config} ->
        new_state = %State{state | config: config}

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.pub_sub_topic(),
          {:update, config}
        )

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.pub_sub_topic(:device_configs),
          {:update, config}
        )

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.DeviceConfig.pub_sub_topic(device_config),
          {:update, device_config}
        )

        {:reply, :ok, new_state, {:continue, :store_config}}
    end
  end

  @impl true
  def handle_call({:delete_device_config, device_config_or_mac}, _from, state) do
    case Config.delete_device_config(state.config, device_config_or_mac) do
      {:error, error} ->
        {:reply, {:error, error}, state}

      {:ok, config, deleted_device_config} ->
        new_state = %State{state | config: config}

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.pub_sub_topic(),
          {:update, config}
        )

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.pub_sub_topic(:device_configs),
          {:update, config}
        )

        Phoenix.PubSub.broadcast(
          ShellyInfluxImporter.PubSub,
          Config.DeviceConfig.pub_sub_topic(deleted_device_config),
          {:delete, deleted_device_config}
        )

        {:reply, :ok, new_state, {:continue, :store_config}}
    end
  end

  @impl true
  def handle_continue(:store_config, state) do
    config_path =
      Keyword.get(Application.get_env(:shelly_influx_importer, __MODULE__), :config_path)

    file_path = Path.join(config_path, @config_file_name)

    with {:ok, encoded} <- Jason.encode(state.config, pretty: true),
         :ok <- File.mkdir_p(config_path),
         :ok <- File.write(file_path, encoded) do
      Logger.info("ConfigManager: Config saved to disk")
      {:noreply, state}
    else
      {:error, error} ->
        Logger.error("ConfigManager: Error while saving config to disk: #{inspect(error)}}")
        {:noreply, state}
    end
  end

  def load_or_init_config() do
    config_path =
      Keyword.get(Application.get_env(:shelly_influx_importer, __MODULE__), :config_path)

    with {:config_path, path} when is_binary(path) <- {:config_path, config_path},
         :ok <- File.mkdir_p(path) do
      file_path = Path.join(path, @config_file_name)

      if File.exists?(file_path) do
        Logger.info("ConfigManager: Loading config")

        with {:ok, content} <- File.read(file_path),
             {:ok, decoded} <- Jason.decode(content),
             config = Config.new(decoded) do
          {:ok, config}
        end
      else
        Logger.info("ConfigManager: Initialising config")

        with config <- Config.new(),
             {:ok, encoded} <- Jason.encode(config, pretty: true),
             :ok <- File.write(file_path, encoded) do
          {:ok, config}
        end
      end
    else
      {:config_path, value} ->
        {:error, "Config path is not set or not a binary, got '#{inspect(value)}}'"}

      {:error, error} ->
        {:error, error}
    end
  end
end
