defmodule TimeManagerWeb.Schemas.RegisterRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "RegisterRequest",
    description: "Self-registration. The account is always created with the employee role.",
    type: :object,
    properties: %{
      user: %Schema{
        type: :object,
        properties: %{
          username: %Schema{type: :string, example: "alice"},
          email: %Schema{type: :string, format: :email, example: "alice@gotham.gov"},
          password: %Schema{type: :string, format: :password, minLength: 8}
        },
        required: [:username, :email, :password]
      }
    },
    required: [:user]
  })
end
