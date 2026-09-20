# WebSocketMock

[![Hex.pm](https://img.shields.io/hexpm/v/websocket_mock.svg)](https://hex.pm/packages/websocket_mock)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://websocket-mock.hexdocs.pm/)

Lightweight WebSocket mock server and mock client for testing.

## Installation

Add `websocket_mock` to your test dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:websocket_mock, "~> 0.4.0", only: :test}
  ]
end
```

## Quick Start

```elixir
iex> alias WebSocketMock.MockServer
iex> alias WebSocketMock.MockClient
iex> alias WebSocketMock.Sync
iex>
iex> {:ok, server} = MockServer.start()
iex> {:ok, client} = MockClient.start(server.url)
iex> MockServer.is_connected?(server)
true
iex> MockServer.num_connections(server)
1
iex> [%{client_id: client_id}] = MockServer.list_clients(server)
iex> MockServer.send_message(server, client_id, {:text, "Hello!"})
:ok
iex> MockClient.send_message(client, {:text, "world"})
:ok
iex>
iex> Sync.wait_until(fn -> MockServer.received_messages(server) end)
[{:text, "world"}]
iex> Sync.wait_until(fn -> MockClient.received_messages(client) end)
[{:text, "Hello!"}]

iex> alias WebSocketMock.MockServer
iex> alias WebSocketMock.MockClient
iex> alias WebSocketMock.Sync
iex>
iex> {:ok, server} = MockServer.start()
iex> {:ok, client} = MockClient.start(server.url)
iex> # Set up automatic replies
iex>  MockServer.reply_with(server, {:text, "ping"}, {:text, "pong"})
iex>  # Also works with functions as filters
iex>  MockServer.reply_with(server, fn {_opcode, msg} -> msg == "ping" end, {:text, "pong"})
iex>
iex> MockClient.send_message(client, {:text, "ping"})
iex> Sync.wait_until(fn -> MockClient.received_messages(client) end)
[{:text, "pong"}]
iex> # Mockserver accepts callbacks which run before sending the reply
iex> MockServer.reply_with(server, "ping", fn {opcode, msg} -> {opcode, msg <> " pong"} end)
iex> MockClient.send_message(client, {:text, "ping"})
iex> Sync.wait_until(fn -> length(MockClient.received_messages(client)) == 2 end)
iex> MockClient.received_messages(client)
[{:text, "pong"}, {:text, "ping pong"}]
```

## Usage in Tests

```elixir
defmodule MyAppTest do
  use ExUnit.Case
  alias WebSocketMock.MockServer
  alias WebSocketMock.MockClient
  alias WebSocketMock.Sync

  setup do
    {:ok, server} = MockServer.start()
    on_exit(fn -> MockServer.stop(server) end)
    %{server: server}
  end

  test "websocket client connects and receives messages", %{server: server} do
    {:ok, client} = MockClient.start(server.url)

    [%{client_id: client_id}] = MockServer.list_clients(server)
    MockServer.send_message(server, client_id, {:text, "test message"})

    assert Sync.wait_until(fn -> MockClient.received_messages(client) end) ==
             [{:text, "test message"}]
  end


  test "client sends message to server", %{server: server} do
    {:ok, client} = MockClient.start(server.url)

    MockClient.send_message(client, {:text, "Hello Server!"})

    assert Sync.wait_until(fn -> MockServer.received_messages(server) end) ==
             [{:text, "Hello Server!"}]
  end


  test "client handles response", %{server: server} do
    {:ok, client} = MockClient.start(server.url)
    MockServer.reply_with(server, {:text, "hello"}, {:text, "world"})
    MockServer.reply_with(server, {:text, "buy"}, {:text, "see ya"})

    MockClient.send_message(client, {:text, "hello"})
    assert Sync.wait_until(fn -> MockClient.received_messages(client) end) == [{:text, "world"}]

    MockClient.send_message(client, {:text, "buy"})
    assert Sync.wait_until(fn -> {:text, "see ya"} in MockClient.received_messages(client) end)
  end
end
```

## Documentation

Full documentation is available at [https://hexdocs.pm/websocket_mock](https://hexdocs.pm/websocket_mock).

## License

MIT License. See [LICENSE](LICENSE) for details.
