defmodule WebSocketMock.State do
  @moduledoc false
  use Agent

  def start_link(opts) do
    registry_name = Keyword.get(opts, :registry_name)
    state = %{replies: %{}, filter_replies: []}

    Agent.start_link(fn -> state end,
      name: {:via, Registry, {registry_name, :state}}
    )
  end

  def replies(registry_name) do
    Agent.get({:via, Registry, {registry_name, :state}}, fn state ->
      state.replies
    end)
  end

  def filter_replies(registry_name) do
    Agent.get({:via, Registry, {registry_name, :state}}, fn state ->
      state.filter_replies
    end)
  end

  def store_reply(registry_name, matcher, reply) do
    matcher = normalize_matcher(matcher)
    reply = normalize_reply(reply)
    add_reply(registry_name, matcher, reply)
  end

  defp add_reply(registry_name, matcher, reply) when is_function(matcher) do
    Agent.update({:via, Registry, {registry_name, :state}}, fn state ->
      %{state | filter_replies: [{matcher, reply} | state.filter_replies]}
    end)
  end

  defp add_reply(registry_name, matcher, reply) do
    Agent.update({:via, Registry, {registry_name, :state}}, fn state ->
      %{state | replies: Map.put(state.replies, matcher, reply)}
    end)
  end

  defp normalize_matcher(matcher) when is_function(matcher), do: matcher
  defp normalize_matcher({opcode, matcher}), do: {opcode, stringify(matcher)}
  defp normalize_matcher(matcher), do: {:text, stringify(matcher)}

  defp normalize_reply(reply) when is_function(reply), do: {:text, reply}
  defp normalize_reply({opcode, reply}) when is_function(reply), do: {opcode, reply}
  defp normalize_reply({opcode, reply}), do: {opcode, stringify(reply)}
  defp normalize_reply(reply), do: {:text, stringify(reply)}

  defp stringify(val) when is_map(val), do: Jason.encode!(val)
  defp stringify(val) when is_list(val), do: Jason.encode!(val)
  defp stringify(val), do: val
end
