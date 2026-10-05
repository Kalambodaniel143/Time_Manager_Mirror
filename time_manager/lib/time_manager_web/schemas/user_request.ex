defmodule TimeManagerWeb.Schemas.UserRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "UserRequest",
    description:
      "Create (administrator) or update a user. On update, an omitted field keeps its value. " <>
        "To change your own password, send `password` with `current_password`; an " <>
        "administrator resets another user's password without it. The role is changed " <>
        "with PUT /api/users/{id}/role, never here.",
    type: :object,
    properties: %{
      user: %Schema{
        type: :object,
        properties: %{
          username: %Schema{type: :string, example: "alice"},
          email: %Schema{type: :string, format: :email, example: "alice@gotham.gov"},
          password: %Schema{type: :string, format: :password, minLength: 8},
          current_password: %Schema{type: :string, format: :password},
          role: %Schema{
            type: :string,
            enum: ["employee", "manager", "administrator"],
            description: "Create only (administrator); defaults to employee"
          }
        }
      }
    },
    required: [:user],
    example: %{
      "user" => %{"username" => "alice", "email" => "alice@gotham.gov"}
    }
  })
end
