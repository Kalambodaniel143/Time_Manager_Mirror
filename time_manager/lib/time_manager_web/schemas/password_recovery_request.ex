defmodule TimeManagerWeb.Schemas.PasswordRecoveryRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PasswordRecoveryRequest",
    type: :object,
    properties: %{email: %Schema{type: :string, format: :email, maxLength: 254}},
    required: [:email]
  })
end
