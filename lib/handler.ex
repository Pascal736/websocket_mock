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

  def handle_info({:get_received, from}, state) do
    send(from, {:received_messages, Enum.reverse(state.received)})
    {:ok, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, state) do
    {:ok, state}
  end

  @impl true
  def handle_in({message, [opcode: :text]}, state) do
    state = %{state | received: [{:text, message} | state.received]}

    case stored_reply(state.registry_name, {:text, message}) do
      nil ->
        {:ok, state}

      reply ->
        state = %{state | sent: [reply | state.sent]}
        {:push, reply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    Registry.unregister(state.registry_name, state.client_id)
    :ok
  end

  defp generate_client_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp stored_reply(registry_name, message) do
    stored_value(registry_name, message) || stored_function(registry_name, message)
  end

  defp stored_value(registry_name, message) do
    WebSocketMock.State.replies(registry_name) |> Map.get(message)
  end

  defp stored_function(registry_name, message) do
    WebSocketMock.State.filter_replies(registry_name)
    |> Enum.find_value(fn {filter, reply} ->
      filter.(message) && evaludated_reply(reply, message)
    end)
  end

  defp evaludated_reply({_, reply}, message) when is_function(reply) do
    reply.(message)
  end

  defp evaludated_reply(reply, _message), do: reply
end
