defmodule TimeManager.Authorization do
  @moduledoc """
  Who may do what, and on whose data: the permission matrix of the project.

  A permission always combines a role (what kind of action) and a scope
  (on which data):

    * employee      — self only;
    * manager       — self, plus the members of the teams they manage;
    * administrator — everyone.

  The API is the only real barrier: the front-end hides buttons for comfort,
  but every controller asks this module before acting.
  """

  alias TimeManager.Accounts.User
  alias TimeManager.Teams

  def administrator?(%User{role: %{name: "administrator"}}), do: true
  def administrator?(_user), do: false

  def manager?(%User{role: %{name: "manager"}}), do: true
  def manager?(_user), do: false

  @doc """
  Can `user` read the profile, clock events, working times and charts of the
  user `target_id`? Self, the managers of the target's teams, administrators.
  """
  def can_view?(%User{id: id}, id), do: true
  def can_view?(%User{} = user, target_id), do: administrator?(user) or manages?(user, target_id)

  @doc """
  Can `user` create, correct or delete working times of `target_id`?
  Administrators always; managers for their team members but never for
  themselves (no one validates their own hours); employees never.
  """
  def can_edit_hours?(%User{} = user, target_id) do
    administrator?(user) or (user.id != target_id and manages?(user, target_id))
  end

  @doc "Clocking in or out is personal: everyone clocks for themselves only."
  def can_clock?(%User{id: id}, id), do: true
  def can_clock?(_user, _target_id), do: false

  @doc "Can `user` edit the profile of `target_id`? Self or an administrator."
  def can_edit_profile?(%User{id: id}, id), do: true
  def can_edit_profile?(user, _target_id), do: administrator?(user)

  @doc """
  The users `user` may search: `:all` for an administrator, the members of
  their teams (and themselves) for a manager, and `:forbidden` for an employee.
  """
  def user_scope(%User{} = user) do
    cond do
      administrator?(user) -> :all
      manager?(user) -> [user.id | Teams.managed_member_ids(user.id)]
      true -> :forbidden
    end
  end

  defp manages?(%User{} = user, target_id) do
    manager?(user) and Teams.manages?(user.id, target_id)
  end
end
