defmodule WebSocketMock.Sync do
  @moduledoc """
  Helpers for waiting on asynchronous conditions in tests.
  """

  @default_timeout 200
  @default_interval 5

  @doc """
  Repeatedly evaluates `fun` until it returns a ready value or `timeout`
  milliseconds have elapsed, then returns the last value produced by `fun`.

  ## Parameters

  - `fun` - A zero-arity function to evaluate
    like `MockServer.received_messages/1` or `MockServer.is_connected?/1`
  - `opts` - Keyword list of options:
    - `:timeout` - Maximum time to wait in milliseconds. Defaults to #{@default_timeout}
    - `:interval` - Time to sleep between attempts in milliseconds. Defaults to #{@default_interval}

  ## Examples

      iex> alias WebSocketMock.MockServer
      iex> alias WebSocketMock.MockClient
      iex> alias WebSocketMock.Sync
      iex>
      iex> {:ok, server} = MockServer.start()
      iex> {:ok, client} = MockClient.start(server.url)
      iex> [%{client_id: client_id}] = MockServer.list_clients(server)
      iex>
      iex> MockClient.send_message(client, {:text, "world"})
      iex> Sync.wait_until(fn -> MockServer.received_messages(server) end)
      [{:text, "world"}]

  """
  @spec wait_until((-> term()), keyword()) :: term()
  def wait_until(fun, opts \\ []) when is_function(fun, 0) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    interval = Keyword.get(opts, :interval, @default_interval)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_until(fun, deadline, interval)
  end

  defp do_wait_until(fun, deadline, interval) do
    result = fun.()

    cond do
      ready?(result) ->
        result

      System.monotonic_time(:millisecond) >= deadline ->
        result

      true ->
        Process.sleep(interval)
        do_wait_until(fun, deadline, interval)
    end
  end

  defp ready?(nil), do: false
  defp ready?(false), do: false
  defp ready?([]), do: false
  defp ready?(_), do: true
end
