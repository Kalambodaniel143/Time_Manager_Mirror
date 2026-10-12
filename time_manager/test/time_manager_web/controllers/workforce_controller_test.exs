defmodule TimeManagerWeb.WorkforceControllerTest do
  use TimeManagerWeb.ConnCase
  import TimeManager.AccountsFixtures
  alias TimeManager.{Repo, Workforce, WorkingTimes}
  alias TimeManager.Workforce.{Absences, Payroll, Planning, TimeSheets}

  setup do
    admin = organization_admin_fixture()

    manager =
      user_fixture(
        role: "manager",
        organization_id: admin.organization_id,
        username: "responsable"
      )

    employee =
      user_fixture(
        organization_id: admin.organization_id,
        username: "agent",
        first_name: "Sara",
        last_name: "Martin"
      )

    colleague = user_fixture(organization_id: admin.organization_id, username: "collegue")

    team =
      team_fixture(
        organization_id: admin.organization_id,
        manager_id: manager.id,
        members: [employee, colleague]
      )

    outsider = organization_admin_fixture()

    %{
      admin: admin,
      manager: manager,
      employee: employee,
      colleague: colleague,
      team: team,
      outsider: outsider
    }
  end

  defp monday, do: Date.utc_today() |> Workforce.monday() |> Date.add(-7)
  defp at(date, hour), do: DateTime.new!(date, Time.new!(hour, 0, 0), "Etc/UTC")

  defp period(user, date \\ monday()) do
    {:ok, p} = WorkingTimes.create_working_time(user.id, %{start: at(date, 8), end: at(date, 16)})
    p
  end

  test "rules, preferences and permissions persist with tenant and role checks", ctx do
    conn = log_in(ctx.conn, ctx.admin)
    path = "/api/organizations/#{ctx.admin.organization_id}/rules"

    assert json_response(
             patch(conn, path, rules: %{maxConsecutiveNights: 2, publishDaysAhead: 0}),
             200
           )["data"]["maxConsecutiveNights"] == 2

    assert json_response(
             patch(log_in(ctx.conn, ctx.employee), path, rules: %{maxConsecutiveNights: 8}),
             403
           )

    assert json_response(get(log_in(ctx.conn, ctx.outsider), path), 403)

    assert json_response(
             patch(conn, path, rules: %{timezone: "wrong", overtimeThreshold: -1}),
             422
           )

    assert json_response(
             patch(conn, "/api/teams/#{ctx.team.id}/permissions", permissions: %{correct: false}),
             200
           )["data"]["correct"] == false

    refute Workforce.allowed?(ctx.manager, ctx.employee.id, :correct)

    prefs =
      patch(log_in(ctx.conn, ctx.employee), "/api/auth/preferences", %{
        theme: "night",
        speech_enabled: true
      })

    assert json_response(prefs, 200)["data"]["theme"] == "night"

    assert json_response(get(log_in(ctx.conn, ctx.employee), "/api/auth/preferences"), 200)[
             "data"
           ]["speech_enabled"]

    assert json_response(
             patch(log_in(ctx.conn, ctx.employee), "/api/auth/preferences", %{
               user_id: ctx.admin.id
             }),
             422
           )

    assert json_response(get(ctx.conn, "/api/notifications"), 401)
  end

  test "notes are shared only within the authorized scope and owned by their writer", ctx do
    url = "/api/users/#{ctx.employee.id}/week-notes/#{monday()}"

    saved =
      put(log_in(ctx.conn, ctx.employee), url, %{
        note: "Intervention prolongée",
        user_id: ctx.admin.id
      })

    assert json_response(saved, 200)["data"]["user_id"] == ctx.employee.id

    assert json_response(get(log_in(ctx.conn, ctx.manager), url), 200)["data"]["note"] ==
             "Intervention prolongée"

    assert json_response(put(log_in(ctx.conn, ctx.manager), url, %{note: "Changer la note"}), 403)
    assert json_response(get(log_in(ctx.conn, ctx.colleague), url), 403)
    assert json_response(get(log_in(ctx.conn, ctx.outsider), url), 403)
  end

  test "correction decisions preserve snapshots and reject duplicates, self-review and stale periods",
       ctx do
    p = period(ctx.employee)
    attrs = %{"start" => p.start, "end" => at(monday(), 15), "reason" => "Départ confirmé"}
    {:ok, request} = TimeSheets.request_correction(ctx.employee, p.id, attrs)
    assert WorkingTimes.get_working_time(p.id) == {:ok, p}
    assert {:error, {:conflict, _}} = TimeSheets.request_correction(ctx.employee, p.id, attrs)

    assert {:error, :forbidden} =
             TimeSheets.review_correction(ctx.employee, request.id, %{"status" => "approved"})

    assert {:error, {:unprocessable_entity, _}} =
             TimeSheets.review_correction(ctx.manager, request.id, %{"status" => "rejected"})

    {:ok, decided} =
      TimeSheets.review_correction(ctx.manager, request.id, %{"status" => "approved"})

    assert decided.before.end == p.end
    assert decided.status == "approved"

    assert {:error, {:conflict, _}} =
             TimeSheets.review_correction(ctx.manager, request.id, %{"status" => "approved"})

    {:ok, current} = WorkingTimes.get_working_time(p.id)

    {:ok, second} =
      TimeSheets.request_correction(ctx.employee, p.id, %{attrs | "end" => at(monday(), 14)})

    {:ok, _} = WorkingTimes.update_working_time(current, %{end: at(monday(), 13)}, ctx.manager)

    assert {:error, {:conflict, _}} =
             TimeSheets.review_correction(ctx.manager, second.id, %{"status" => "approved"})
  end

  test "batch validation rolls back on an invalid member; validated weeks block all period mutation until reopening",
       ctx do
    p = period(ctx.employee)
    week = Date.to_iso8601(monday())

    assert {:error, :forbidden} =
             TimeSheets.validate_batch(ctx.manager, %{
               "week" => week,
               "user_ids" => [ctx.employee.id, ctx.outsider.id]
             })

    assert Repo.aggregate(TimeManager.Workforce.Sheet, :count) == 0

    {:ok, [_]} =
      TimeSheets.validate_batch(ctx.manager, %{"week" => week, "user_ids" => [ctx.employee.id]})

    assert {:error, {:conflict, _}} =
             WorkingTimes.update_working_time(p, %{end: at(monday(), 15)})

    assert {:error, {:conflict, _}} = WorkingTimes.delete_working_time(p)

    assert {:error, {:conflict, _}} =
             WorkingTimes.create_working_time(ctx.employee.id, %{
               start: at(monday(), 17),
               end: at(monday(), 18)
             })

    assert {:error, :forbidden} =
             TimeSheets.transition(ctx.employee, ctx.employee.id, week, "reopen", "Moi-même")

    {:ok, closed} =
      TimeSheets.transition(ctx.admin, ctx.employee.id, week, "close", "Contrôle terminé")

    assert closed.status == "closed"

    {:ok, opened} =
      TimeSheets.transition(ctx.manager, ctx.employee.id, week, "reopen", "Régularisation")

    assert opened.status == "open"
    assert {:ok, _} = WorkingTimes.update_working_time(p, %{end: at(monday(), 15)})
  end

  test "missing departures and pending corrections block validation", ctx do
    date = at(monday(), 8)

    {:ok, _} =
      TimeManager.Clocks.create_clock(ctx.employee, %{time: date, status: true, kind: "arrival"})

    assert {:error, {:conflict, _}} =
             TimeSheets.validate_batch(ctx.manager, %{
               "week" => "#{monday()}",
               "user_ids" => [ctx.employee.id]
             })

    {:ok, _} =
      TimeManager.Clocks.create_clock(ctx.employee, %{
        time: at(monday(), 16),
        status: false,
        kind: "departure"
      })

    {:ok, [p]} = WorkingTimes.list_working_times(ctx.employee.id)

    {:ok, _} =
      TimeSheets.request_correction(ctx.employee, p.id, %{
        "start" => p.start,
        "end" => p.end,
        "reason" => "À vérifier"
      })

    assert {:error, {:conflict, _}} =
             TimeSheets.validate_batch(ctx.manager, %{
               "week" => "#{monday()}",
               "user_ids" => [ctx.employee.id]
             })
  end

  test "planning revisions protect edits, keep draft private and publish only authorized valid guards",
       ctx do
    {:ok, _} =
      Workforce.update_rules(ctx.admin, ctx.admin.organization_id, %{"publishDaysAhead" => 0})

    date = Date.add(Date.utc_today(), 15)
    {:ok, plan} = Planning.create(ctx.manager, ctx.team.id, %{"start" => date})

    attrs = %{
      "revision" => plan.revision,
      "user_id" => ctx.employee.id,
      "start" => at(date, 22),
      "end" => at(Date.add(date, 1), 6),
      "kind" => "night"
    }

    {:ok, draft} = Planning.save_shift(ctx.manager, plan.id, nil, attrs)
    assert {:error, {:conflict, _}} = Planning.save_shift(ctx.manager, plan.id, nil, attrs)
    {:ok, employee_view} = Planning.get(ctx.employee, plan.id)
    assert employee_view.shifts == []

    assert {:error, :forbidden} =
             Planning.publish(ctx.manager, plan.id, %{"revision" => draft.revision})

    {:ok, _} = Workforce.update_permission(ctx.admin, ctx.team.id, %{"publish" => true})
    {:ok, published} = Planning.publish(ctx.manager, plan.id, %{"revision" => draft.revision})
    assert published.published
    {:ok, employee_view} = Planning.get(ctx.employee, plan.id)
    assert length(employee_view.shifts) == 1
    assert {:error, :forbidden} = Planning.get(ctx.outsider, plan.id)
  end

  test "only an empty draft can change range; withdrawing a published plan requires publication permission",
       ctx do
    date = Date.add(Date.utc_today(), 15)
    {:ok, plan} = Planning.create(ctx.manager, ctx.team.id, %{"start" => date})

    {:ok, plan} =
      Planning.update_plan(ctx.manager, plan.id, %{
        "revision" => plan.revision,
        "start" => Date.add(date, 1),
        "days" => 7
      })

    assert plan.days == 7

    {:ok, plan} =
      Planning.save_shift(ctx.manager, plan.id, nil, %{
        "revision" => plan.revision,
        "user_id" => ctx.employee.id,
        "start" => at(Date.add(date, 1), 8),
        "end" => at(Date.add(date, 1), 16),
        "kind" => "day"
      })

    assert {:error, {:conflict, _}} =
             Planning.update_plan(ctx.manager, plan.id, %{
               "revision" => plan.revision,
               "days" => 6
             })

    {:ok, plan} = Planning.publish(ctx.admin, plan.id, %{"revision" => plan.revision})

    assert {:error, :forbidden} =
             Planning.delete_plan(ctx.manager, plan.id, %{
               "revision" => plan.revision,
               "reason" => "Annulation"
             })

    assert {:ok, %{id: _}} =
             Planning.delete_plan(ctx.admin, plan.id, %{
               "revision" => plan.revision,
               "reason" => "Réorganisation"
             })

    assert {:error, :not_found} = Planning.get(ctx.employee, plan.id)
  end

  test "exchanges require colleague consent and apply once as a transaction", ctx do
    date = Date.add(Date.utc_today(), 15)
    {:ok, _} = Workforce.update_permission(ctx.admin, ctx.team.id, %{"publish" => true})
    {:ok, plan} = Planning.create(ctx.manager, ctx.team.id, %{"start" => date})

    {:ok, plan} =
      Planning.save_shift(ctx.manager, plan.id, nil, %{
        "revision" => plan.revision,
        "user_id" => ctx.employee.id,
        "start" => at(date, 8),
        "end" => at(date, 16),
        "kind" => "day"
      })

    {:ok, plan} =
      Planning.save_shift(ctx.manager, plan.id, nil, %{
        "revision" => plan.revision,
        "user_id" => ctx.colleague.id,
        "start" => at(Date.add(date, 1), 8),
        "end" => at(Date.add(date, 1), 16),
        "kind" => "day"
      })

    {:ok, plan} = Planning.publish(ctx.manager, plan.id, %{"revision" => plan.revision})
    [first, second] = plan.shifts

    {:ok, swap} =
      Planning.request_swap(ctx.employee, %{
        "shift_id" => first.id,
        "target_shift_id" => second.id,
        "reason" => "Échange familial"
      })

    assert {:error, {:conflict, _}} =
             Planning.review_swap(ctx.manager, swap.id, %{"status" => "approved"})

    assert {:error, :forbidden} = Planning.consent(ctx.employee, swap.id, true)
    {:ok, _} = Planning.consent(ctx.colleague, swap.id, true)
    {:ok, result} = Planning.review_swap(ctx.manager, swap.id, %{"status" => "approved"})
    assert result.status == "approved"

    assert {:error, {:conflict, _}} =
             Planning.review_swap(ctx.manager, swap.id, %{"status" => "approved"})

    {:ok, plan} = Planning.get(ctx.employee, plan.id)
    assert hd(plan.shifts)["user_id"] == ctx.colleague.id
  end

  test "absence decisions reject self-approval and overlap with worked periods", ctx do
    date = Date.add(Date.utc_today(), 8)

    {:ok, request} =
      Absences.create(ctx.employee, %{
        "start" => at(date, 8),
        "end" => at(date, 16),
        "kind" => "leave"
      })

    assert {:error, :forbidden} =
             Absences.review(ctx.employee, request.id, %{"status" => "approved"})

    assert {:error, {:conflict, _}} =
             Absences.create(ctx.employee, %{
               "start" => at(date, 9),
               "end" => at(date, 10),
               "kind" => "sick"
             })

    assert {:ok, _} = Absences.review(ctx.manager, request.id, %{"status" => "approved"})

    assert {:error, {:conflict, _}} =
             Absences.review(ctx.manager, request.id, %{"status" => "approved"})
  end

  test "payroll computes full boundary weeks, exclusive overtime, night seconds, recovery and decimal amount",
       ctx do
    # September 2026 starts on Tuesday; Monday's hours consume the weekly quota.
    for date <- [~D[2026-08-31], ~D[2026-09-01], ~D[2026-09-02], ~D[2026-09-03], ~D[2026-09-04]] do
      period(ctx.employee, date)
    end

    {:ok, _} =
      WorkingTimes.create_working_time(ctx.employee.id, %{
        start: ~U[2026-09-05 22:00:00Z],
        end: ~U[2026-09-06 02:00:00Z]
      })

    {:ok, _} =
      WorkingTimes.create_working_time(ctx.employee.id, %{
        start: ~U[2026-09-30 22:00:00Z],
        end: ~U[2026-10-01 02:00:00Z]
      })

    {:ok, _} =
      WorkingTimes.create_working_time(ctx.employee.id, %{
        start: ~U[2026-09-20 10:00:00Z],
        end: ~U[2026-09-20 12:00:00Z],
        kind: "recup"
      })

    {:ok, _} =
      Payroll.update_profile(ctx.admin, ctx.employee.id, %{
        "hourly_rate" => "10.00",
        "currency" => "EUR"
      })

    {:ok, report} = Payroll.report(ctx.admin, "2026-09")
    row = Enum.find(report.rows, &(&1.id == ctx.employee.id))
    assert row.day == 32
    assert row.sup == 4
    assert row.night == 2
    assert row.recup == 2
    assert row.total == 40
    assert row.amount == "430.00"
    assert {:error, :forbidden} = Payroll.report(ctx.employee, "2026-09")
    assert Payroll.csv(report) =~ "Montant calculé"
  end

  test "approved recovery leave is not worked time, and paid absences need an explicit rule",
       ctx do
    start = ~U[2026-09-14 08:00:00Z]

    {:ok, recovery} =
      Absences.create(ctx.employee, %{
        "start" => start,
        "end" => DateTime.add(start, 7200),
        "kind" => "recup"
      })

    {:ok, _} = Absences.review(ctx.manager, recovery.id, %{"status" => "approved"})

    {:ok, leave} =
      Absences.create(ctx.employee, %{
        "start" => DateTime.add(start, 86400),
        "end" => DateTime.add(start, 86400 + 28800),
        "kind" => "leave"
      })

    {:ok, _} =
      Absences.review(ctx.manager, leave.id, %{"status" => "approved", "payable_hours" => "8"})

    {:ok, _} =
      Payroll.update_profile(ctx.admin, ctx.employee.id, %{
        "hourly_rate" => "10",
        "currency" => "EUR"
      })

    {:ok, report} = Payroll.report(ctx.admin, "2026-09")
    row = Enum.find(report.rows, &(&1.id == ctx.employee.id))
    assert row.total == 0
    assert row.recup == 0
    assert row.recup_taken == 2
    assert row.leave == 8
    assert row.amount == "0.00"

    {:ok, _} =
      Workforce.update_rules(ctx.admin, ctx.admin.organization_id, %{
        "paidAbsenceKinds" => ["leave"]
      })

    {:ok, report} = Payroll.report(ctx.admin, "2026-09")
    row = Enum.find(report.rows, &(&1.id == ctx.employee.id))
    assert row.paid_absence_hours == 8
    assert row.amount == "80.00"

    assert {:error, :forbidden} =
             Absences.cancel(ctx.employee, leave.id, %{"reason" => "Annuler"})

    assert {:ok, _} = Absences.cancel(ctx.manager, leave.id, %{"reason" => "Congé déplacé"})
    {:ok, report} = Payroll.report(ctx.admin, "2026-09")
    assert Enum.find(report.rows, &(&1.id == ctx.employee.id)).amount == "0.00"
  end

  test "payable hours cannot be fabricated from an absence calendar span", ctx do
    {:ok, absence} =
      Absences.create(ctx.employee, %{
        "start" => ~U[2026-09-14 08:00:00Z],
        "end" => ~U[2026-09-16 16:00:00Z],
        "kind" => "leave"
      })

    {:ok, _} = Absences.review(ctx.manager, absence.id, %{"status" => "approved"})

    {:ok, _} =
      Workforce.update_rules(ctx.admin, ctx.admin.organization_id, %{
        "paidAbsenceKinds" => ["leave"]
      })

    {:ok, _} = Payroll.update_profile(ctx.admin, ctx.employee.id, %{"hourly_rate" => "10"})
    {:ok, report} = Payroll.report(ctx.admin, "2026-09")
    row = Enum.find(report.rows, &(&1.id == ctx.employee.id))
    assert row.absence_payment_incomplete
    assert row.amount == nil

    assert {:error, :forbidden} =
             Absences.payment(ctx.employee, absence.id, %{"payable_hours" => "24"})

    assert {:error, {:unprocessable_entity, _}} =
             Absences.payment(ctx.manager, absence.id, %{"payable_hours" => "NaN"})

    {:ok, _} = Absences.payment(ctx.manager, absence.id, %{"payable_hours" => "24"})
    {:ok, report} = Payroll.report(ctx.admin, "2026-09")
    row = Enum.find(report.rows, &(&1.id == ctx.employee.id))
    assert row.paid_absence_hours == 24
    assert row.amount == "240.00"
  end

  test "a demoted manager cannot retain draft access or manager permissions", ctx do
    date = Date.add(Date.utc_today(), 15)
    {:ok, plan} = Planning.create(ctx.manager, ctx.team.id, %{"start" => date})
    {:ok, _} = TimeManager.Accounts.change_role(ctx.manager, "employee")
    conn = log_in(ctx.conn, ctx.manager)
    assert json_response(get(conn, "/api/plans/#{plan.id}"), 403)
    assert json_response(get(conn, "/api/teams/#{ctx.team.id}"), 403)
    assert json_response(get(conn, "/api/workforce/context"), 200)["data"]["permissions"] == []
    assert json_response(get(conn, "/api/plans?from=#{date}"), 200)["data"] == []
  end

  test "hour queries preserve an overnight period crossing a week boundary", ctx do
    {:ok, period} =
      WorkingTimes.create_working_time(ctx.employee.id, %{
        start: ~U[2026-09-27 22:00:00Z],
        end: ~U[2026-09-28 06:00:00Z]
      })

    conn = log_in(ctx.conn, ctx.employee)

    data =
      json_response(
        get(
          conn,
          "/api/workingtime/#{ctx.employee.id}?start=2026-09-28T00:00:00Z&end=2026-10-04T23:59:59Z"
        ),
        200
      )["data"]

    assert [%{"id" => id, "start" => "2026-09-27 22:00:00", "end" => "2026-09-28 06:00:00"}] =
             data

    assert id == period.id
  end

  test "notifications and journal cannot be read across users or organizations", ctx do
    row = Workforce.notify(ctx.employee.id, "Information", "Vos données ont changé.")

    assert json_response(get(log_in(ctx.conn, ctx.colleague), "/api/notifications"), 200)["data"] ==
             []

    assert json_response(
             patch(log_in(ctx.conn, ctx.colleague), "/api/notifications/#{row.id}/read", %{}),
             403
           )

    assert json_response(
             patch(log_in(ctx.conn, ctx.employee), "/api/notifications/#{row.id}/read", %{}),
             200
           )["data"]["read_at"]

    Workforce.audit(ctx.admin, "test.event", %{team_id: ctx.team.id})

    assert json_response(get(log_in(ctx.conn, ctx.outsider), "/api/audit-events"), 200)["data"] ==
             []

    assert json_response(get(log_in(ctx.conn, ctx.employee), "/api/audit-events"), 403)
  end
end
