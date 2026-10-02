defmodule TimeManagerWeb.Schemas.UsersResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.User

  OpenApiSpex.schema(%{
    title: "UsersResponse",
    description: "A list of users, wrapped in a data envelope",
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: User}
    },
    required: [:data]
  })
end
