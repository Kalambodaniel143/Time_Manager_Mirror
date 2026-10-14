defmodule TimeManager.Repo.Migrations.RemoveManagersFromOwnTeamMemberships do
  use Ecto.Migration

  def up do
    # Keep the manager assignment and all working hours; remove only redundant membership.
    execute("""
    DELETE FROM team_members AS member
    USING teams AS team
    WHERE member.team_id = team.id AND member.user_id = team.manager_id
    """)
  end

  # The former redundant memberships cannot be inferred after cleanup.
  def down, do: :ok
end
