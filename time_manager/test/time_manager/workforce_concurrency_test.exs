defmodule TimeManager.WorkforceConcurrencyTest do
  use ExUnit.Case, async: false
  import Ecto.Query
  import TimeManager.AccountsFixtures
  alias Ecto.Adapters.SQL.Sandbox
  alias TimeManager.{Repo, Workforce, WorkingTimes}
  alias TimeManager.Workforce.{TimeSheets, Planning}

  setup do
    ctx =
      Sandbox.unboxed_run(Repo, fn ->
        admin = organization_admin_fixture(name: "Workforce concurrency #{Ecto.UUID.generate()}")
        employee = user_fixture(organization_id: admin.organization_id)
        team = team_fixture(organization_id: admin.organization_id, members: [employee])
        date = Date.utc_today() |> Workforce.monday() |> Date.add(-7)

        {:ok, period} =
          WorkingTimes.create_working_time(employee.id, %{
            start: DateTime.new!(date, ~T[08:00:00]),
            end: DateTime.new!(date, ~T[16:00:00])
          })

        %{
          admin: admin,
          employee: employee,
          team: team,
          period: period,
          week: Date.to_iso8601(date)
        }
      end)

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.delete_all(
          from t in TimeManager.Teams.Team, where: t.organization_id == ^ctx.admin.organization_id
        )

        Repo.delete_all(
          from u in TimeManager.Accounts.User,
            where: u.organization_id == ^ctx.admin.organization_id
        )

        Repo.delete!(Repo.get!(TimeManager.Organizations.Organization, ctx.admin.organization_id))
      end)
    end)

    Map.put(ctx, :supervisor, start_supervised!({Task.Supervisor, []}))
  end

  test "duplicate correction requests on separate connections create one pending request", ctx do
    results =
      together(ctx, fn ->
        TimeSheets.request_correction(ctx.employee, ctx.period.id, %{
          "start" => ctx.period.start,
          "end" => ctx.period.end,
          "reason" => "Vérification"
        })
      end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, {:conflict, _}}, &1)) == 1
  end

  test "concurrent decisions cannot accept the same correction twice", ctx do
    request =
      Sandbox.unboxed_run(Repo, fn ->
        {:ok, row} =
          TimeSheets.request_correction(ctx.employee, ctx.period.id, %{
            "start" => ctx.period.start,
            "end" => ctx.period.end,
            "reason" => "Vérification"
          })

        row
      end)

    results =
      together(ctx, fn ->
        TimeSheets.review_correction(ctx.admin, request.id, %{"status" => "approved"})
      end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, {:conflict, _}}, &1)) == 1
  end

  test "batch validation and direct correction serialize on the employee lock", ctx do
    results =
      together(ctx, fn ->
        TimeSheets.validate_batch(ctx.admin, %{
          "week" => ctx.week,
          "user_ids" => [ctx.employee.id]
        })
      end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1

    Sandbox.unboxed_run(Repo, fn ->
      assert {:error, {:conflict, _}} =
               WorkingTimes.update_working_time(ctx.period, %{
                 end: DateTime.add(ctx.period.end, -3600)
               })
    end)
  end

  test "concurrent draft edits with one revision do not silently overwrite", ctx do
    plan =
      Sandbox.unboxed_run(Repo, fn ->
        {:ok, row} =
          Planning.create(ctx.admin, ctx.team.id, %{"start" => Date.add(Date.utc_today(), 15)})

        row
      end)

    start = DateTime.new!(Date.add(Date.utc_today(), 15), ~T[08:00:00])

    results =
      together(ctx, fn ->
        Planning.save_shift(ctx.admin, plan.id, nil, %{
          "revision" => plan.revision,
          "user_id" => ctx.employee.id,
          "start" => start,
          "end" => DateTime.add(start, 3600),
          "kind" => "day"
        })
      end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, {:conflict, _}}, &1)) == 1
  end

  defp together(ctx, action) do
    owner = self()

    tasks =
      for _ <- 1..2 do
        Task.Supervisor.async_nolink(ctx.supervisor, fn ->
          Sandbox.unboxed_run(Repo, fn ->
            send(owner, {:ready, self()})

            receive do
              :go -> action.()
            after
              5000 -> flunk("No synchronization signal")
            end
          end)
        end)
      end

    for _ <- tasks, do: assert_receive({:ready, _}, 5000)
    Enum.each(tasks, &send(&1.pid, :go))
    Enum.map(tasks, &Task.await(&1, 10000))
  end
end
