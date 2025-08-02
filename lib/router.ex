defmodule WebSocketMock.Router do
  @moduledoc false
  use Plug.Router

  def init(registry_name) when is_atom(registry_name) do
    registry_name
  end

  def call(conn, registry_name) do
    conn = assign(conn, :registry_name, registry_name)
    super(conn, [])
  end

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  get "/ws" do
    registry_name = conn.assigns.registry_name
    port = conn.port

    conn
    |> WebSockAdapter.upgrade(WebSocketMock.Handler, [port: port, registry_name: registry_name],
      timeout: 60_000
    )
    |> halt()
  end
end
