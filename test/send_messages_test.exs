defmodule WebSocketMockTest.SendMessagesTest do
  alias WebSocketMock.MockClient
  alias WebSocketMock.MockServer
  use ExUnit.Case

  describe "send messages" do
    test "works with strings" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, {:text, "Hello, WebSocket!"})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:text, "Hello, WebSocket!"}]

      MockServer.stop(mock)
    end

    test "works with strings and short notation" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, "Hello, WebSocket!")

      # Allow time for the message to be processed
      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:text, "Hello, WebSocket!"}]

      MockServer.stop(mock)
    end

    test "works with non strings and short notation" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, %{"hello" => "world"})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:text, %{"hello" => "world"}}]

      MockServer.stop(mock)
    end

    test "works with binary data" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, {:binary, <<1, 2, 3>>})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:binary, <<1, 2, 3>>}]

      MockServer.stop(mock)
    end

    test "works with maps" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok =
        MockServer.send_message(mock, client_id, {:text, %{"message" => "Hello, WebSocket!"}})

      # Allow time for the message to be processed
      Process.sleep(10)

      assert MockClient.received_messages(client) == [
               {:text, %{"message" => "Hello, WebSocket!"}}
             ]

      MockServer.stop(mock)
    end

    test "works with lists" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, {:text, [1, 2, 3]})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:text, [1, 2, 3]}]

      MockServer.stop(mock)
    end

    test "works with ping with data" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, {:ping, "ping-data"})

      # Allow time for the message to be processed
      Process.sleep(10)
      assert MockClient.received_messages(client) == [{:ping, "ping-data"}]

      MockServer.stop(mock)
    end

    test "returns error for non-existent client" do
      {:ok, mock} = MockServer.start()

      result = MockServer.send_message(mock, "non-existent-client-id", {:text, "Hello"})
      assert result == {:error, :client_not_found}

      MockServer.stop(mock)
    end
  end
end
