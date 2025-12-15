defmodule WebsocketMockTest do
  alias WebSocketMock.MockClient
  alias WebSocketMock.MockServer
  use ExUnit.Case

  doctest WebSocketMock.MockServer

  describe "websocket mock server" do
    test "creates a unique url each time it starts" do
      mocks =
        for _ <- 1..10 do
          {:ok, mock} = MockServer.start()
          mock
        end

      urls = Enum.map(mocks, & &1.url)
      ports = Enum.map(mocks, & &1.port)

      assert length(Enum.uniq(urls)) == 10
      assert length(Enum.uniq(ports)) == 10

      Enum.each(mocks, &MockServer.stop/1)
    end

    test "is_connected? returns false when it is not connected" do
      {:ok, mock} = MockServer.start()

      refute MockServer.is_connected?(mock)

      MockServer.stop(mock)
    end

    test "is_connected? returns true when it is connected" do
      {:ok, mock} = MockServer.start()
      {:ok, _client_pid} = MockClient.start(mock.url)

      assert MockServer.is_connected?(mock)

      MockServer.stop(mock)
    end

    test "number of connections is correct" do
      {:ok, mock} = MockServer.start()

      assert MockServer.num_connections(mock) == 0

      {:ok, _client} = MockClient.start(mock.url)
      assert MockServer.num_connections(mock) == 1

      {:ok, _client} = MockClient.start(mock.url)
      assert MockServer.num_connections(mock) == 2

      MockServer.stop(mock)
    end

    test "list_clients returns correct client information" do
      {:ok, mock} = MockServer.start()

      assert MockServer.list_clients(mock) == []

      {:ok, _client} = MockClient.start(mock.url)

      clients = MockServer.list_clients(mock)
      assert length(clients) == 1

      [client] = clients
      assert is_binary(client.client_id)
      assert is_pid(client.pid)
      assert client.alive? == true

      MockServer.stop(mock)
    end

    test "multiple mock servers can run simultaneously" do
      {:ok, mock1} = MockServer.start()
      {:ok, mock2} = MockServer.start()

      {:ok, _client1} = MockClient.start(mock1.url)
      {:ok, _client2} = MockClient.start(mock2.url)

      assert MockServer.num_connections(mock1) == 1
      assert MockServer.num_connections(mock2) == 1

      clients1 = MockServer.list_clients(mock1)
      clients2 = MockServer.list_clients(mock2)

      assert length(clients1) == 1
      assert length(clients2) == 1
      assert clients1 != clients2

      MockServer.stop(mock1)
      MockServer.stop(mock2)
    end

    test "stores received messages" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, {:text, "Hello"})
      # Allow time for the message to be processed
      Process.sleep(10)

      assert MockServer.received_messages(mock) == [{:text, "Hello"}]
    end

    test "stores received messages from specific client" do
      {:ok, mock} = MockServer.start()
      {:ok, client1} = MockClient.start(mock.url)
      {:ok, client2} = MockClient.start(mock.url)

      MockClient.send_message(client1, {:text, "Hello"})
      MockClient.send_message(client2, {:text, "World"})
      # Allow time for the message to be processed
      Process.sleep(10)

      clients = MockServer.list_clients(mock)

      messages_by_client =
        Enum.map(clients, fn client ->
          MockServer.received_messages(mock, client.client_id)
        end)

      assert length(clients) == 2
      assert [{:text, "Hello"}] in messages_by_client
      assert [{:text, "World"}] in messages_by_client
    end

    test "replys with correct configured message" do
      {:ok, mock} = MockServer.start()
      msg = {:text, "hello"}
      response = {:text, "world"}
      MockServer.reply_with(mock, msg, response)
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, msg)

      Process.sleep(10)
      assert MockClient.received_messages(client) == [response]
    end

    test "replys with correct configured json message when map get's send" do
      {:ok, mock} = MockServer.start()
      msg = {:text, %{"msg" => "hello"}}
      response = {:text, %{"hello" => "world"}}
      MockServer.reply_with(mock, msg, response)
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, msg)

      Process.sleep(10)
      assert MockClient.received_messages(client) == [response]
    end

    test "replys with correct configured json message when list get's send" do
      {:ok, mock} = MockServer.start()
      msg = {:text, [1, 2, 3]}
      response = {:text, [4, 5, 6]}
      MockServer.reply_with(mock, msg, response)
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, msg)

      Process.sleep(10)
      assert MockClient.received_messages(client) == [response]
    end

    test "replys with correct configured json message when nested list get's send" do
      {:ok, mock} = MockServer.start()
      msg = {:text, [1, 2, %{"number" => 3}]}
      response = {:text, [4, 5, %{"number" => 6}]}
      MockServer.reply_with(mock, msg, response)
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, msg)

      Process.sleep(10)
      assert MockClient.received_messages(client) == [response]
    end

    test "replys with correct configured json message when shorthand notation is used" do
      {:ok, mock} = MockServer.start()
      msg = "Hello"
      response = "World"
      MockServer.reply_with(mock, msg, response)
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, msg)

      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:text, response}]
    end

    test "replys with correct message when function is used as filter" do
      {:ok, mock} = MockServer.start()
      msg = "Hello"
      response = "World"

      filter = fn {_opcode, msg} -> msg == "Hello" end
      MockServer.reply_with(mock, filter, response)
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, msg)

      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:text, response}]
    end

    test "does not reply when filter condition is not met" do
      {:ok, mock} = MockServer.start()
      msg = "Hello"
      response = "World"

      filter = fn {_opcode, msg} -> msg == "Not Hello" end
      MockServer.reply_with(mock, filter, response)
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, msg)

      Process.sleep(10)
      assert MockClient.received_messages(client) == []
    end

    test "replys with modified response from transformer function" do
      {:ok, mock} = MockServer.start()
      msg = "Hello"

      transformer = fn {opcode, msg} -> {opcode, msg <> " World"} end
      MockServer.reply_with(mock, msg, transformer)
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, msg)

      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:text, "Hello World"}]
    end

    test "replyes with modified response when using a filter" do
      {:ok, mock} = MockServer.start()
      msg = "Hello"

      transformer = fn {opcode, msg} -> {opcode, msg <> " World"} end
      filter = fn {_, msg} -> is_binary(msg) end
      MockServer.reply_with(mock, filter, transformer)
      {:ok, client} = MockClient.start(mock.url)

      MockClient.send_message(client, msg)

      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:text, "Hello World"}]
    end
  end
end
