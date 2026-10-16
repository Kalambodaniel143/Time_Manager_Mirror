defmodule TimeManagerWeb.RoleController do
  @moduledoc "Roles are predefined and read-only: there is no route to change them."
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TimeManager.Accounts
  alias TimeManagerWeb.Schemas.RolesResponse

  tags(["roles"])

  operation(:index,
    summary: "List the predefined roles",
    responses: [ok: {"Roles", "application/json", RolesResponse}]
  )

  def index(conn, _params), do: render(conn, :index, roles: Accounts.list_roles())
end
