defmodule TimeManagerWeb.Schemas.ClockResponse do
  require OpenApiSpex
  alias TimeManagerWeb.Schemas.Clock

  OpenApiSpex.schema(%{
    title: "ClockResponse",
    description: "A single clock event, wrapped in a data envelope",
    type: :object,
    properties: %{
      data: Clock
    },
    required: [:data]
  })
end
