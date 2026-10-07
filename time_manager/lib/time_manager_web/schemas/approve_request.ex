defmodule TimeManagerWeb.Schemas.ApproveRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ApproveRequest",
    description:
      "The password the administrator chose for the new employee (8 to 128 characters)",
    type: :object,
    properties: %{
      password: %Schema{type: :string, format: :password, minLength: 8, maxLength: 128}
    },
    required: [:password]
  })
end
