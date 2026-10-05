defmodule TimeManagerWeb.Authz do
  @moduledoc """
  Small helpers shared by the controllers to apply `TimeManager.Authorization`.
  """

  @doc "The authenticated user, set by `TimeManagerWeb.Plugs.Authenticate`."
  def current_user(conn), do: conn.assigns.current_user

  @doc "`:ok` when the permission holds, `{:error, :forbidden}` (403) otherwise."
  def authorize(true), do: :ok
  def authorize(false), do: {:error, :forbidden}

  @doc """
  URL parameters are strings: cast them to integers before comparing them with
  user ids. A malformed id is reported as not found.
  """
  def cast_id(value) do
    case Ecto.Type.cast(:id, value) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :not_found}
    end
  end
end
