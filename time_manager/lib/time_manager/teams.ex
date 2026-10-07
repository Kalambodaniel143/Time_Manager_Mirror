defmodule TimeManager.Teams do
  @moduledoc """
  Teams, their manager and their members. An employee can belong to several
  teams; each team has at most one manager (`teams.manager_id`).

  A team belongs to the organization of the administrator who created it. Its
  manager and its members must belong to the same organization.

  Composing teams and naming managers is an administrator task: a manager able
  to add people to their team would gain access to those people's hours.
  """

  import Ecto.Query, warn: false

  alias TimeManager.Accounts
  alias TimeManager.Accounts.User
  alias TimeManager.Repo
  alias TimeManager.Teams.Team

  @manager_roles ~w(manager administrator)

  @doc "All teams of an organization (`nil`: teams without organization), with manager and members."
  def list_teams(organization_id) do
    Team |> in_organization(organization_id) |> order_by(:name) |> Repo.all() |> preload_team()
  end

  @doc "Teams managed by the user."
  def list_managed_teams(%User{id: user_id}) do
    from(t in Team, where: t.manager_id == ^user_id, order_by: t.name)
    |> Repo.all()
    |> preload_team()
  end

  @doc "Teams the user is a member of."
  def list_member_teams(%User{id: user_id}) do
    from(t in Team,
      join: m in "team_members",
      on: m.team_id == t.id,
      where: m.user_id == ^user_id,
      order_by: t.name
    )
    |> Repo.all()
    |> preload_team()
  end

  def fetch_team(id) do
    with {:ok, id} <- cast_id(id),
         %Team{} = team <- Repo.get(Team, id) do
      {:ok, preload_team(team)}
    else
      _ -> {:error, :not_found}
    end
  end

  def create_team(attrs, organization_id \\ nil) do
    %Team{organization_id: organization_id}
    |> Team.changeset(attrs)
    |> validate_manager()
    |> Repo.insert()
    |> preload_result()
  end

  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> validate_manager()
    |> Repo.update()
    |> preload_result()
  end

  def delete_team(%Team{} = team), do: Repo.delete(team)

  @doc "Adds a member, who must belong to the team's organization (404 otherwise)."
  def add_member(%Team{organization_id: org}, %User{organization_id: user_org})
      when org != user_org,
      do: {:error, :not_found}

  def add_member(%Team{id: team_id} = team, %User{id: user_id}) do
    Repo.insert_all("team_members", [%{team_id: team_id, user_id: user_id}],
      on_conflict: :nothing
    )

    {:ok, preload_team(team, force: true)}
  end

  def remove_member(%Team{id: team_id} = team, %User{id: user_id}) do
    from(m in "team_members", where: m.team_id == ^team_id and m.user_id == ^user_id)
    |> Repo.delete_all()

    {:ok, preload_team(team, force: true)}
  end

  @doc """
  True when `user_id` is a member of a team managed by `manager_id`. This is
  the "my teams" scope of a manager.
  """
  def manages?(manager_id, user_id) do
    from(t in Team,
      join: m in "team_members",
      on: m.team_id == t.id,
      where: t.manager_id == ^manager_id and m.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  @doc "Ids of every member of the teams managed by `manager_id`."
  def managed_member_ids(manager_id) do
    from(t in Team,
      join: m in "team_members",
      on: m.team_id == t.id,
      where: t.manager_id == ^manager_id,
      distinct: true,
      select: m.user_id
    )
    |> Repo.all()
  end

  # A team's manager must hold the manager (or administrator) role and belong
  # to the team's organization.
  defp validate_manager(changeset) do
    organization_id = Ecto.Changeset.get_field(changeset, :organization_id)

    case Ecto.Changeset.get_change(changeset, :manager_id) do
      nil ->
        changeset

      manager_id ->
        case Accounts.fetch_user(manager_id) do
          {:ok, %User{organization_id: other}} when other != organization_id ->
            Ecto.Changeset.add_error(changeset, :manager_id, "does not exist")

          {:ok, %User{role: %{name: role}}} when role in @manager_roles ->
            changeset

          {:ok, _user} ->
            Ecto.Changeset.add_error(changeset, :manager_id, "must have the manager role")

          {:error, :not_found} ->
            Ecto.Changeset.add_error(changeset, :manager_id, "does not exist")
        end
    end
  end

  defp in_organization(query, nil), do: from(t in query, where: is_nil(t.organization_id))
  defp in_organization(query, id), do: from(t in query, where: t.organization_id == ^id)

  defp preload_team(team_or_teams, opts \\ []) do
    Repo.preload(team_or_teams, [manager: :role, members: :role], opts)
  end

  defp preload_result({:ok, team}), do: {:ok, preload_team(team, force: true)}
  defp preload_result(error), do: error

  defp cast_id(id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :not_found}
    end
  end
end
