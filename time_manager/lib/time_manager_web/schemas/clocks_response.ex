defmodule TimeManagerWeb.Schemas.ClocksResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.Clock

  OpenApiSpex.schema(%{
    title: "ClocksResponse",
    description: "A list of clock events, wrapped in a data envelope",
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: Clock}
    },
    required: [:data]
  })
end
