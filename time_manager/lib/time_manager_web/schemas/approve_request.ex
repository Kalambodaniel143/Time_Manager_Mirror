defmodule TimeManagerWeb.Schemas.ApproveRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ApproveRequest",
    description: "Credentials and initial role chosen by the administrator.",
    type: :object,
    properties: %{
      username: %Schema{type: :string, minLength: 1, maxLength: 100},
      password: %Schema{type: :string, format: :password, minLength: 8, maxLength: 128},
      role: %Schema{type: :string, enum: ["employee", "manager"], default: "employee"}
    },
    required: [:username, :password]
  })
end
