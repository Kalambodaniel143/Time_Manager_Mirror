defmodule TimeManager.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TimeManager.Accounts` context.
  """

  def valid_password, do: "correct horse battery"

  def unique_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Generate a user. The role is "employee" unless `:role` is given.
  """
  def user_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {role, attrs} = Map.pop(attrs, :role, "employee")

    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_email(),
        username: "some username",
        password: valid_password()
      })
      |> TimeManager.Accounts.create_user(role)

    user
  end

  def team_fixture(attrs \\ %{}) do
    {members, attrs} = attrs |> Map.new() |> Map.pop(:members, [])

    {:ok, team} =
      attrs
      |> Enum.into(%{name: "team #{System.unique_integer([:positive])}"})
      |> TimeManager.Teams.create_team()

    Enum.reduce(members, team, fn member, team ->
      {:ok, team} = TimeManager.Teams.add_member(team, member)
      team
    end)
  end
end
