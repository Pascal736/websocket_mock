defmodule WebsocketMock.MixProject do
  use Mix.Project

  def project do
    [
      app: :websocket_mock,
      description: "A lightweight WebSocket mock server for testing",
      version: "0.3.0",
      elixir: "~> 1.18",
      deps: deps(),
      package: package()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:plug, "~> 1.18"},
      {:bandit, "~> 1.7"},
      {:websock_adapter, "~> 0.5"},
      {:jason, "~> 1.4"},
      # TODO: switch back to `{:websockex, "~> 0.5", hex: :websockex_wt}` once a fixed version (>0.5.0) is published.
      {:websockex,
       github: "dominicletz/websockex", ref: "2ed0adaf4fd9ae87caac5098159d4f682701264d"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Pascal Pfeiffer"],
      links: %{
        "GitHub" => "https://github.com/pascal736/websocket_mock"
      }
    ]
  end
end
