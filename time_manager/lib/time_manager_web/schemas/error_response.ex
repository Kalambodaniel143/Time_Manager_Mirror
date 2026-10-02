defmodule TimeManagerWeb.Schemas.ErrorResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ErrorResponse",
    description: "A generic error (not found, bad request, ...)",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        properties: %{
          detail: %Schema{type: :string, example: "Not Found"}
        }
      }
    },
    example: %{"errors" => %{"detail" => "Not Found"}}
  })
end
