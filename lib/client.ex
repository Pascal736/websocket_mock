defmodule WebSocketMock.MockClient do
  defstruct [:pid]
  use WebSockex

  def start(url) when is_binary(url) do
    state = %{received: [], sent: []}
    {:ok, pid} = WebSockex.start_link(url, __MODULE__, state)
    # Allow time for the connection to establish
    Process.sleep(5)
    {:ok, %__MODULE__{pid: pid}}
  end

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

  def received_messages(%__MODULE__{pid: pid}) do
    send(pid, {:get_received, self()})

    receive do
      {:received_messages, messages} -> messages
    after
      10 -> []
    end
  end

  @impl true
  def handle_frame({type, msg}, state) do
    msg = parse_message(msg)
    state = %{state | received: [{type, msg} | state.received]}
    {:ok, state}
  end

  @impl true
  def handle_ping({:ping, msg}, state) do
    msg = parse_message(msg)
    state = %{state | received: [{:ping, msg} | state.received]}
    {:ok, state}
  end

  @impl true
  def handle_cast({:send, frame}, state) do
    {:reply, frame, state}
  end

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
