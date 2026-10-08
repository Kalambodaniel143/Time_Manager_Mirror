defmodule TimeManagerWeb.Schemas.ClockRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ClockRequest",
    description: "Request body to record an arrival, departure, pause or resume",
    type: :object,
    properties: %{
      clock: %Schema{
        type: :object,
        properties: %{
          time: %Schema{
            type: :string,
            description:
              "UTC timestamp, YYYY-MM-DD hh:mm:ss or ISO 8601; must not be in the future",
            example: "2026-09-23 08:00:00"
          },
          status: %Schema{
            type: :boolean,
            description: "true = arrival/resume, false = pause/departure",
            example: true
          },
          kind: %Schema{
            type: :string,
            enum: ["arrival", "departure", "pause", "resume"],
            description:
              "Optional. Without kind, status true means arrival and false means departure.",
            example: "arrival"
          }
        },
        required: [:time, :status]
      }
    },
    required: [:clock],
    example: %{
      "clock" => %{"time" => "2026-09-23 08:00:00", "status" => true}
    }
  })
end
