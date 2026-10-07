defmodule TimeManagerWeb.TeamController do
  @moduledoc """
  Teams. Everyone can read the teams they belong to or manage; only an
  administrator creates the teams of their organization, names their manager
  and composes them. Teams of another organization answer 404.
  """
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import TimeManagerWeb.Authz

  alias TimeManager.Accounts
  alias TimeManager.Authorization
  alias TimeManager.Teams
  alias TimeManagerWeb.Schemas.{ErrorResponse, MemberRequest, TeamRequest, TeamResponse}
  alias TimeManagerWeb.Schemas.{TeamsResponse, ValidationErrorResponse}

  action_fallback TimeManagerWeb.FallbackController

  tags(["teams"])

  @team_id [in: :path, type: :integer, description: "Team ID", example: 1]

  operation(:index,
    summary: "List teams",
    description:
      "Administrators: all teams. Others: the teams they manage or belong to. " <>
        "Members are only listed for teams the caller manages (or for an administrator).",
    responses: [ok: {"Teams", "application/json", TeamsResponse}]
  )

  def index(conn, _params) do
    me = current_user(conn)

    teams =
      if Authorization.administrator?(me) do
        Teams.list_teams(me.organization_id)
      else
        managed = Teams.list_managed_teams(me)
        managed_ids = MapSet.new(managed, & &1.id)

        member_of =
          me
          |> Teams.list_member_teams()
          |> Enum.reject(&MapSet.member?(managed_ids, &1.id))
          # An employee sees the names of their teams, not the other members.
          |> Enum.map(&%{&1 | members: []})

        managed ++ member_of
      end

    render(conn, :index, teams: teams)
  end

  operation(:show,
    summary: "Get a team",
    parameters: [id: @team_id],
    responses: [
      ok: {"Team", "application/json", TeamResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"Team not found", "application/json", ErrorResponse}
    ]
  )

  def show(conn, %{"id" => id}) do
    me = current_user(conn)

    with {:ok, team} <- Teams.fetch_team(id),
         :ok <-
           authorize(Authorization.administrator_of_team?(me, team) or team.manager_id == me.id) do
      render(conn, :show, team: team)
    end
  end

  operation(:create,
    summary: "Create a team (administrator)",
    request_body: {"Team", "application/json", TeamRequest},
    responses: [
      created: {"Team created", "application/json", TeamResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def create(conn, %{"team" => attrs}) when is_map(attrs) do
    me = current_user(conn)

    with :ok <- authorize(Authorization.administrator?(me)),
         {:ok, team} <- Teams.create_team(attrs, me.organization_id) do
      conn
      |> put_status(:created)
      |> render(:show, team: team)
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  operation(:update,
    summary: "Rename a team or change its manager (administrator)",
    parameters: [id: @team_id],
    request_body: {"Team", "application/json", TeamRequest},
    responses: [
      ok: {"Team updated", "application/json", TeamResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"Team not found", "application/json", ErrorResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def update(conn, %{"id" => id, "team" => attrs}) when is_map(attrs) do
    with {:ok, team} <- fetch_administered_team(current_user(conn), id),
         {:ok, team} <- Teams.update_team(team, attrs) do
      render(conn, :show, team: team)
    end
  end

  def update(_conn, _params), do: {:error, :bad_request}

  operation(:delete,
    summary: "Delete a team (administrator)",
    parameters: [id: @team_id],
    responses: [
      no_content: "Team deleted",
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"Team not found", "application/json", ErrorResponse}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, team} <- fetch_administered_team(current_user(conn), id),
         {:ok, _team} <- Teams.delete_team(team) do
      send_resp(conn, :no_content, "")
    end
  end

  operation(:add_member,
    summary: "Add a member to a team (administrator)",
    parameters: [id: @team_id],
    request_body: {"Member", "application/json", MemberRequest},
    responses: [
      ok: {"Team", "application/json", TeamResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"Team or user not found", "application/json", ErrorResponse}
    ]
  )

  def add_member(conn, %{"id" => id, "user_id" => user_id}) do
    with {:ok, team} <- fetch_administered_team(current_user(conn), id),
         {:ok, user} <- Accounts.fetch_user(user_id),
         {:ok, team} <- Teams.add_member(team, user) do
      render(conn, :show, team: team)
    end
  end

  def add_member(_conn, _params), do: {:error, :bad_request}

  operation(:remove_member,
    summary: "Remove a member from a team (administrator)",
    parameters: [
      id: @team_id,
      user_id: [in: :path, type: :integer, description: "User ID", example: 3]
    ],
    responses: [
      ok: {"Team", "application/json", TeamResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"Team or user not found", "application/json", ErrorResponse}
    ]
  )

  def remove_member(conn, %{"id" => id, "user_id" => user_id}) do
    with {:ok, team} <- fetch_administered_team(current_user(conn), id),
         {:ok, user} <- Accounts.fetch_user(user_id),
         {:ok, team} <- Teams.remove_member(team, user) do
      render(conn, :show, team: team)
    end
  end

  # An administrator only reaches the teams of their organization; the others
  # do not exist for them (404). Non-administrators get 403.
  defp fetch_administered_team(me, id) do
    with :ok <- authorize(Authorization.administrator?(me)),
         {:ok, team} <- Teams.fetch_team(id) do
      if Authorization.administrator_of_team?(me, team),
        do: {:ok, team},
        else: {:error, :not_found}
    end
  end
end
