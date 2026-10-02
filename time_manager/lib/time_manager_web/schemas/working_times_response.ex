defmodule TimeManagerWeb.Schemas.WorkingTimesResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.WorkingTime

  OpenApiSpex.schema(%{
    title: "WorkingTimesResponse",
    description: "A list of working time slots, wrapped in a data envelope",
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: WorkingTime}
    },
    required: [:data]
  })
end
