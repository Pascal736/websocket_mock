defmodule WebsocketMockTest do
  alias WebSocketMock.WsClient
  use ExUnit.Case

  doctest WebSocketMock

  describe "websocket mock server" do
    test "creates a unique url each time it starts" do
      mocks =
        for _ <- 1..10 do
          {:ok, mock} = WebSocketMock.start()
          mock
        end

      urls = Enum.map(mocks, & &1.url)
      ports = Enum.map(mocks, & &1.port)

      assert length(Enum.uniq(urls)) == 10
      assert length(Enum.uniq(ports)) == 10

      Enum.each(mocks, &WebSocketMock.stop/1)
    end

    test "is_connected? returns false when it is not connected" do
      {:ok, mock} = WebSocketMock.start()

      refute WebSocketMock.is_connected?(mock)

      WebSocketMock.stop(mock)
    end

    test "is_connected? returns true when it is connected" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, _client_pid} = WsClient.start(mock.url)

      assert WebSocketMock.is_connected?(mock)

      WebSocketMock.stop(mock)
    end

    test "number of connections is correct" do
      {:ok, mock} = WebSocketMock.start()

      assert WebSocketMock.num_connections(mock) == 0

      {:ok, _client} = WsClient.start(mock.url)
      assert WebSocketMock.num_connections(mock) == 1

      {:ok, _client} = WsClient.start(mock.url)
      assert WebSocketMock.num_connections(mock) == 2

      WebSocketMock.stop(mock)
    end

    test "can send messages to the client" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client} = WsClient.start(mock.url)

      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)

      :ok = WebSocketMock.send_message(mock, client_id, {:text, "Hello, WebSocket!"})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert WsClient.received_messages(client) == [{:text, "Hello, WebSocket!"}]

      WebSocketMock.stop(mock)
    end

    test "list_clients returns correct client information" do
      {:ok, mock} = WebSocketMock.start()

      assert WebSocketMock.list_clients(mock) == []

      {:ok, _client} = WsClient.start(mock.url)

      clients = WebSocketMock.list_clients(mock)
      assert length(clients) == 1

      [client] = clients
      assert is_binary(client.client_id)
      assert is_pid(client.pid)
      assert client.alive? == true

      WebSocketMock.stop(mock)
    end

    test "send_message returns error for non-existent client" do
      {:ok, mock} = WebSocketMock.start()

      result = WebSocketMock.send_message(mock, "non-existent-client-id", {:text, "Hello"})
      assert result == {:error, :client_not_found}

      WebSocketMock.stop(mock)
    end

    test "multiple mock servers can run simultaneously" do
      {:ok, mock1} = WebSocketMock.start()
      {:ok, mock2} = WebSocketMock.start()

      {:ok, _client1} = WsClient.start(mock1.url)
      {:ok, _client2} = WsClient.start(mock2.url)

      assert WebSocketMock.num_connections(mock1) == 1
      assert WebSocketMock.num_connections(mock2) == 1

      clients1 = WebSocketMock.list_clients(mock1)
      clients2 = WebSocketMock.list_clients(mock2)

      assert length(clients1) == 1
      assert length(clients2) == 1
      assert clients1 != clients2

      WebSocketMock.stop(mock1)
      WebSocketMock.stop(mock2)
    end

    test "stores received messages" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client} = WsClient.start(mock.url)

      WsClient.send_message(client, {:text, "Hello"})
      # Allow time for the message to be processed
      Process.sleep(10)

      assert WebSocketMock.received_messages(mock) == [{:text, "Hello"}]
    end

    test "stores received messages from specific client" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client1} = WsClient.start(mock.url)
      {:ok, client2} = WsClient.start(mock.url)

      WsClient.send_message(client1, {:text, "Hello"})
      WsClient.send_message(client2, {:text, "World"})
      # Allow time for the message to be processed
      Process.sleep(10)

      clients = WebSocketMock.list_clients(mock)

      messages_by_client =
        Enum.map(clients, fn client ->
          WebSocketMock.received_messages(mock, client.client_id)
        end)

      assert length(clients) == 2
      assert [{:text, "Hello"}] in messages_by_client
      assert [{:text, "World"}] in messages_by_client
    end

    test "replys with correct configured message" do
      {:ok, mock} = WebSocketMock.start()
      msg = {:text, "hello"}
      response = {:text, "world"}
      WebSocketMock.reply_with(mock, msg, response)
      {:ok, client} = WsClient.start(mock.url)

      WsClient.send_message(client, msg)

      Process.sleep(10)
      assert WsClient.received_messages(client) == [response]
    end
  end
end
