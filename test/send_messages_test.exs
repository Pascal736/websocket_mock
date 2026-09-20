defmodule WebSocketMockTest.SendMessagesTest do
  alias WebSocketMock.MockClient
  alias WebSocketMock.MockServer
  alias WebSocketMock.Sync
  use ExUnit.Case

  describe "send messages" do
    test "works with strings" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, {:text, "Hello, WebSocket!"})

      assert Sync.wait_until(fn -> MockClient.received_messages(client) end) ==
               [{:text, "Hello, WebSocket!"}]

      MockServer.stop(mock)
    end

    test "works with strings and short notation" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, "Hello, WebSocket!")

      assert Sync.wait_until(fn -> MockClient.received_messages(client) end) ==
               [{:text, "Hello, WebSocket!"}]

      MockServer.stop(mock)
    end

    test "works with non strings and short notation" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, %{"hello" => "world"})

      assert Sync.wait_until(fn -> MockClient.received_messages(client) end) ==
               [{:text, %{"hello" => "world"}}]

      MockServer.stop(mock)
    end

    test "works with binary data" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, {:binary, <<1, 2, 3>>})

      assert Sync.wait_until(fn -> MockClient.received_messages(client) end) ==
               [{:binary, <<1, 2, 3>>}]

      MockServer.stop(mock)
    end

    test "works with maps" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok =
        MockServer.send_message(mock, client_id, {:text, %{"message" => "Hello, WebSocket!"}})

      assert Sync.wait_until(fn -> MockClient.received_messages(client) end) == [
               {:text, %{"message" => "Hello, WebSocket!"}}
             ]

      MockServer.stop(mock)
    end

    test "works with lists" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, {:text, [1, 2, 3]})

      assert Sync.wait_until(fn -> MockClient.received_messages(client) end) ==
               [{:text, [1, 2, 3]}]

      MockServer.stop(mock)
    end

    test "works with ping with data" do
      {:ok, mock} = MockServer.start()
      {:ok, client} = MockClient.start(mock.url)

      [%{client_id: client_id}] = MockServer.list_clients(mock)

      :ok = MockServer.send_message(mock, client_id, {:ping, "ping-data"})

      assert Sync.wait_until(fn -> MockClient.received_messages(client) end) ==
               [{:ping, "ping-data"}]

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
