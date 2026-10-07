defmodule TimeManagerWeb.OrganizationController do
  @moduledoc """
  Organizations: public creation and lookup, and the members management of an
  organization by its administrators.

  The `:org_id` of the URL is never trusted: it must be the organization of the
  logged-in administrator, otherwise 403 (whether it exists or not).
  """
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import TimeManagerWeb.Authz

  alias TimeManager.{Accounts, Authorization, Organizations}
  alias TimeManagerWeb.AuthController
  alias TimeManagerWeb.Plugs.RateLimit
  alias TimeManagerWeb.Schemas.{ConflictResponse, ErrorResponse, MemberRoleRequest}
  alias TimeManagerWeb.Schemas.{OrganizationLookupResponse, OrganizationRequest}
  alias TimeManagerWeb.Schemas.{SessionResponse, UserResponse, UsersResponse}
  alias TimeManagerWeb.Schemas.ValidationErrorResponse

  action_fallback TimeManagerWeb.FallbackController

  plug RateLimit, [bucket: :create_organization, limit: 10] when action == :create
  plug RateLimit, [bucket: :lookup_organization, limit: 60] when action == :lookup

  tags(["organizations"])

  @org_id [
    in: :path,
    schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
    description: "Organization ID"
  ]

  operation(:create,
    summary: "Create an organization and its administrator, then log in",
    description:
      "Public. Creates the organization and its administrator atomically, sets the session " <>
        "cookie and returns the session with the CSRF token. No role is read from the body. " <>
        "409 when the name (ignoring case, accents and spaces) or the e-mail is taken.",
    security: [],
    request_body: {"Organization", "application/json", OrganizationRequest},
    responses: [
      created: {"Organization created", "application/json", SessionResponse},
      conflict: {"Name or e-mail taken", "application/json", ConflictResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def create(conn, %{"name" => name, "profile" => profile, "password" => password})
      when is_map(profile) do
    with {:ok, admin} <- Organizations.create_organization(name, profile, password) do
      AuthController.start_session(conn, admin, :created)
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  operation(:lookup,
    summary: "Find an organization by its exact name",
    description:
      "Public. The name is compared ignoring case, accents and successive spaces. Only the " <>
        "id and the name are returned.",
    security: [],
    parameters: [name: [in: :query, type: :string, required: true, example: "Atelier Gotham"]],
    responses: [
      ok: {"Organization", "application/json", OrganizationLookupResponse},
      not_found: {"No organization with this name", "application/json", ErrorResponse}
    ]
  )

  def lookup(conn, params) do
    with {:ok, organization} <- Organizations.lookup_organization(params["name"]) do
      render(conn, :lookup, organization: organization)
    end
  end

  operation(:members,
    summary: "List the members of an organization (its administrators)",
    parameters: [org_id: @org_id],
    responses: [
      ok: {"Members", "application/json", UsersResponse},
      forbidden: {"Not an administrator of this organization", "application/json", ErrorResponse}
    ]
  )

  def members(conn, %{"org_id" => org_id}) do
    with :ok <- authorize(Authorization.organization_admin?(current_user(conn), org_id)) do
      render(conn, :members, users: Accounts.list_organization_members(org_id))
    end
  end

  operation(:update_member,
    summary: "Make a member employee or manager (its administrators)",
    description:
      "Only employee and manager are accepted; an administrator cannot be changed here. " <>
        "The new role applies from the member's next request.",
    parameters: [
      org_id: @org_id,
      id: [in: :path, type: :integer, description: "User ID", example: 14]
    ],
    request_body: {"New role", "application/json", MemberRoleRequest},
    responses: [
      ok: {"Member updated", "application/json", UserResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"Not a member of this organization", "application/json", ErrorResponse},
      unprocessable_entity: {"Unknown role", "application/json", ValidationErrorResponse}
    ]
  )

  def update_member(conn, %{"org_id" => org_id, "id" => id, "role" => role}) do
    with :ok <- authorize(Authorization.organization_admin?(current_user(conn), org_id)),
         {:ok, user} <-
           Organizations.set_member_role(current_user(conn).organization_id, id, role) do
      render(conn, :member, user: user)
    end
  end

  def update_member(_conn, _params), do: {:error, :bad_request}
end
