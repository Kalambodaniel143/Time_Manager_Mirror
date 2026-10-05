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
      role: %Schema{
        type: :string,
        enum: ["employee", "manager", "administrator"],
        example: "employee"
      },
      inserted_at: %Schema{
        type: :string,
        format: :"date-time",
        description: "Creation timestamp",
        example: "2026-09-22T08:15:25Z",
        nullable: false
      }
    },
    required: [:id, :username, :email, :role]
  })
end
