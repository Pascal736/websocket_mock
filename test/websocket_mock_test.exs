defmodule WebsocketMockTest do
  use ExUnit.Case
  doctest WebSocketMock

  describe "websocket mock server" do
    test "creates a unique url each time it starts" do
      servers = for _ <- 1..10, do: WebSocketMock.start()

      {urls, ports} = Enum.unzip(servers)

      assert length(Enum.uniq(urls)) == 10
      assert length(Enum.uniq(ports)) == 10
    end

    test "is_connected? returns false when it is not connected" do
      {port, _url} = WebSocketMock.start()
      refute WebSocketMock.is_connected?(port)
    end

    test "is_connected? returns true when it is connected" do
      {port, url} = WebSocketMock.start()
      {:ok, _client_pid} = WsClient.start(url)

      assert WebSocketMock.is_connected?(port)
    end

    test "number of connections is correct" do
      {port, url} = WebSocketMock.start()

      {:ok, _client_pid} = WsClient.start(url)
      assert WebSocketMock.num_connections(port) == 1

      {:ok, _client_pid} = WsClient.start(url)
      assert WebSocketMock.num_connections(port) == 2
    end

    test "can send messages to the client" do
      {port, url} = WebSocketMock.start()
      {:ok, client_pid} = WsClient.start(url)
      [client_id] = WebSocketMock.list_clients(port) |> Enum.map(& &1.client_id)

      WebSocketMock.send_message(port, client_id, {:text, "Hello, WebSocket!"})
      # Allow time for the message to be processed
      Process.sleep(10)

      assert WsClient.received_messages(client_pid) == [{:text, "Hello, WebSocket!"}]
    end
  end
end
