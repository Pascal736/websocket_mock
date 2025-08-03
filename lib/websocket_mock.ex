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

    # TODO: Move bandit in wrapper GenServer to handle used ports retry.
    children = [
      {Registry, keys: :unique, name: registry_name},
      {Bandit,
       plug: {WebSocketMock.Router, registry_name}, scheme: :http, port: port, startup_log: false},
      {WebSocketMock.State, registry_name: registry_name}
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
    get_connected_clients(registry_name)
    |> Enum.map(fn {client_id, pid} ->
      %{
        client_id: client_id,
        pid: pid,
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
  - `{:error, :invalid_message_format}` - Message could not be encoded

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
  @spec send_message(t(), String.t(), message()) ::
          :ok | {:error, :client_not_found | :invalid_message_format}
  def send_message(%__MODULE__{} = mock, client_id, {type, message}) when is_binary(message) do
    case Registry.lookup(mock.registry_name, client_id) do
      [{pid, _}] ->
        send(pid, {:server_message, {type, message}})
        :ok

      [] ->
        {:error, :client_not_found}
    end
  end

  def send_message(%__MODULE__{} = mock, client_id, {:text, message}) do
    case Jason.encode(message) do
      {:ok, json_message} ->
        send_message(mock, client_id, {:text, json_message})

      _ ->
        {:error, :invalid_message_format}
    end
  end

  @doc """
  Returns all received messages from all connected clients as a list.

  ## Parameters

  - `mock` - The mock server instance to query

  ## Returns

  A list of all messages received by all clients. Messages are in
  the order they were received by each client, but the order between
  different clients is not guaranteed.

  ## Examples

     {:ok, mock} = WebSocketMock.start()
     {:ok, client1} = WsClient.start(mock.url)
     {:ok, client2} = WsClient.start(mock.url)
     
     # Clients send messages to server
     WsClient.send_message(client1, {:text, "Hello from client 1"})
     WsClient.send_message(client2, {:text, "Hello from client 2"})
     
     # Get all received messages
     all_messages = WebSocketMock.received_messages(mock)
     assert length(all_messages) == 2
     assert "Hello from client 1" in all_messages
     assert "Hello from client 2" in all_messages

  """
  @spec received_messages(t()) :: [term()]
  def received_messages(%__MODULE__{registry_name: registry_name}) do
    get_connected_clients(registry_name)
    |> Enum.map(fn {client_id, pid} ->
      send(pid, {:get_received, self()})

      receive do
        {:received_messages, messages} -> messages
      after
        1000 -> {client_id, []}
      end
    end)
    |> List.flatten()
  end

  @doc """
  Returns received messages from a specific client.

  Retrieves all messages that have been received by the WebSocket handler
  for the specified client. Messages are returned in the order they were
  received.

  ## Parameters

  - `mock` - The mock server instance to query
  - `client_id` - The unique client identifier (from `list_clients/1`)

  ## Returns

  - A list of messages received by the client
  - `{:error, :client_not_found}` if the client ID doesn't exist

  ## Examples

     {:ok, mock} = WebSocketMock.start()
     {:ok, client} = WsClient.start(mock.url)
     
     # Client sends messages to server
     WsClient.send_message(client, {:text, "First message"})
     WsClient.send_message(client, {:text, "Second message"})
     
     # Get the client ID and retrieve their messages
     [%{client_id: client_id}] = WebSocketMock.list_clients(mock)
     messages = WebSocketMock.received_messages(mock, client_id)
     assert messages == ["First message", "Second message"]
     
     # Non-existent client returns error
     {:error, :client_not_found} = WebSocketMock.received_messages(mock, "invalid-id")

  """
  @spec received_messages(t(), String.t()) :: [term()] | {:error, :client_not_found}
  def received_messages(%__MODULE__{registry_name: registry_name}, client_id) do
    case get_client_pid(registry_name, client_id) do
      nil ->
        {:error, :client_not_found}

      pid ->
        send(pid, {:get_received, self()})

        receive do
          {:received_messages, messages} -> messages
        after
          1000 -> []
        end
    end
  end

  @doc """
  Configures an automatic reply for when clients send a specific message.

  Sets up the mock server to automatically respond with a predefined reply
  when any connected client sends a message that matches the given pattern.

  ## Parameters

  - `mock` - The mock server instance
  - `msg` - The message pattern to match against incoming client messages
  - `reply` - The message to automatically send back when the pattern matches

  ## Examples

      {:ok, mock} = WebSocketMock.start()
      
      # Set up automatic replies
      WebSocketMock.reply_with(mock, {:text, "ping"}, {:text, "pong"})
      
      {:ok, client} = WsClient.start(mock.url)
      WsClient.send_message(client, {:text, "ping"})
      # Client will receive {:text, "pong"}

  """
  def reply_with(%__MODULE__{registry_name: registry_name}, msg, reply) do
    WebSocketMock.State.store_reply(registry_name, msg, reply)
  end

  defp get_port do
    :rand.uniform(10_000) + 50_000
  end

  defp get_connected_clients(registry_name) do
    Registry.select(registry_name, [
      {{:"$1", :"$2", :"$3"}, [{:"=/=", :"$3", nil}], [{{:"$1", :"$2"}}]}
    ])
  end

  defp get_client_pid(registry_name, client_id) do
    case Registry.lookup(registry_name, client_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end
end
