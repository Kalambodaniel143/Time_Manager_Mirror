defmodule TimeManagerWeb.Schemas.ValidationErrorResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ValidationErrorResponse",
    description: "Validation errors, keyed by field name",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        description: "Map of field name to a list of error messages for that field",
        additionalProperties: %Schema{type: :array, items: %Schema{type: :string}}
      }
    },
    example: %{
      "errors" => %{
        "username" => ["can't be blank"],
        "email" => ["can't be blank"]
      }
    }
  })
end
