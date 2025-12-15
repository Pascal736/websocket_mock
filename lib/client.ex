defmodule WebSocketMock.MockClient do
  @moduledoc """
  A lightweight WebSocket client for testing server interactions.

  This module wraps `WebSockex` to provide a simple interface for connecting to
  WebSocket servers (including `WebSocketMock.MockServer`), sending messages,
  and inspecting received frames.

  It automatically handles JSON encoding/decoding for convenience in tests.

  ## Example
      {:ok, client} = MockClient.start("ws://localhost:4000/ws")

      # Send a message (maps are auto-encoded to JSON)
      :ok = MockClient.send_message(client, %{action: "hello"})

      # Send a raw string
      :ok = MockClient.send_message(client, "simple string")

      # Assert on received messages
      # Incoming JSON strings are auto-decoded into maps
      assert [{:text, %{"response" => "ok"}}] = MockClient.received_messages(client)
  """

  use WebSockex

  @typedoc """
  A WebSocket mock client instance.
  """
  @type t :: %__MODULE__{
          pid: pid()
        }

  defstruct [:pid]

  @doc """
  Starts a new WebSocket client and connects to the given URL.

  ## Parameters

  - `url` - The WebSocket URL to connect to (e.g., "ws://localhost:4000/path")

  ## Returns

  - `{:ok, client}` - Successfully started client
  - `{:error, term}` - Failed to connect

  """
  @spec start(String.t()) :: {:ok, t()} | {:error, term()}
  def start(url) when is_binary(url) do
    state = %{received: [], sent: []}
    {:ok, pid} = WebSockex.start_link(url, __MODULE__, state)
    # Allow time for the connection to establish
    Process.sleep(10)
    {:ok, %__MODULE__{pid: pid}}
  end

  @doc """
  Sends a message to the connected server.

  Supports automatic JSON encoding for maps/lists and convenience wrappers for
  text frames.

  ## Parameters

  - `client` - The mock client instance
  - `message` - The message to send. Can be:
    - `{:text, map | list}` - Will be JSON encoded and sent as text
    - `{:text, string}` - Sent as a text frame
    - `{:binary, binary}` - Sent as a binary frame
    - `string` - Convenience: wrapped in `{:text, string}` and sent

  ## Examples

      MockClient.send_message(client, "Hello")
      MockClient.send_message(client, {:text, %{user_id: 1}})
      MockClient.send_message(client, {:binary, <<1, 2, 3>>})

  """
  @spec send_message(t(), term()) :: :ok | {:error, term()}
  def send_message(%__MODULE__{pid: pid}, {:text, msg}) when not is_binary(msg) do
    msg = Jason.encode!(msg)
    WebSockex.send_frame(pid, {:text, msg})
  end

  def send_message(%__MODULE__{} = client, msg) when is_binary(msg) do
    send_message(client, {:text, msg})
  end

  def send_message(%__MODULE__{pid: pid}, request) do
    WebSockex.send_frame(pid, request)
  end

  @doc """
  Returns all messages received by this client so far.

  Messages are returned in the order they were received (newest last).
  Incoming JSON text messages are automatically decoded into Elixir maps.

  ## Parameters

  - `client` - The mock client instance

  ## Returns

  A list of received messages, e.g., `[{:text, "msg"}, {:binary, <<...>>}]`.

  """
  @spec received_messages(t()) :: [term()]
  def received_messages(%__MODULE__{pid: pid}) do
    send(pid, {:get_received, self()})

    receive do
      {:received_messages, messages} -> messages
    after
      10 -> []
    end
  end

  @doc false
  @impl true
  def handle_frame({type, msg}, state) do
    msg = parse_message(msg)
    state = %{state | received: [{type, msg} | state.received]}
    {:ok, state}
  end

  @doc false
  @impl true
  def handle_ping({:ping, msg}, state) do
    msg = parse_message(msg)
    state = %{state | received: [{:ping, msg} | state.received]}
    {:ok, state}
  end

  @doc false
  @impl true
  def handle_cast({:send, frame}, state) do
    {:reply, frame, state}
  end

  @doc false
  @impl true
  def handle_info({:get_received, from}, state) do
    send(from, {:received_messages, Enum.reverse(state.received)})
    {:ok, state}
  end

  defp parse_message(msg) when is_binary(msg) do
    case Jason.decode(msg) do
      {:ok, decoded} -> decoded
      _ -> msg
    end
  end

  defp parse_message(msg), do: msg
end
