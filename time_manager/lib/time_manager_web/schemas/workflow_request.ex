defmodule TimeManagerWeb.Schemas.WorkflowRequest do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "WorkflowRequest",
    type: :object,
    additionalProperties: true,
    description:
      "Workflow-specific fields. Authors, organizations and reviewers are assigned server-side; explicit target users in assignments are checked against the authenticated scope. See CONTRAT_BACKEND_ORGANISATIONS.md for the exact payloads."
  })
end
