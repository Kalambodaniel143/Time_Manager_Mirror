defmodule TimeManagerWeb.Schemas.TeamsResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.Team

  OpenApiSpex.schema(%{
    title: "TeamsResponse",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Team}},
    required: [:data]
  })
end
