defmodule WebsocketMockTest do
  alias TestHelper.WsClient

  use ExUnit.Case
  doctest WebsocketMock

  describe "websocket mock server" do
    test "creates a unique url each time it starts" do
      servers = for _ <- 1..10, do: WebsocketMock.start_link()

      {urls, pids} = Enum.unzip(servers)

      assert length(Enum.uniq(urls)) == 10
      assert length(Enum.uniq(pids)) == 10
    end

    test "is_connected? returns false when it is not connected" do
      {:ok, pid} = WebsocketMock.start_link()
      refute WebsocketMock.is_connected?(pid)
    end

    test "is_connected? returns true when it is connected" do
      {url, pid} = WebsocketMock.start_link()
      WsClient.start_link(url, name: :ws_client)

      assert WebsocketMock.is_connected?(pid)
    end

    test "number of connections is correct" do
      {url, pid} = WebsocketMock.start_link()
      WsClient.start_link(url, name: :ws_client)

      assert WebsocketMock.num_connections(pid) == 1

      WsClient.start_link(url, name: :ws_client2)
      assert WebsocketMock.num_connections(pid) == 2
    end

    test "can send messages to the client" do
      {url, pid} = WebsocketMock.start_link()
      {:ok, client_pid} = WsClient.start_link(url, name: :ws_client)

      WebsocketMock.send(pid, client_pid, {:text, "Hello, WebSocket!"})

      assert WsClient.received_messages(client_pid) == [{:text, "Hello, WebSocket!"}]
    end
  end
end
