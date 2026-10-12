defmodule TimeManagerWeb.Schemas.WorkflowResponse do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "WorkflowResponse",
    type: :object,
    required: [:data],
    properties: %{
      data: %OpenApiSpex.Schema{
        description: "Persisted workflow object, list or report; never demo data."
      }
    }
  })
end
