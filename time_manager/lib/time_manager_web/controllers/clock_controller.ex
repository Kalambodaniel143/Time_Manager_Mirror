defmodule TimeManagerWeb.ClockController do
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TimeManager.Accounts
  alias TimeManager.Clocks
  alias TimeManagerWeb.Schemas.{ClockRequest, ClockResponse, ClocksResponse, ErrorResponse}
  alias TimeManagerWeb.Schemas.ValidationErrorResponse
  alias TimeManagerWeb.Schemas.ClockCompletionRequest

  action_fallback TimeManagerWeb.FallbackController

  tags(["clocks"])

  operation(:index,
    summary: "List a user's clock events",
    parameters: [
      userID: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    responses: [
      ok: {"Clock events list", "application/json", ClocksResponse},
      not_found: {"User not found", "application/json", ErrorResponse}
    ]
  )

  def index(conn, _params) do
    with {:ok, user} <- fetch_user(conn.path_params["userID"]) do
      render(conn, :index, clocks: Clocks.list_clocks(user))
    end
  end

  operation(:create,
    summary: "Record an arrival, departure, pause or resume for a user",
    description:
      "A pause or departure closes the current work segment atomically. Breaks are excluded from working periods. Leaving during a pause creates no extra period. Invalid transitions and dates are rejected.",
    parameters: [
      userID: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    request_body: {"Clock attributes", "application/json", ClockRequest},
    responses: [
      created: {"Clock event created", "application/json", ClockResponse},
      bad_request: {"Malformed request body", "application/json", ErrorResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse},
      not_found: {"User not found", "application/json", ErrorResponse}
    ]
  )

  def create(conn, %{"clock" => attrs}) when is_map(attrs) do
    with {:ok, user} <- fetch_user(conn.path_params["userID"]),
         {:ok, clock} <- Clocks.create_clock(user, attrs) do
      conn
      |> put_status(:created)
      |> render(:show, clock: clock)
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "Expected a JSON object under the clock key"}})
  end

  operation(:complete,
    summary: "Complete a missing departure",
    description:
      "Closes the current service at its actual departure time within the last seven days. clockID must still be the user's latest event. Creates its working period atomically, unless the user was paused.",
    parameters: [
      userID: [in: :path, type: :integer, description: "User ID"],
      clockID: [in: :path, type: :integer, description: "Expected latest clock ID"]
    ],
    request_body: {"Actual departure time", "application/json", ClockCompletionRequest},
    responses: [
      created: {"Departure recorded", "application/json", ClockResponse},
      bad_request: {"Malformed request", "application/json", ErrorResponse},
      not_found: {"User not found", "application/json", ErrorResponse},
      unprocessable_entity:
        {"Invalid time or stale clock", "application/json", ValidationErrorResponse}
    ]
  )

  def complete(conn, %{"clock" => %{"time" => time}}) when is_binary(time) do
    with {:ok, user} <- fetch_user(conn.path_params["userID"]),
         {:ok, clock} <- Clocks.complete_clock(user, conn.path_params["clockID"], time) do
      conn |> put_status(:created) |> render(:show, clock: clock)
    end
  end

  def complete(_conn, _params), do: {:error, :bad_request}

  defp fetch_user(user_id) do
    case Integer.parse(user_id) do
      {id, ""} when id > 0 and id <= 9_223_372_036_854_775_807 ->
        {:ok, Accounts.get_user!(id)}

      _ ->
        {:error, :not_found}
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end
end
