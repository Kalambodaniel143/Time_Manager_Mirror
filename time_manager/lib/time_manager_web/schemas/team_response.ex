defmodule TimeManagerWeb.Schemas.TeamResponse do
  require OpenApiSpex
  alias TimeManagerWeb.Schemas.Team

  OpenApiSpex.schema(%{
    title: "TeamResponse",
    type: :object,
    properties: %{data: Team},
    required: [:data]
  })
end
