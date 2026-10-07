defmodule TimeManager.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TimeManager.Accounts` context.
  """

  def valid_password, do: "correct horse battery"

  def unique_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Generate a user. The role is "employee" unless `:role` is given, and the user
  has no organization unless `:organization_id` is given.
  """
  def user_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {role, attrs} = Map.pop(attrs, :role, "employee")
    {organization_id, attrs} = Map.pop(attrs, :organization_id)

    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_email(),
        username: "some username",
        password: valid_password()
      })
      |> TimeManager.Accounts.create_user(role, organization_id)

    user
  end

  def team_fixture(attrs \\ %{}) do
    {members, attrs} = attrs |> Map.new() |> Map.pop(:members, [])
    {organization_id, attrs} = Map.pop(attrs, :organization_id)

    {:ok, team} =
      attrs
      |> Enum.into(%{name: "team #{System.unique_integer([:positive])}"})
      |> TimeManager.Teams.create_team(organization_id)

    Enum.reduce(members, team, fn member, team ->
      {:ok, team} = TimeManager.Teams.add_member(team, member)
      team
    end)
  end

  @doc """
  Creates an organization through its public flow and returns its
  administrator (role and organization loaded).
  """
  def organization_admin_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    profile = %{
      "first_name" => "Nando",
      "last_name" => "Martin",
      "email" => Map.get(attrs, :email, unique_email())
    }

    {:ok, admin} =
      TimeManager.Organizations.create_organization(
        Map.get(attrs, :name, "Organisation #{System.unique_integer([:positive])}"),
        profile,
        valid_password()
      )

    admin
  end

  @doc "A complete profile to join an organization."
  def join_profile(attrs \\ %{}) do
    Enum.into(attrs, %{
      "first_name" => "Sara",
      "last_name" => "Martin",
      "email" => unique_email(),
      "gender" => "female",
      "birth_date" => "1999-03-12",
      "birth_place" => "Paris"
    })
  end

  @doc "A pending join request; returns `{request, reference}`."
  def join_request_fixture(organization_id, attrs \\ %{}) do
    {:ok, request, reference} =
      TimeManager.Organizations.submit_join_request(organization_id, join_profile(attrs))

    {request, reference}
  end
end
