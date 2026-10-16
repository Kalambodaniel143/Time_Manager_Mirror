defmodule TimeManagerWeb.Schemas.LoginRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "LoginRequest",
    description: "E-mail and password of an existing account",
    type: :object,
    properties: %{
      email: %Schema{type: :string, format: :email, example: "admin@gotham.gov"},
      password: %Schema{type: :string, format: :password, example: "correct horse battery"}
    },
    required: [:email, :password]
  })
end
