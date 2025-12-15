defmodule WebSocketMock do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("\n## Installation", parts: 2)
             |> then(fn [preamble, body] ->
               description =
                 preamble
                 |> String.split("\n")
                 |> Enum.reject(&(&1 =~ ~r/^#|^\s*\[/))
                 |> Enum.join("\n")
                 |> String.trim()

               description <> "\n\n## Installation" <> body
             end)
             |> String.split("\n## Documentation", parts: 2)
             |> List.first()
end
