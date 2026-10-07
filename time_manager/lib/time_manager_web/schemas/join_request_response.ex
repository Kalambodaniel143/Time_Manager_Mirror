defmodule TimeManagerWeb.Schemas.JoinRequestResponse do
  require OpenApiSpex
  alias TimeManagerWeb.Schemas.JoinRequest

  OpenApiSpex.schema(%{
    title: "JoinRequestResponse",
    description: "A single join request, wrapped in a data envelope",
    type: :object,
    properties: %{data: JoinRequest},
    required: [:data]
  })
end
