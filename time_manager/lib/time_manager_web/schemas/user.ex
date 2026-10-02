defmodule TimeManagerWeb.Schemas.User do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "User",
    description: "A user account",
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "User ID", example: 1},
      username: %Schema{type: :string, description: "Username", example: "alice"},
      email: %Schema{
        type: :string,
        format: :email,
        description: "Email address",
        example: "alice@example.com"
      },
      inserted_at: %Schema{
        type: :string,
        format: :"date-time",
        description: "Creation timestamp. Only present on show/index/update responses.",
        example: "2026-09-22T08:15:25Z",
        nullable: true
      }
    },
    required: [:id, :username, :email]
  })
end
