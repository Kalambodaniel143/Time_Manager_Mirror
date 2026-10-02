defmodule TimeManagerWeb.Schemas.Clock do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Clock",
    description: "A clock-in or clock-out event for a user",
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Clock ID", example: 1},
      time: %Schema{
        type: :string,
        format: :"date-time",
        description: "When the clock event happened (ISO 8601, UTC)",
        example: "2026-09-23T08:00:00Z"
      },
      status: %Schema{
        type: :boolean,
        description: "true = clock-in (arrival), false = clock-out (departure)",
        example: true
      },
      user_id: %Schema{type: :integer, description: "Owning user's ID", example: 1}
    },
    required: [:id, :time, :status, :user_id]
  })
end
