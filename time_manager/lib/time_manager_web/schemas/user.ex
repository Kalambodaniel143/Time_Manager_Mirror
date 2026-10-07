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
      first_name: %Schema{type: :string, nullable: true, example: "Sara"},
      last_name: %Schema{type: :string, nullable: true, example: "Martin"},
      organization_id: %Schema{type: :string, format: :uuid, nullable: true},
      gender: %Schema{
        type: :string,
        nullable: true,
        enum: ["female", "male", "non_binary", "unspecified"],
        description: "Only for the user themselves and their organization's administrators"
      },
      birth_date: %Schema{type: :string, format: :date, nullable: true},
      birth_place: %Schema{type: :string, nullable: true},
      role: %Schema{
        type: :string,
        enum: ["employee", "manager", "administrator"],
        example: "employee"
      },
      created_at: %Schema{type: :string, format: :"date-time", description: "Same as inserted_at"},
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
