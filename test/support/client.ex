defmodule WebSocketMock.WsClient do
  defstruct [:pid]
  use WebSockex

  def start(url) when is_binary(url) do
    state = %{received: [], sent: []}
    {:ok, pid} = WebSockex.start_link(url, __MODULE__, state)
    # Allow time for the connection to establish
    Process.sleep(10)
    {:ok, %__MODULE__{pid: pid}}
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
    state = %{state | received: [{type, msg} | state.received]}
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
end
