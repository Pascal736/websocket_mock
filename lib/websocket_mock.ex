defmodule WebsocketMock do
  @behaviour :cowboy_websocket

  @impl :cowboy_websocket
  def init(req, state) do
    IO.puts("WebSocket connection initializing with state: #{inspect(state)}")
    {:cowboy_websocket, req, state}
  end

  @impl :cowboy_websocket
  def websocket_init(state) do
    IO.puts("WebSocket connection initialized with state: #{inspect(state)}")
    {:ok, state}
  end

  @impl :cowboy_websocket
  def terminate(_reason, _req, _state), do: :ok

  @impl :cowboy_websocket
  def websocket_handle({:text, msg}, state) do
    send(state.pid, to_string(msg))
    handle_websocket_message(msg, state)
  end

  @impl :cowboy_websocket
  def websocket_info(:close, state), do: {:reply, :close, state}

  def websocket_info({:close, code, reason}, state) do
    {:reply, {:close, code, reason}, state}
  end

  def websocket_info({:send, frame}, state) do
    {:reply, frame, state}
  end

  defp handle_websocket_message(msg, state) do
    IO.puts("Received WebSocket message: #{msg}")
    {:ok, state}
  end
end
