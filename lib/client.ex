defmodule WsClient do
  use WebSockex

  def start(url) when is_binary(url) do
    state = %{received: [], sent: []}
    {:ok, pid} = WebSockex.start_link(url, __MODULE__, state)
    Process.sleep(10)
    {:ok, pid}
  end

  @impl true
  def handle_frame({type, msg}, state) do
    state = %{state | received: [{type, msg} | state.received]}
    {:ok, state}
  end

  @impl true
  def handle_cast({:send, {type, msg} = frame}, state) do
    {:reply, frame, state}
  end

  @impl true
  def handle_info({:get_received, from}, state) do
    send(from, {:received_messages, Enum.reverse(state.received)})
    {:ok, state}
  end

  def received_messages(client_pid) do
    send(client_pid, {:get_received, self()})

    receive do
      {:received_messages, messages} -> messages
    after
      10 -> []
    end
  end
end
