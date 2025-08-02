defmodule WebSocketMock.Handler do
  @moduledoc false
  @behaviour WebSock

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port)
    registry_name = Keyword.get(opts, :registry_name)
    client_id = generate_client_id()

    Registry.register(registry_name, client_id, self())

    state = %{
      received: [],
      sent: [],
      client_id: client_id,
      port: port,
      registry_name: registry_name
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:server_message, message}, state) do
    state = %{state | sent: [message | state.sent]}
    {:push, message, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, state) do
    {:ok, state}
  end

  @impl true
  def handle_in({message, [opcode: :text]}, state) do
    state = %{state | received: [message | state.received]}
    {:push, {:text, "echo: #{inspect(message)}"}, state}
  end

  @impl true
  def terminate(_reason, state) do
    Registry.unregister(state.registry_name, state.client_id)
    :ok
  end

  defp generate_client_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
