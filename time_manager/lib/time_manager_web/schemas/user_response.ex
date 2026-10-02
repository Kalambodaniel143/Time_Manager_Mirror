defmodule TimeManagerWeb.Schemas.UserResponse do
  require OpenApiSpex
  alias TimeManagerWeb.Schemas.User

  OpenApiSpex.schema(%{
    title: "UserResponse",
    description: "A single user, wrapped in a data envelope",
    type: :object,
    properties: %{
      data: User
    },
    required: [:data]
  })
end
