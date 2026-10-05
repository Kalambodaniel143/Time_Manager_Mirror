defmodule TimeManagerWeb.TeamJSON do
  alias TimeManager.Teams.Team
  alias TimeManagerWeb.UserJSON

  def index(%{teams: teams}), do: %{data: Enum.map(teams, &data/1)}

  def show(%{team: team}), do: %{data: data(team)}

  defp data(%Team{} = team) do
    %{
      id: team.id,
      name: team.name,
      manager: team.manager && UserJSON.data(team.manager),
      members: Enum.map(team.members, &UserJSON.data/1)
    }
  end
end
