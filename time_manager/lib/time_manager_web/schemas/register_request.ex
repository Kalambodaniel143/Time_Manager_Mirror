defmodule TimeManagerWeb.Schemas.RegisterRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "RegisterRequest",
    description:
      "Registration details. The account is created only after administrator approval.",
    type: :object,
    properties: %{
      user: %Schema{
        type: :object,
        properties: %{
          first_name: %Schema{type: :string, example: "Alice"},
          last_name: %Schema{type: :string, example: "Martin"},
          email: %Schema{type: :string, format: :email, example: "alice@gotham.gov"},
          gender: %Schema{type: :string},
          birth_date: %Schema{type: :string, format: :date},
          birth_place: %Schema{type: :string}
        },
        required: [:first_name, :last_name, :email, :gender, :birth_date, :birth_place]
      }
    },
    required: [:user]
  })
end
