defmodule TimeManagerWeb.WorkingTimeController do
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TimeManager.WorkingTimes
  alias TimeManager.WorkingTimes.WorkingTime
  alias TimeManagerWeb.Schemas.ErrorResponse
  alias TimeManagerWeb.Schemas.ValidationErrorResponse
  alias TimeManagerWeb.Schemas.{WorkingTimeRequest, WorkingTimeResponse, WorkingTimesResponse}

  action_fallback TimeManagerWeb.FallbackController

  tags(["workingtime"])

  operation(:index,
    summary: "List a user's working times",
    parameters: [
      userID: [in: :path, type: :integer, description: "User ID", example: 1],
      start: [
        in: :query,
        type: :string,
        required: false,
        description: "Only include slots starting on/after this ISO 8601 timestamp"
      ],
      end: [
        in: :query,
        type: :string,
        required: false,
        description: "Only include slots ending on/before this ISO 8601 timestamp"
      ]
    ],
    responses: [
      ok: {"Working times list", "application/json", WorkingTimesResponse},
      not_found: {"User not found", "application/json", ErrorResponse},
      bad_request: {"Malformed start/end filter", "application/json", ErrorResponse}
    ]
  )

  def index(conn, %{"userID" => user_id} = params) do
    with {:ok, working_times} <- WorkingTimes.list_working_times(user_id, params) do
      render(conn, :index, working_times: working_times)
    end
  end

  operation(:show,
    summary: "Get one of a user's working times by ID",
    parameters: [
      userID: [in: :path, type: :integer, description: "User ID", example: 1],
      id: [in: :path, type: :integer, description: "Working time ID", example: 1]
    ],
    responses: [
      ok: {"Working time", "application/json", WorkingTimeResponse},
      not_found: {"Working time or user not found", "application/json", ErrorResponse}
    ]
  )

  def show(conn, %{"userID" => user_id, "id" => id}) do
    with {:ok, working_time} <- WorkingTimes.get_working_time(user_id, id) do
      render(conn, :show, working_time: working_time)
    end
  end

  operation(:create,
    summary: "Create a working time for a user",
    parameters: [
      userID: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    request_body: {"Working time attributes", "application/json", WorkingTimeRequest},
    responses: [
      created: {"Working time created", "application/json", WorkingTimeResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse},
      not_found: {"User not found", "application/json", ErrorResponse}
    ]
  )

  def create(conn, %{"userID" => user_id} = params) do
    with {:ok, %WorkingTime{} = working_time} <-
           WorkingTimes.create_working_time(user_id, working_time_params(params)) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/workingtime/#{user_id}/#{working_time.id}")
      |> render(:show, working_time: working_time)
    end
  end

  operation(:update,
    summary: "Update a working time",
    parameters: [
      id: [in: :path, type: :integer, description: "Working time ID", example: 1]
    ],
    request_body: {"Working time attributes", "application/json", WorkingTimeRequest},
    responses: [
      ok: {"Working time updated", "application/json", WorkingTimeResponse},
      not_found: {"Working time not found", "application/json", ErrorResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    with {:ok, working_time} <- WorkingTimes.get_working_time(id),
         {:ok, %WorkingTime{} = working_time} <-
           WorkingTimes.update_working_time(working_time, working_time_params(params)) do
      render(conn, :show, working_time: working_time)
    end
  end

  operation(:delete,
    summary: "Delete a working time",
    parameters: [
      id: [in: :path, type: :integer, description: "Working time ID", example: 1]
    ],
    responses: [
      no_content: "Working time deleted",
      not_found: {"Working time not found", "application/json", ErrorResponse}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, working_time} <- WorkingTimes.get_working_time(id),
         {:ok, %WorkingTime{}} <- WorkingTimes.delete_working_time(working_time) do
      send_resp(conn, :no_content, "")
    end
  end

  defp working_time_params(%{"workingtime" => %{} = working_time_params}), do: working_time_params
  defp working_time_params(params), do: params
end
