# WebSocketMock

[![Hex.pm](https://img.shields.io/hexpm/v/websocket_mock.svg)](https://hex.pm/packages/websocket_mock)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/websocket_mock)

A lightweight WebSocket mock server for testing Elixir applications. Create isolated WebSocket servers on-demand for reliable testing of WebSocket clients and real-time features.

## Features

- **Isolated test servers** - Each mock runs on a unique port with its own client registry
- **Client management** - Track connections, send messages, and query connection status  
- **Test-friendly** - Designed for ExUnit with minimal setup

## Installation

Add `websocket_mock` to your test dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:websocket_mock, "~> 0.1.0", only: :test}
  ]
end
```

## Quick Start

```elixir
# Start a mock server
{:ok, mock} = WebSocketMock.start()

# Connect your WebSocket client
{:ok, client_pid} = MyWebSocketClient.start(mock.url)

# Check connection status
assert WebSocketMock.is_connected?(mock)
assert WebSocketMock.num_connections(mock) == 1

# Send messages to clients
[%{client_id: client_id}] = WebSocketMock.list_clients(mock)
:ok = WebSocketMock.send_message(mock, client_id, {:text, "Hello!"})

# Clean up
WebSocketMock.stop(mock)
```

## Usage in Tests

```elixir
defmodule MyAppTest do
  use ExUnit.Case

  setup do
    {:ok, mock} = WebSocketMock.start()
    on_exit(fn -> WebSocketMock.stop(mock) end)
    %{mock: mock}
  end

  test "websocket client connects and receives messages", %{mock: mock} do
    {:ok, client} = MyApp.WebSocketClient.start(mock.url)
    
    # Verify connection
    assert WebSocketMock.is_connected?(mock)
    
    # Send message from server
    [%{client_id: client_id}] = WebSocketMock.list_clients(mock)
    WebSocketMock.send_message(mock, client_id, {:text, "test message"})
    
    # Assert client received message
    assert_receive {:websocket_message, {:text, "test message"}}
  end
end
```

## Message Types

Send different WebSocket frame types:

```elixir
# Text messages
WebSocketMock.send_message(mock, client_id, {:text, "Hello"})

# Binary data
WebSocketMock.send_message(mock, client_id, {:binary, <<1, 2, 3>>})

# Ping/Pong frames
WebSocketMock.send_message(mock, client_id, {:ping, "ping-data"})
WebSocketMock.send_message(mock, client_id, {:pong, "pong-data"})
```


## Documentation

Full documentation is available at [https://hexdocs.pm/websocket_mock](https://hexdocs.pm/websocket_mock).


## License

MIT License. See [LICENSE](LICENSE) for details.
```elixir


```
```
```
