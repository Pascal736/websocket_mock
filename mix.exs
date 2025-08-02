defmodule WebsocketMock.MixProject do
  use Mix.Project

  def project do
    [
      app: :websocket_mock,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.18"},
      {:bandit, "~> 1.7"},
      {:websock_adapter, "~> 0.5.8"},
      {:websockex, "~> 0.5.0", hex: :websockex_wt}
    ]
  end
end
