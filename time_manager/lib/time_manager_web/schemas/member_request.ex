defmodule TimeManagerWeb.Schemas.MemberRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "MemberRequest",
    description: "The user to add to the team",
    type: :object,
    properties: %{user_id: %Schema{type: :integer, example: 3}},
    required: [:user_id]
  })
end
