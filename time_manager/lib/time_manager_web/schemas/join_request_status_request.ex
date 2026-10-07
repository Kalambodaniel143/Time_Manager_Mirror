defmodule TimeManagerWeb.Schemas.JoinRequestStatusRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "JoinRequestStatusRequest",
    description: "The private reference returned when the request was sent",
    type: :object,
    properties: %{reference: %Schema{type: :string}},
    required: [:reference]
  })
end
