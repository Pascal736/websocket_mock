defmodule WebSocketMock do
  @moduledoc """
  A WebSocket mock server for testing WebSocket clients and applications.

  This module provides a lightweight WebSocket server that can be started and stopped
  programmatically for testing purposes. Each mock server instance runs on a unique
  port and maintains its own isolated registry of connected clients.

  ## Features

  - **Isolated instances**: Each mock server runs independently with its own port and client registry
  - **Client management**: Track connected clients, send messages, and query connection status
  - **Test-friendly**: Designed for use in ExUnit tests with minimal setup

  ## Example

      # Start a mock server
      {:ok, mock} = WebSocketMock.start()

      # Connect a WebSocket client to mock.url
      {:ok, client_pid} = MyWebSocketClient.start(mock.url)

      # Check connection status
      assert WebSocketMock.is_connected?(mock)
      assert WebSocketMock.num_connections(mock) == 1

      # Send a message to a specific client
      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)
      :ok = WebSocketMock.send_message(mock, client_id, {:text, "Hello!"})

      # Clean up
      WebSocketMock.stop(mock)

  ## Client Message Format

  Messages sent via `send_message/3` should follow the WebSocket frame format:

  - `{:text, "message"}` - Text frame
  - `{:binary, <<data>>}` - Binary frame
  - `{:ping, payload}` - Ping frame
  - `{:pong, payload}` - Pong frame

  """

  @typedoc """
  A WebSocket mock server instance.

  Contains all the information needed to interact with a running mock server:

  - `supervisor_pid` - The supervisor process managing the server
  - `port` - The TCP port the server is listening on
  - `url` - The WebSocket URL clients should connect to
  - `registry_name` - Internal registry name for client tracking
  """
  @type t :: %__MODULE__{
          supervisor_pid: pid(),
          port: pos_integer(),
          url: String.t(),
          registry_name: atom()
        }

  @typedoc "WebSocket message frame"
  @type message :: {:text, String.t()} | {:binary, binary()} | {:ping | :pong, binary()}

  @typedoc "Client information returned by list_clients/1"
  @type client_info :: %{
          client_id: String.t(),
          pid: pid(),
          metadata: term(),
          alive?: boolean()
        }

  defstruct [:supervisor_pid, :port, :url, :registry_name]

  @doc """
  Starts a new WebSocket mock server.

  Creates a new mock server instance listening on a random available port.
  Each server runs independently with its own client registry.

  ## Returns

  - `{:ok, mock}` - Successfully started server
  - `{:error, reason}` - Failed to start server

  ## Examples

      {:ok, mock} = WebSocketMock.start()
      #=> {:ok, %WebSocketMock{port: 52847, url: "ws://localhost:52847/ws", ...}}

  """
  @spec start() :: {:ok, t()} | {:error, term()}
  def start() do
    port = get_port()
    registry_name = :"ws_mock_registry_#{:erlang.unique_integer()}"

    children = [
      {Registry, keys: :unique, name: registry_name},
      {Bandit, plug: {WebSocketMock.Router, registry_name}, scheme: :http, port: port}
    ]

    case Supervisor.start_link(children, strategy: :one_for_one) do
      {:ok, supervisor_pid} ->
        mock = %__MODULE__{
          supervisor_pid: supervisor_pid,
          port: port,
          url: "ws://localhost:#{port}/ws",
          registry_name: registry_name
        }

        {:ok, mock}

      error ->
        error
    end
  end

  @doc """
  Stops a WebSocket mock server and cleans up all resources.

  This will close all client connections and shut down the server process.
  Always call this function to avoid resource leaks in tests.

  ## Parameters

  - `mock` - The mock server instance to stop

  ## Examples

      {:ok, mock} = WebSocketMock.start()
      # ... use the mock server ...
      :ok = WebSocketMock.stop(mock)

  """
  @spec stop(t()) :: :ok
  def stop(%__MODULE__{supervisor_pid: pid}) do
    Supervisor.stop(pid)
  end

  @doc """
  Checks if any clients are currently connected to the mock server.

  ## Parameters

  - `mock` - The mock server instance to check

  ## Returns

  - `true` - One or more clients are connected
  - `false` - No clients are connected

  ## Examples

      {:ok, mock} = WebSocketMock.start()
      refute WebSocketMock.is_connected?(mock)

      # After a client connects...
      assert WebSocketMock.is_connected?(mock)

  """
  @spec is_connected?(t()) :: boolean()
  def is_connected?(%__MODULE__{} = mock) do
    num_connections(mock) > 0
  end

  @doc """
   Returns the number of currently connected clients

  """

  @spec num_connections(t()) :: non_neg_integer()
  def num_connections(%__MODULE__{} = mock) do
    list_clients(mock) |> length()
  end

  @doc """
  Lists all currently connected clients with their metadata.

  Returns detailed information about each connected client, including their
  unique client ID, process ID, and connection status.

  ## Parameters

  - `mock` - The mock server instance to query

  ## Returns

  A list of client information maps. Each map contains:

  - `:client_id` - Unique identifier for the client (base64 encoded)
  - `:pid` - The client's WebSocket process ID
  - `:metadata` - Additional metadata (typically the process ID)
  - `:alive?` - Whether the client process is still alive

  ## Examples

      {:ok, mock} = WebSocketMock.start()
      assert WebSocketMock.list_clients(mock) == []

      # After a client connects...
      [client] = WebSocketMock.list_clients(mock)
      assert is_binary(client.client_id)
      assert is_pid(client.pid)
      assert client.alive? == true

  """
  @spec list_clients(t()) :: [client_info()]
  def list_clients(%__MODULE__{registry_name: registry_name}) do
    Registry.select(registry_name, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Enum.map(fn {client_id, pid, metadata} ->
      %{
        client_id: client_id,
        pid: pid,
        metadata: metadata,
        alive?: Process.alive?(pid)
      }
    end)
  end

  @doc """
  Sends a message to a specific connected client.

  Delivers a WebSocket frame to the client identified by the given client ID.
  The client ID can be obtained from `list_clients/1`.

  ## Parameters

  - `mock` - The mock server instance
  - `client_id` - The unique client identifier (from `list_clients/1`)
  - `message` - The WebSocket frame to send

  ## Returns

  - `:ok` - Message sent successfully
  - `{:error, :client_not_found}` - Client ID does not exist

  ## Examples

      {:ok, mock} = WebSocketMock.start()
      # ... client connects ...
      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)

      # Send different types of messages
      :ok = WebSocketMock.send_message(mock, client_id, {:text, "Hello!"})
      :ok = WebSocketMock.send_message(mock, client_id, {:binary, <<1, 2, 3>>})
      :ok = WebSocketMock.send_message(mock, client_id, {:ping, "ping-data"})

      # Handle non-existent clients
      {:error, :client_not_found} = WebSocketMock.send_message(mock, "invalid-id", {:text, "Hello"})

  """
  @spec send_message(t(), String.t(), message()) :: :ok | {:error, :client_not_found}
  def send_message(%__MODULE__{registry_name: registry_name}, client_id, message) do
    case Registry.lookup(registry_name, client_id) do
      [{pid, _}] ->
        send(pid, {:server_message, message})
        :ok

      [] ->
        {:error, :client_not_found}
    end
  end

  defp get_port do
    :rand.uniform(10_000) + 50_000
  end
end
