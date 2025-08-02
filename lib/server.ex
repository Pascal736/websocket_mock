defmodule WebSocketMock do
  @behaviour WebSock

  def start() do
    port = get_port()
    url = "ws://localhost:#{port}/ws"

    registry = {Registry, keys: :unique, name: registry_name(port)}
    webserver = {Bandit, plug: WsRouter, scheme: :http, port: port}

    {:ok, _pid} = Supervisor.start_link([webserver, registry], strategy: :one_for_one)
    {port, url}
  end

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port)
    pid = self()
    client_id = generate_client_id()

    Registry.register(registry_name(port), client_id, pid)

    state = %{received: [], sent: [], client_id: client_id, port: port}
    {:ok, state}
  end

  def is_connected?(port) when is_number(port) do
    num_connections(port) > 0
  end

  def num_connections(port) do
    list_clients(port) |> length()
  end

  def list_clients(port) do
    Registry.select(registry_name(port), [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Enum.map(fn {client_id, pid, metadata} ->
      %{
        client_id: client_id,
        pid: pid,
        metadata: metadata,
        alive?: Process.alive?(pid)
      }
    end)
  end

  def send_message(port, client_id, message) do
    case Registry.lookup(registry_name(port), client_id) do
      [{pid, _}] ->
        send(pid, {:server_message, message})
        :ok

      [] ->
        {:error, :client_not_found}
    end
  end

  @impl true
  def handle_info({:server_message, message}, state) do
    state = %{state | sent: [message | state.sent]}
    {:push, message, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, state) do
    {:ok, state}
  end

  @impl true
  def handle_in({message, [opcode: :text]}, state) do
    state = %{state | received: [message | state.received]}
    {:push, {:text, "echo: #{inspect(message)}"}, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  defp get_port do
    unless Process.whereis(__MODULE__), do: start_ports_agent()

    Agent.get_and_update(__MODULE__, fn port -> {port, port + 1} end)
  end

  defp start_ports_agent do
    Agent.start(fn -> Enum.random(50_000..63_000) end, name: __MODULE__)
  end

  defp registry_name(port) do
    String.to_atom("WebSocketRegistry_#{port}")
  end

  defp generate_client_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end

defmodule WsRouter do
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  get "/ws" do
    port = conn.port

    conn
    |> WebSockAdapter.upgrade(WebSocketMock, [port: port], timeout: 60_000)
    |> halt()
  end
end
