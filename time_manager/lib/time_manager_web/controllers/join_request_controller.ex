defmodule TimeManagerWeb.JoinRequestController do
  @moduledoc """
  Requests to join an organization: public submission and tracking, review by
  the organization's administrators.

  Submitting creates no account and opens no session. The private reference
  returned at submission is the only way to follow the request publicly; it is
  sent in the body, never in the URL, so that it does not end up in logs.
  """
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import TimeManagerWeb.Authz

  alias TimeManager.{Authorization, Organizations}
  alias TimeManagerWeb.Plugs.RateLimit
  alias TimeManagerWeb.Schemas.{ApproveRequest, ApproveResponse, ConflictResponse}
  alias TimeManagerWeb.Schemas.{ErrorResponse, JoinRequestCreateRequest, JoinRequestReceipt}

  alias TimeManagerWeb.Schemas.{
    JoinRequestResponse,
    JoinRequestsResponse,
    JoinRequestStatusRequest
  }

  alias TimeManagerWeb.Schemas.{RejectRequest, ValidationErrorResponse}

  action_fallback TimeManagerWeb.FallbackController

  plug RateLimit, [bucket: :join_request, limit: 10] when action == :create
  plug RateLimit, [bucket: :join_request_status, limit: 30] when action == :status

  tags(["join requests"])

  @org_id [
    in: :path,
    schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
    description: "Organization ID"
  ]
  @id [
    in: :path,
    schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
    description: "Join request ID"
  ]

  operation(:create,
    summary: "Ask to join an organization",
    description:
      "Public. Records a pending request and returns a private tracking reference. 409 when " <>
        "the e-mail already has an account or a pending request in this organization.",
    security: [],
    request_body: {"Request", "application/json", JoinRequestCreateRequest},
    responses: [
      created: {"Request recorded", "application/json", JoinRequestReceipt},
      not_found: {"Unknown organization", "application/json", ErrorResponse},
      conflict: {"Account or pending request exists", "application/json", ConflictResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def create(conn, %{"organization_id" => organization_id, "profile" => profile})
      when is_map(profile) do
    with {:ok, request, reference} <- Organizations.submit_join_request(organization_id, profile) do
      conn
      |> put_status(:created)
      |> render(:receipt, request: request, reference: reference)
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  operation(:status,
    summary: "Follow a request with its private reference",
    description: "Public. Only the status and the rejection reason are returned.",
    security: [],
    request_body: {"Reference", "application/json", JoinRequestStatusRequest},
    responses: [
      ok: {"Request status", "application/json", JoinRequestReceipt},
      not_found: {"Unknown reference", "application/json", ErrorResponse}
    ]
  )

  def status(conn, %{"reference" => reference}) do
    with {:ok, request} <- Organizations.fetch_join_request_by_reference(reference) do
      render(conn, :status, request: request, reference: reference)
    end
  end

  def status(_conn, _params), do: {:error, :bad_request}

  operation(:index,
    summary: "List the requests of an organization (its administrators)",
    parameters: [org_id: @org_id],
    responses: [
      ok: {"Requests", "application/json", JoinRequestsResponse},
      forbidden: {"Not an administrator of this organization", "application/json", ErrorResponse}
    ]
  )

  def index(conn, %{"org_id" => org_id}) do
    with {:ok, me} <- organization_admin(conn, org_id) do
      render(conn, :index, requests: Organizations.list_join_requests(me.organization_id))
    end
  end

  operation(:approve,
    summary: "Approve a request: create the employee (its administrators)",
    description:
      "Creates the employee with the password chosen by the administrator, atomically. The " <>
        "password is not returned. 409 if the request was already reviewed.",
    parameters: [org_id: @org_id, id: @id],
    request_body: {"Password", "application/json", ApproveRequest},
    responses: [
      ok: {"Request approved", "application/json", ApproveResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"Unknown request", "application/json", ErrorResponse},
      conflict: {"Already reviewed or e-mail taken", "application/json", ConflictResponse},
      unprocessable_entity: {"Invalid password", "application/json", ValidationErrorResponse}
    ]
  )

  def approve(conn, %{"org_id" => org_id, "id" => id, "password" => password}) do
    with {:ok, me} <- organization_admin(conn, org_id),
         {:ok, result} <-
           Organizations.approve_join_request(me.organization_id, id, password, me) do
      render(conn, :approved, result)
    end
  end

  def approve(_conn, _params), do: {:error, :bad_request}

  operation(:reject,
    summary: "Reject a request with a reason (its administrators)",
    parameters: [org_id: @org_id, id: @id],
    request_body: {"Reason", "application/json", RejectRequest},
    responses: [
      ok: {"Request rejected", "application/json", JoinRequestResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"Unknown request", "application/json", ErrorResponse},
      conflict: {"Already reviewed", "application/json", ConflictResponse},
      unprocessable_entity: {"Invalid reason", "application/json", ValidationErrorResponse}
    ]
  )

  def reject(conn, %{"org_id" => org_id, "id" => id, "reason" => reason})
      when is_binary(reason) do
    with {:ok, me} <- organization_admin(conn, org_id),
         {:ok, request} <- Organizations.reject_join_request(me.organization_id, id, reason, me) do
      render(conn, :show, request: request)
    end
  end

  def reject(_conn, _params), do: {:error, :bad_request}

  defp organization_admin(conn, org_id) do
    me = current_user(conn)

    with :ok <- authorize(Authorization.organization_admin?(me, org_id)), do: {:ok, me}
  end
end
