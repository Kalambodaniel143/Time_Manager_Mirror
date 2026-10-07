defmodule TimeManagerWeb.Schemas.JoinRequestReceipt do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "JoinRequestReceipt",
    description:
      "Public view of a request: never the profile. rejection_reason is absent from the " <>
        "initial receipt and null unless the request is rejected.",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :string, format: :uuid},
          reference: %Schema{type: :string},
          organization_name: %Schema{type: :string, example: "Atelier Gotham"},
          status: %Schema{type: :string, enum: ["pending", "approved", "rejected"]},
          rejection_reason: %Schema{type: :string, nullable: true}
        },
        required: [:id, :reference, :organization_name, :status]
      }
    },
    required: [:data]
  })
end
