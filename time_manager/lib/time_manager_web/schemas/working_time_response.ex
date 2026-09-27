defmodule TimeManagerWeb.Schemas.WorkingTimeResponse do
  require OpenApiSpex
  alias TimeManagerWeb.Schemas.WorkingTime

  OpenApiSpex.schema(%{
    title: "WorkingTimeResponse",
    description: "A single working time slot, wrapped in a data envelope",
    type: :object,
    properties: %{
      data: WorkingTime
    },
    required: [:data]
  })
end
