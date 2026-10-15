defmodule TimeManagerWeb.WorkforceController do
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias TimeManager.Workforce
  alias TimeManager.Workforce.{Absences, Planning, Payroll, TimeSheets}
  alias TimeManagerWeb.Schemas.{ErrorResponse, WorkflowRequest, WorkflowResponse}
  action_fallback TimeManagerWeb.FallbackController
  tags(["workforce"])

  operation(:context,
    summary: "Current effective rules and team permissions",
    responses: [ok: {"Context", "application/json", WorkflowResponse}]
  )

  def context(conn, _params) do
    user = me(conn)

    teams =
      if user.role.name == "administrator",
        do: TimeManager.Teams.list_teams(user.organization_id),
        else:
          if(user.role.name == "manager",
            do: TimeManager.Teams.list_managed_teams(user),
            else: []
          )

    json(conn, %{
      data: %{
        rules: Workforce.rules(user.organization_id),
        preferences: Workforce.preferences(user),
        permissions:
          Enum.map(teams, fn team ->
            Map.merge(Workforce.permission(team.id), %{
              team_id: team.id,
              manager_id: team.manager_id,
              team: team.name,
              member_ids: Enum.map(team.members, & &1.id)
            })
          end)
      }
    })
  end

  operation(:rules,
    summary: "rules",
    parameters: [org_id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def rules(conn, p), do: respond(conn, Workforce.get_rules(me(conn), p["org_id"]))

  operation(:update_rules,
    summary: "update rules",
    parameters: [org_id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def update_rules(conn, p),
    do:
      respond(
        conn,
        Workforce.update_rules(me(conn), p["org_id"], p["rules"] || Map.drop(p, ["org_id"]))
      )

  operation(:permissions,
    summary: "permissions",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def permissions(conn, p),
    do:
      respond(
        conn,
        with(
          {:ok, team} <- Workforce.team(me(conn), p["id"]),
          do: {:ok, Workforce.permission(team.id)}
        )
      )

  operation(:update_permissions,
    summary: "update permissions",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def update_permissions(conn, p),
    do:
      respond(
        conn,
        Workforce.update_permission(me(conn), p["id"], p["permissions"] || Map.drop(p, ["id"]))
      )

  operation(:notes,
    summary: "notes",
    parameters: [
      user_id: [in: :path, type: :string, required: true],
      week: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def notes(conn, p), do: respond(conn, TimeSheets.get_note(me(conn), p["user_id"], p["week"]))

  operation(:update_notes,
    summary: "update notes",
    parameters: [
      user_id: [in: :path, type: :string, required: true],
      week: [in: :path, type: :string, required: true]
    ],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def update_notes(conn, p),
    do: respond(conn, TimeSheets.put_note(me(conn), p["user_id"], p["week"], p["note"]))

  operation(:sheets,
    summary: "sheets",
    parameters: [week: [in: :query, type: :string, required: true]],
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def sheets(conn, p), do: respond(conn, TimeSheets.list(me(conn), p["week"]))

  operation(:validate_sheets,
    summary: "validate sheets",
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def validate_sheets(conn, p), do: respond(conn, TimeSheets.validate_batch(me(conn), p))

  operation(:transition_sheet,
    summary: "transition sheet",
    parameters: [
      user_id: [in: :path, type: :string, required: true],
      week: [in: :path, type: :string, required: true],
      action: [in: :path, type: :string, required: true]
    ],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def transition_sheet(conn, p),
    do:
      respond(
        conn,
        TimeSheets.transition(me(conn), p["user_id"], p["week"], p["action"], p["reason"])
      )

  operation(:corrections,
    summary: "corrections",
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def corrections(conn, p),
    do: paged(conn, p, &TimeSheets.corrections(me(conn), Map.put(p, "page", &1)))

  operation(:request_correction,
    summary: "request correction",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def request_correction(conn, p),
    do: respond(conn, TimeSheets.request_correction(me(conn), p["id"], p["correction"]))

  operation(:review_correction,
    summary: "review correction",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def review_correction(conn, p),
    do: respond(conn, TimeSheets.review_correction(me(conn), p["id"], p))

  operation(:plans,
    summary: "plans",
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def plans(conn, p), do: respond(conn, Planning.list(me(conn), p))

  operation(:plan,
    summary: "plan",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def plan(conn, p), do: respond(conn, Planning.get(me(conn), p["id"]))

  operation(:create_plan,
    summary: "create plan",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def create_plan(conn, p), do: respond(conn, Planning.create(me(conn), p["id"], p["plan"] || p))

  operation(:update_plan,
    summary: "Change an empty draft's date range",
    parameters: [id: [in: :path, type: :integer, required: true]],
    request_body: {"Draft start, days and revision", "application/json", WorkflowRequest},
    responses: [ok: {"Plan", "application/json", WorkflowResponse}]
  )

  def update_plan(conn, p), do: respond(conn, Planning.update_plan(me(conn), p["id"], p))

  operation(:delete_plan,
    summary: "Withdraw a future plan",
    parameters: [id: [in: :path, type: :integer, required: true]],
    request_body: {"Revision and reason", "application/json", WorkflowRequest},
    responses: [ok: {"Deleted plan", "application/json", WorkflowResponse}]
  )

  def delete_plan(conn, p), do: respond(conn, Planning.delete_plan(me(conn), p["id"], p))

  operation(:create_shift,
    summary: "create shift",
    parameters: [plan_id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def create_shift(conn, p),
    do: respond(conn, Planning.save_shift(me(conn), p["plan_id"], nil, p["shift"] || p))

  operation(:update_shift,
    summary: "update shift",
    parameters: [
      plan_id: [in: :path, type: :string, required: true],
      id: [in: :path, type: :string, required: true]
    ],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def update_shift(conn, p),
    do: respond(conn, Planning.save_shift(me(conn), p["plan_id"], p["id"], p["shift"] || p))

  operation(:delete_shift,
    summary: "delete shift",
    parameters: [
      plan_id: [in: :path, type: :string, required: true],
      id: [in: :path, type: :string, required: true]
    ],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def delete_shift(conn, p),
    do: respond(conn, Planning.delete_shift(me(conn), p["plan_id"], p["id"], p))

  operation(:publish,
    summary: "publish",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def publish(conn, p), do: respond(conn, Planning.publish(me(conn), p["id"], p))

  operation(:swaps,
    summary: "swaps",
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def swaps(conn, p), do: paged(conn, p, &Planning.swaps(me(conn), &1))

  operation(:create_swap,
    summary: "create swap",
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def create_swap(conn, p), do: respond(conn, Planning.request_swap(me(conn), p))

  operation(:consent_swap,
    summary: "consent swap",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def consent_swap(conn, p), do: respond(conn, Planning.consent(me(conn), p["id"], p["accepted"]))

  operation(:review_swap,
    summary: "review swap",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def review_swap(conn, p), do: respond(conn, Planning.review_swap(me(conn), p["id"], p))

  operation(:absences,
    summary: "absences",
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def absences(conn, p), do: paged(conn, p, &Absences.list(me(conn), &1))

  operation(:create_absence,
    summary: "create absence",
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def create_absence(conn, p), do: respond(conn, Absences.create(me(conn), p))

  operation(:absence_payment,
    summary: "Confirm payable hours on an approved absence",
    parameters: [id: [in: :path, type: :integer, required: true]],
    request_body: {"Payable hours", "application/json", WorkflowRequest},
    responses: [ok: {"Absence", "application/json", WorkflowResponse}]
  )

  def absence_payment(conn, p), do: respond(conn, Absences.payment(me(conn), p["id"], p))

  operation(:cancel_absence,
    summary: "Withdraw a pending absence or cancel an approved one",
    parameters: [id: [in: :path, type: :integer, required: true]],
    request_body: {"Reason", "application/json", WorkflowRequest},
    responses: [ok: {"Cancelled absence", "application/json", WorkflowResponse}]
  )

  def cancel_absence(conn, p), do: respond(conn, Absences.cancel(me(conn), p["id"], p))

  operation(:review_absence,
    summary: "review absence",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def review_absence(conn, p), do: respond(conn, Absences.review(me(conn), p["id"], p))

  operation(:payroll,
    summary: "payroll",
    parameters: [month: [in: :query, type: :string, required: true]],
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def payroll(conn, p), do: respond(conn, Payroll.report(me(conn), p["month"]))

  operation(:pay_profile,
    summary: "pay profile",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def pay_profile(conn, p), do: respond(conn, Payroll.profile(me(conn), p["id"]))

  operation(:update_pay_profile,
    summary: "update pay profile",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def update_pay_profile(conn, p),
    do: respond(conn, Payroll.update_profile(me(conn), p["id"], Map.drop(p, ["id"])))

  operation(:preferences,
    summary: "preferences",
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def preferences(conn, _p), do: respond(conn, {:ok, Workforce.preferences(me(conn))})

  operation(:update_preferences,
    summary: "update preferences",
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def update_preferences(conn, p), do: respond(conn, Workforce.update_preferences(me(conn), p))

  operation(:journal,
    summary: "journal",
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def journal(conn, p), do: paged(conn, p, &Workforce.journal(me(conn), &1))

  operation(:notifications,
    summary: "notifications",
    parameters: [
      status: [in: :query, type: :string, description: "all (default), read or unread"],
      page: [
        in: :query,
        type: :integer,
        description: "Page starting at 1; 50 notifications per page"
      ]
    ],
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def notifications(conn, p) do
    status = p["status"] || "all"

    with true <- status in ["all", "read", "unread"],
         raw_page when is_binary(raw_page) <- p["page"] || "1",
         {page, ""} when page >= 1 and page <= 100_000 <- Integer.parse(raw_page) do
      respond(conn, {:ok, Workforce.notifications(me(conn), status, page)})
    else
      _ ->
        {:error,
         {:unprocessable_entity,
          "Choisissez toutes les notifications, les lues ou les non lues, et un numéro de page valide."}}
    end
  end

  operation(:notification_count,
    summary: "Unread notification count",
    responses: [ok: {"Count", "application/json", WorkflowResponse}]
  )

  def notification_count(conn, _p),
    do: respond(conn, {:ok, %{unread: Workforce.unread_notification_count(me(conn))}})

  operation(:read_notification,
    summary: "read notification",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Workflow attributes", "application/json", WorkflowRequest},
    responses: [
      ok: {"Result", "application/json", WorkflowResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse},
      conflict: {"State conflict", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid input", "application/json", ErrorResponse}
    ]
  )

  def read_notification(conn, p),
    do: respond(conn, Workforce.read_notification(me(conn), p["id"]))

  operation(:payroll_csv,
    summary: "Download monthly payroll CSV",
    parameters: [month: [in: :query, type: :string, required: true]],
    responses: [ok: {"CSV", "text/csv", %OpenApiSpex.Schema{type: :string}}]
  )

  def payroll_csv(conn, p) do
    with {:ok, report} <- Payroll.report(me(conn), p["month"]) do
      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=payroll-#{p["month"]}.csv")
      |> send_resp(200, "\uFEFF" <> Payroll.csv(report))
    end
  end

  defp me(conn), do: conn.assigns.current_user

  defp paged(conn, params, fetch) do
    with {:ok, page} <- TimeManager.Pagination.parse(params),
         {:ok, rows} <- fetch.(page) do
      conn |> TimeManager.Pagination.header(rows, page) |> respond({:ok, rows})
    end
  end

  defp respond(conn, {:ok, result}), do: json(conn, %{data: result})
  defp respond(_conn, error), do: error
end
