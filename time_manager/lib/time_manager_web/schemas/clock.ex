defmodule TimeManagerWeb.Schemas.Clock do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Clock",
    description: "An arrival, departure, pause or resume event for a user",
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
        description: "true = working (arrival/resume), false = not working (pause/departure)",
        example: true
      },
      kind: %Schema{
        type: :string,
        enum: ["arrival", "departure", "pause", "resume"],
        description: "The action recorded by this event",
        example: "arrival"
      },
      user_id: %Schema{type: :integer, description: "Owning user's ID", example: 1}
    },
    required: [:id, :time, :status, :kind, :user_id]
  })
end
