defmodule TimeManager.Clocks do
  @moduledoc """
  Recording and reading user clockings.
  """

  import Ecto.Query

  alias TimeManager.Accounts.User
  alias TimeManager.Clocks.Clock
  alias TimeManager.Repo

  @doc """
  Lists a persisted user's clockings, oldest first.
  """
  def list_clocks(%User{id: user_id}) do
    Clock
    |> where([clock], clock.user_id == ^user_id)
    |> order_by([clock], asc: clock.time, asc: clock.id)
    |> Repo.all()
  end

  @doc """
  Records an arrival (status: true) or departure (status: false).

  The owner comes from the supplied user, never from attrs.
  Returns {:ok, clock} or {:error, changeset}.
  """
  def create_clock(%User{id: user_id}, attrs) do
    %Clock{user_id: user_id}
    |> Clock.changeset(attrs)
    |> Repo.insert()
  end
end
