defmodule WsClient do
  use WebSockex

  @impl true
  def start_link(url, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    state = %{received: [], sent: []}
    Websockex.start_link(url, __MODULE__, state, name: name)
  end

  @impl true
  def handle_frame({type, msg}, state) do
    IO.puts("Received Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}")
    state = %{state | received: [{type, msg} | state.received]}
    {:ok, state}
  end

  @impl true
  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts("Sending #{type} frame with payload: #{msg}")
    {:reply, frame, state}
  end

  def received_messages(client) do
    GenServer.call(client, :get_received)
  end

  @impl true
  def handle_call(:get_received, _from, state) do
    {:reply, state.received, state}
  end
end
