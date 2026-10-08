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

  # Not authenticated: missing or invalid session.
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: TimeManagerWeb.ErrorJSON)
    |> render(:"401")
  end

  # Authenticated, but outside the user's permissions.
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: TimeManagerWeb.ErrorJSON)
    |> render(:"403")
  end

  def call(conn, {:error, :last_administrator}) do
    conn
    |> put_status(:conflict)
    |> json(%{errors: %{detail: "The last administrator cannot be demoted or deleted"}})
  end

  # Errors of the organizations contract carry their own displayable message.
  def call(conn, {:error, {:conflict, detail, fields}}) do
    conn
    |> put_status(:conflict)
    |> json(%{errors: Map.put(fields, :detail, detail)})
  end

  def call(conn, {:error, {status, detail}}) when status in [:not_found, :forbidden] do
    conn
    |> put_status(status)
    |> json(%{errors: %{detail: detail}})
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: TimeManagerWeb.ErrorJSON)
    |> render(:"400")
  end

  def call(conn, {:error, reason})
      when reason in [:invalid_code, :expired_code, :too_many_attempts] do
    detail =
      case reason do
        :invalid_code -> "Invalid verification code"
        :expired_code -> "Verification code expired"
        :too_many_attempts -> "Too many verification attempts"
      end

    status = if reason == :too_many_attempts, do: :too_many_requests, else: :unprocessable_entity
    json(conn |> put_status(status), %{errors: %{detail: detail}})
  end

  def call(conn, {:error, :service_unavailable}) do
    json(conn |> put_status(:service_unavailable), %{
      errors: %{detail: "Email delivery is unavailable"}
    })
  end
end
