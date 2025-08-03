defmodule WebSocketMock.State do
  @moduledoc false
  use Agent

  def start_link(opts) do
    registry_name = Keyword.get(opts, :registry_name)
    state = %{replies: %{}}

    Agent.start_link(fn -> state end,
      name: {:via, Registry, {registry_name, :state}}
    )
  end

  def replies(registry_name) do
    Agent.get({:via, Registry, {registry_name, :state}}, fn state ->
      state.replies
    end)
  end

  def store_reply(registry_name, {msg_format, msg}, {reply_format, reply}) do
    msg = stringify(msg)
    reply = stringify(reply)

    Agent.update({:via, Registry, {registry_name, :state}}, fn state ->
      %{state | replies: Map.put(state.replies, {msg_format, msg}, {reply_format, reply})}
    end)
  end

  defp stringify(val) when is_map(val), do: Jason.encode!(val)
  defp stringify(val) when is_list(val), do: Jason.encode!(val)
  defp stringify(val), do: val
end
