defmodule TimeManagerWeb.Schemas.PasswordResetRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PasswordResetRequest",
    type: :object,
    properties: %{
      email: %Schema{type: :string, format: :email, maxLength: 254},
      code: %Schema{
        type: :string,
        pattern: "^[0-9]{8}$",
        description: "Latest emailed code; expires after 15 minutes"
      },
      password: %Schema{
        type: :string,
        format: :password,
        minLength: 8,
        maxLength: 128,
        description: "Common, numeric-only and repeated passwords are rejected"
      }
    },
    required: [:email, :code, :password]
  })
end
