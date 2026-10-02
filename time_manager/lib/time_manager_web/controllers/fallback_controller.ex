defmodule TimeManagerWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use TimeManagerWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: TimeManagerWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause handles resources that cannot be found, e.g. a missing or
  # malformed :id path parameter.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: TimeManagerWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: TimeManagerWeb.ErrorJSON)
    |> render(:"400")
  end
end
