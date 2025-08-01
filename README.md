# WebsocketMock

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `websocket_mock` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:websocket_mock, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/websocket_mock>.


## Usage 

```elixir

# Each server is started with a unique URL and a process ID.
{url , pid } = WebsocketMock.start_link()

# Check if a client is connected to the server.
WebsocketMock.is_connected?(pid)

# Get the number of clients connected to the server.
WebsocketMock.num_connections(pid)

# Send a message to the client connected to the server.
WebsocketMock.send(pid, "Hello Client")
# OR WebsocketMock.send(pid, client_pid, "Hello Client")
# WebsocketMock.broadcast(pid, "Hello Client")


# Retrieve all messages received by the server.
WebsocketMock.received_messages(pid)

# Send a response when receiving a specific message from a client.
WebsocketMock.respond_with(pid, "Hello from the CLient", "Hello from the Server")

# Stop the server.
WebsocketMock.stop(pid)

```
```
```
