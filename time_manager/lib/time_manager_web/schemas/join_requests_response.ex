defmodule TimeManagerWeb.Schemas.JoinRequestsResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.JoinRequest

  OpenApiSpex.schema(%{
    title: "JoinRequestsResponse",
    description: "The join requests of an organization",
    type: :object,
    properties: %{data: %Schema{type: :array, items: JoinRequest}},
    required: [:data]
  })
end
