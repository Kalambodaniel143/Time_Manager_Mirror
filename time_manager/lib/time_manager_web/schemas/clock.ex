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
        pattern: ~S(^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$),
        description: "When the clock event happened (YYYY-MM-DD hh:mm:ss, UTC)",
        example: "2026-09-23 08:00:00"
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
