defmodule WebsocketMockTest.SendMessagesTest do
  alias WebSocketMock.WsClient
  use ExUnit.Case

  doctest WebSocketMock

  describe "send messages" do
    test "works with strings" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client} = WsClient.start(mock.url)

      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)

      :ok = WebSocketMock.send_message(mock, client_id, {:text, "Hello, WebSocket!"})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert WsClient.received_messages(client) == [{:text, "Hello, WebSocket!"}]

      WebSocketMock.stop(mock)
    end

    test "works with strings and short notation" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client} = WsClient.start(mock.url)

      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)

      :ok = WebSocketMock.send_message(mock, client_id, "Hello, WebSocket!")

      # Allow time for the message to be processed
      Process.sleep(10)
      assert WsClient.received_messages(client) == [{:text, "Hello, WebSocket!"}]

      WebSocketMock.stop(mock)
    end

    test "works with non strings and short notation" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client} = WsClient.start(mock.url)

      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)

      :ok = WebSocketMock.send_message(mock, client_id, %{"hello" => "world"})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert WsClient.received_messages(client) == [{:text, %{"hello" => "world"}}]

      WebSocketMock.stop(mock)
    end

    test "works with binary data" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client} = WsClient.start(mock.url)

      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)

      :ok = WebSocketMock.send_message(mock, client_id, {:binary, <<1, 2, 3>>})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert WsClient.received_messages(client) == [{:binary, <<1, 2, 3>>}]

      WebSocketMock.stop(mock)
    end

    test "works with maps" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client} = WsClient.start(mock.url)

      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)

      :ok =
        WebSocketMock.send_message(mock, client_id, {:text, %{"message" => "Hello, WebSocket!"}})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert WsClient.received_messages(client) == [{:text, %{"message" => "Hello, WebSocket!"}}]

      WebSocketMock.stop(mock)
    end

    test "works with lists" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client} = WsClient.start(mock.url)

      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)

      :ok = WebSocketMock.send_message(mock, client_id, {:text, [1, 2, 3]})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert WsClient.received_messages(client) == [{:text, [1, 2, 3]}]

      WebSocketMock.stop(mock)
    end

    test "works with ping with data" do
      {:ok, mock} = WebSocketMock.start()
      {:ok, client} = WsClient.start(mock.url)

      [%{client_id: client_id}] = WebSocketMock.list_clients(mock)

      :ok = WebSocketMock.send_message(mock, client_id, {:ping, "ping-data"})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert WsClient.received_messages(client) == [{:ping, "ping-data"}]

      WebSocketMock.stop(mock)
    end

    test "returns error for non-existent client" do
      {:ok, mock} = WebSocketMock.start()

      result = WebSocketMock.send_message(mock, "non-existent-client-id", {:text, "Hello"})
      assert result == {:error, :client_not_found}

      WebSocketMock.stop(mock)
    end
  end
end
