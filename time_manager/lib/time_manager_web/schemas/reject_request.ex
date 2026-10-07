defmodule TimeManagerWeb.Schemas.RejectRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "RejectRequest",
    description: "The reason of the rejection, shown to the applicant (1 to 500 characters)",
    type: :object,
    properties: %{reason: %Schema{type: :string, minLength: 1, maxLength: 500}},
    required: [:reason]
  })
end
