# WebSocketMock

[![Hex.pm](https://img.shields.io/hexpm/v/websocket_mock.svg)](https://hex.pm/packages/websocket_mock)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/websocket_mock)

Lightweight WebSocket mock server and mock client for testing.

## Installation

Add `websocket_mock` to your test dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:websocket_mock, "~> 0.3.0", only: :test}
  ]
end
```

## Quick Start

```elixir
iex> alias WebSocketMock.MockServer
iex> alias WebSocketMock.MockClient
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
iex> MockServer.received_messages(server)
[{:text, "world"}]
iex> MockClient.received_messages(client)
[{:text, "Hello!"}]

iex> alias WebSocketMock.MockServer
iex> alias WebSocketMock.MockClient
iex>
iex> {:ok, server} = MockServer.start()
iex> {:ok, client} = MockClient.start(server.url)
iex> # Set up automatic replies
iex>  MockServer.reply_with(server, {:text, "ping"}, {:text, "pong"})
iex>  # Also works with functions as filters
iex>  MockServer.reply_with(server, fn {opcode, msg} -> msg == "ping" end, {:text, "pong"})
iex>   
iex> MockClient.send_message(client, {:text, "ping"})
iex> Process.sleep(20)
iex> MockClient.received_messages(client)
[{:text, "pong"}]
iex> # Mockserver accepts callbacks which run before sending the reply
iex> MockServer.reply_with(server, "ping", fn {opcode, msg} -> {opcode, msg <> " pong"} end)
iex> MockClient.send_message(client, {:text, "ping"})
iex> Process.sleep(20)
iex> MockClient.received_messages(client)
[{:text, "pong"}, {:text, "ping pong"}]
```

## Usage in Tests
```elixir
defmodule MyAppTest do
  use ExUnit.Case
  alias WebSocketMock.MockServer
  alias WebSocketMock.MockClient

  setup do
    {:ok, server} = MockServer.start()
    on_exit(fn -> MockServer.stop(server) end)
    %{server: server}
  end

  test "websocket client connects and receives messages", %{server: server} do
    {:ok, client} = MockClient.start(server.url)
    
    [%{client_id: client_id}] = MockServer.list_clients(server)
    MockServer.send_message(server, client_id, {:text, "test message"})

    assert MockClient.received_messages(client) == [{:text, "test message"}]
  end


  test "client sends message to server", %{server: server} do
    {:ok, client} = MockClient.start(server.url)
    
    MockClient.send_message(client, {:text, "Hello Server!"})
    
    assert MockServer.received_messsages(server) == [{:text, "Hello Server!"}]
  end


  test "client handles response", %{server: server} do 
    {:ok, client} = MockClient.start(server.url)
    MockServer.reply_with(server, {:text, "hello"}, {:text, "world"})
    MockServer.reply_with(server, {:text, "buy"}, {:text, "see ya"})

    MockClient.send_message(client, {:text, "hello"})
    assert MockClient.received_messages(client) == [{:text, "world"}]

    MockClient.send_message(client, {:text, "buy"})
    assert {:text, "see ya"} in MockClient.received_messages(client)
  end
end
```

## Documentation

Full documentation is available at [https://hexdocs.pm/websocket_mock](https://hexdocs.pm/websocket_mock).


## Known Issues
- Tests are flaky because of the asynchronous nature of the requests. Needs improvement.
- The mock server currently crashes on start when the randomly selected port is already in use.


## License

MIT License. See [LICENSE](LICENSE) for details.
