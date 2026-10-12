defmodule TimeManager.Workforce.Planning do
  import Ecto.Query
  alias TimeManager.{Repo, Workforce, Teams}
  alias TimeManager.Workforce.{Absence, Plan, Shift, Swap, TimeSheets}
  alias TimeManager.Accounts.User

  defp manager_team(me, id) do
    with {:ok, team} <- Workforce.team(me, id),
         :ok <-
           Workforce.check(
             TimeManager.Authorization.administrator_of_team?(me, team) or
               (me.role.name == "manager" and team.manager_id == me.id)
           ),
         do: {:ok, team}
  end

  def list(me, params) do
    teams =
      if me.role.name == "administrator",
        do: Teams.list_teams(me.organization_id),
        else:
          Enum.uniq_by(
            if(me.role.name == "manager", do: Teams.list_managed_teams(me), else: []) ++
              Teams.list_member_teams(me),
            & &1.id
          )

    ids = Enum.map(teams, & &1.id)

    with {:ok, from_date} <- Workforce.date(params["from"] || Date.to_iso8601(Date.utc_today())),
         {:ok, to_date} <-
           Workforce.date(params["to"] || Date.to_iso8601(Date.add(from_date, 42))),
         :ok <-
           if(Date.diff(to_date, from_date) in 1..366,
             do: :ok,
             else: Workforce.invalid("Choisissez une période de 1 à 366 jours.")
           ) do
      plans =
        Repo.all(
          from p in Plan,
            where:
              p.team_id in ^ids and p.start <= ^to_date and p.start >= ^Date.add(from_date, -31),
            order_by: [asc: p.start]
        )

      {:ok, Enum.map(plans, &data(&1, me))}
    end
  end

  def get(me, id) do
    with {:ok, plan} <- Workforce.fetch(Plan, id),
         {:ok, _} <- Workforce.team(me, plan.team_id),
         do: {:ok, data(plan, me)}
  end

  def create(me, team_id, attrs) when is_map(attrs) do
    with {:ok, team} <- manager_team(me, team_id),
         {:ok, start} <- Workforce.date(attrs["start"]),
         days = attrs["days"] || 14,
         :ok <-
           if(is_integer(days) and days in 1..31,
             do: :ok,
             else: Workforce.invalid("Un planning couvre de 1 à 31 jours.")
           ) do
      Repo.transact(fn ->
        {:ok, _} = Workforce.fetch(TimeManager.Teams.Team, team.id, true)

        cs =
          Ecto.Changeset.change(%Plan{team_id: team.id, start: start, days: days})
          |> Ecto.Changeset.unique_constraint([:team_id, :start])

        with {:ok, plan} <- Repo.insert(cs) do
          Workforce.audit(me, "plan.created", %{plan_id: plan.id, team_id: team.id})
          {:ok, data(plan, me)}
        end
      end)
    end
  end

  def create(_, _, _), do: {:error, :bad_request}

  def update_plan(me, id, attrs) do
    with {:ok, initial} <- Workforce.fetch(Plan, id),
         {:ok, _} <- manager_team(me, initial.team_id) do
      Repo.transact(fn ->
        with {:ok, plan} <- Workforce.fetch(Plan, id, true),
             :ok <- revision(plan, attrs),
             :ok <-
               if(is_nil(plan.published_at) and shifts(plan.id) == [],
                 do: :ok,
                 else: Workforce.conflict("Seul un brouillon sans garde peut changer de période.")
               ),
             changeset =
               Ecto.Changeset.cast(plan, attrs, [:start, :days])
               |> Ecto.Changeset.validate_required([:start, :days])
               |> Ecto.Changeset.validate_number(:days,
                 greater_than: 0,
                 less_than_or_equal_to: 31
               )
               |> Ecto.Changeset.unique_constraint([:team_id, :start]),
             {:ok, plan} <-
               Repo.update(Ecto.Changeset.put_change(changeset, :revision, plan.revision + 1)) do
          Workforce.audit(me, "plan.updated", %{plan_id: plan.id})
          {:ok, data(plan, me)}
        end
      end)
    end
  end

  def delete_plan(me, id, attrs) do
    with {:ok, initial} <- Workforce.fetch(Plan, id),
         {:ok, _} <- manager_team(me, initial.team_id) do
      Repo.transact(fn ->
        lock_organization(me.organization_id)

        with {:ok, plan} <- Workforce.fetch(Plan, id, true),
             :ok <- revision(plan, attrs),
             {:ok, team} <-
               if(plan.published_at,
                 do: Workforce.team(me, plan.team_id, :publish),
                 else: manager_team(me, plan.team_id)
               ),
             :ok <-
               if(
                 Date.compare(plan.start, Date.utc_today()) != :lt and
                   Enum.all?(
                     shifts(plan.id),
                     &(DateTime.compare(&1.start, Workforce.now()) == :gt)
                   ),
                 do: :ok,
                 else:
                   Workforce.conflict("Un planning commencé reste conservé dans l’historique.")
               ),
             :ok <-
               if(
                 is_binary(attrs["reason"]) and
                   String.length(String.trim(attrs["reason"])) in 1..500,
                 do: :ok,
                 else:
                   Workforce.invalid("Indiquez un motif de suppression de 1 à 500 caractères.")
               ),
             :ok <-
               invalidate_swaps(
                 me,
                 Enum.map(shifts(plan.id), & &1.id),
                 "Le planning a été retiré."
               ),
             {:ok, _} <- Repo.delete(plan) do
          Workforce.audit(me, "plan.deleted", %{plan_id: plan.id, reason: attrs["reason"]})

          if plan.published_at,
            do:
              Enum.each(
                team.members,
                &Workforce.notify(
                  &1.id,
                  "Planning retiré",
                  "Le planning du #{plan.start} a été retiré. #{attrs["reason"]}"
                )
              )

          {:ok, %{id: plan.id}}
        end
      end)
    end
  end

  def save_shift(me, plan_id, id, attrs) when is_map(attrs) do
    with {:ok, initial} <- Workforce.fetch(Plan, plan_id),
         {:ok, _} <- manager_team(me, initial.team_id) do
      Repo.transact(fn ->
        with {:ok, plan} <- Workforce.fetch(Plan, plan_id, true),
             :ok <- revision(plan, attrs),
             {:ok, team} <- manager_team(me, plan.team_id),
             {:ok, user_id} <- Workforce.id(attrs["user_id"]),
             :ok <- Workforce.check(Enum.any?(team.members, &(&1.id == user_id))),
             {:ok, _} <- Workforce.fetch(User, user_id, true),
             {:ok, row} <- shift_for_plan(plan, id),
             changeset =
               Ecto.Changeset.cast(%{row | user_id: user_id}, attrs, [:start, :end, :kind, :place])
               |> Ecto.Changeset.validate_required([:start, :end, :kind])
               |> Ecto.Changeset.validate_inclusion(:kind, [
                 "day",
                 "night",
                 "oncall",
                 "leave",
                 "rest"
               ])
               |> Ecto.Changeset.validate_length(:place, max: 200),
             {:ok, shift} <- Ecto.Changeset.apply_action(changeset, :insert),
             :ok <- valid_shift(plan, shift),
             {:ok, _} <- Repo.insert_or_update(changeset),
             :ok <-
               invalidate_swaps(
                 me,
                 if(row.id, do: [row.id], else: []),
                 "La garde a été modifiée."
               ),
             {:ok, plan} <- bump(plan) do
          Workforce.audit(me, "shift.saved", %{plan_id: plan.id, user_id: user_id})
          {:ok, data(plan, me)}
        end
      end)
    end
  end

  def save_shift(_, _, _, _), do: {:error, :bad_request}

  defp shift_for_plan(plan, nil), do: {:ok, %Shift{plan_id: plan.id}}

  defp shift_for_plan(plan, id) do
    with {:ok, shift} <- Workforce.fetch(Shift, id, true),
         :ok <- Workforce.check(shift.plan_id == plan.id),
         do: {:ok, shift}
  end

  defp valid_shift(plan, shift) do
    start_date = DateTime.to_date(shift.start)

    cond do
      DateTime.diff(shift.end, shift.start) not in 1..86400 ->
        Workforce.invalid("Une garde doit durer de 1 seconde à 24 heures.")

      Date.compare(start_date, plan.start) == :lt or
          Date.compare(start_date, Date.add(plan.start, plan.days)) != :lt ->
        Workforce.invalid("La garde doit commencer dans la période du planning.")

      DateTime.compare(shift.start, Workforce.now()) == :lt ->
        Workforce.invalid("Une garde passée ne peut pas être modifiée.")

      true ->
        :ok
    end
  end

  defp revision(plan, attrs) do
    if attrs["revision"] == plan.revision,
      do: :ok,
      else: Workforce.conflict("Le planning a changé. Actualisez avant de continuer.")
  end

  defp bump(plan), do: Repo.update(Ecto.Changeset.change(plan, revision: plan.revision + 1))

  def delete_shift(me, plan_id, id, params) do
    with {:ok, initial} <- Workforce.fetch(Plan, plan_id),
         {:ok, _} <- manager_team(me, initial.team_id) do
      Repo.transact(fn ->
        with {:ok, plan} <- Workforce.fetch(Plan, plan_id, true),
             :ok <- revision(plan, params),
             {:ok, shift} <- shift_for_plan(plan, id),
             :ok <- valid_shift(plan, shift),
             :ok <- invalidate_swaps(me, [shift.id], "La garde a été supprimée."),
             {:ok, _} <- Repo.delete(shift),
             {:ok, plan} <- bump(plan) do
          Workforce.audit(me, "shift.deleted", %{plan_id: plan.id, shift_id: shift.id})
          {:ok, data(plan, me)}
        end
      end)
    end
  end

  def publish(me, plan_id, attrs) do
    with {:ok, initial} <- Workforce.fetch(Plan, plan_id),
         {:ok, _} <- Workforce.team(me, initial.team_id, :publish) do
      Repo.transact(fn ->
        # Serialize publications for an organization, including cross-team quotas.
        lock_organization(me.organization_id)

        with {:ok, plan} <- Workforce.fetch(Plan, plan_id, true),
             :ok <- revision(plan, attrs),
             {:ok, team} <- Workforce.team(me, plan.team_id, :publish),
             shifts = shifts(plan.id),
             :ok <- validate_publication(plan, shifts, team) do
          snapshot = %{"shifts" => Enum.map(shifts, &string_shift/1)}

          with {:ok, plan} <-
                 Repo.update(
                   Ecto.Changeset.change(plan,
                     snapshot: snapshot,
                     published_revision: plan.revision,
                     published_at: Workforce.now()
                   )
                 ) do
            Workforce.audit(me, "plan.published", %{plan_id: plan.id, revision: plan.revision})

            Enum.each(
              team.members,
              &Workforce.notify(
                &1.id,
                "Planning publié",
                "Le planning de #{team.name} est publié à partir du #{plan.start}."
              )
            )

            {:ok, data(plan, me)}
          end
        end
      end)
    end
  end

  defp validate_publication(plan, shifts, team) do
    rules = Workforce.rules(team.organization_id)
    members = Enum.map(team.members, & &1.id)

    cond do
      shifts == [] ->
        Workforce.invalid("Ajoutez des gardes avant publication.")

      plan.published_revision == plan.revision ->
        Workforce.conflict("Cette version est déjà publiée.")

      Date.diff(plan.start, Date.utc_today()) < rules["publishDaysAhead"] ->
        Workforce.invalid("Le délai de publication de l’organisation n’est pas respecté.")

      Enum.any?(shifts, &(&1.user_id not in members)) ->
        Workforce.conflict("La composition de l’équipe a changé.")

      true ->
        constraints(shifts, plan.id, team.organization_id, rules)
    end
  end

  def constraints(candidate, excluded_plan, org_id, rules) do
    teams = Teams.list_teams(org_id) |> Enum.map(& &1.id)

    others =
      Repo.all(
        from p in Plan,
          where: p.team_id in ^teams and p.id != ^excluded_plan and not is_nil(p.published_at)
      )
      |> Enum.flat_map(fn p -> Enum.map(p.snapshot["shifts"] || [], &snapshot_shift/1) end)

    records = candidate ++ others
    users = Enum.uniq(Enum.map(candidate, & &1.user_id))

    error =
      Enum.find_value(users, fn id ->
        relevant =
          Enum.filter(records, &(&1.user_id == id and &1.kind not in ["rest", "leave"]))
          |> Enum.sort_by(&DateTime.to_unix(&1.start))

        overlaps =
          relevant
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.any?(fn [a, b] -> DateTime.compare(a.end, b.start) == :gt end)

        nights =
          relevant
          |> Enum.filter(&(&1.kind == "night"))
          |> Enum.map(&DateTime.to_date(&1.start))
          |> Enum.uniq()
          |> Enum.sort(Date)

        run =
          Enum.reduce(nights, {nil, 0, 0}, fn day, {previous, current, max_run} ->
            count = if previous && Date.diff(day, previous) == 1, do: current + 1, else: 1
            {day, count, max(max_run, count)}
          end)
          |> elem(2)

        weekly = Enum.frequencies_by(nights, &Workforce.monday/1)
        monthly = Enum.frequencies_by(nights, &{&1.year, &1.month})

        absent =
          Enum.any?(relevant, fn s ->
            Repo.exists?(
              from a in Absence,
                where:
                  a.user_id == ^id and a.status == "approved" and a.start < ^s.end and
                    a.end > ^s.start
            )
          end)

        cond do
          overlaps ->
            "Deux gardes se chevauchent pour un agent."

          absent ->
            "Une garde chevauche une absence approuvée."

          run > rules["maxConsecutiveNights"] ->
            "Le maximum de nuits consécutives est dépassé."

          rules["maxNightsPerWeek"] > 0 and
              Enum.any?(weekly, fn {_, n} -> n > rules["maxNightsPerWeek"] end) ->
            "Le maximum hebdomadaire de nuits est dépassé."

          rules["maxNightsPerMonth"] > 0 and
              Enum.any?(monthly, fn {_, n} -> n > rules["maxNightsPerMonth"] end) ->
            "Le maximum mensuel de nuits est dépassé."

          true ->
            nil
        end
      end)

    if error, do: Workforce.invalid(error), else: :ok
  end

  def lock_organization(nil), do: :ok

  def lock_organization(id),
    do:
      Repo.query!("SELECT id FROM organizations WHERE id = $1::uuid FOR UPDATE", [
        Ecto.UUID.dump!(id)
      ])

  def shifts(id),
    do: Repo.all(from s in Shift, where: s.plan_id == ^id, order_by: [asc: s.start, asc: s.id])

  defp string_shift(s), do: Workforce.plain(s) |> Jason.encode!() |> Jason.decode!()

  defp snapshot_shift(s) do
    %{
      id: s["id"],
      user_id: s["user_id"],
      kind: s["kind"],
      start: elem(Workforce.datetime(s["start"]), 1),
      end: elem(Workforce.datetime(s["end"]), 1)
    }
  end

  def data(plan, me) do
    {:ok, team} = Teams.fetch_team(plan.team_id)

    can_manage =
      me.role.name == "administrator" or (me.role.name == "manager" and team.manager_id == me.id)

    rows =
      if can_manage,
        do: Enum.map(shifts(plan.id), &Workforce.plain/1),
        else: plan.snapshot["shifts"] || []

    users =
      Enum.map(team.members, fn user ->
        %{
          id: user.id,
          username: user.username,
          name: Enum.reject([user.first_name, user.last_name], &is_nil/1) |> Enum.join(" ")
        }
      end)

    Map.merge(Workforce.plain(plan), %{
      shifts: rows,
      members: users,
      team_name: team.name,
      published: plan.revision == plan.published_revision,
      can_manage: can_manage,
      can_publish:
        me.role.name == "administrator" or
          (me.role.name == "manager" and team.manager_id == me.id and
             Workforce.permission(team.id).publish)
    })
    |> Map.drop([:snapshot])
  end

  defp invalidate_swaps(me, ids, reason) do
    rows =
      Repo.all(
        from s in Swap,
          where:
            s.status in ["pending", "consented"] and
              (s.shift_id in ^ids or s.target_shift_id in ^ids),
          lock: "FOR UPDATE"
      )

    Enum.each(rows, fn row ->
      Repo.update!(
        Ecto.Changeset.change(row,
          status: "rejected",
          reviewer_id: me.id,
          reviewed_at: Workforce.now(),
          review_reason: reason
        )
      )

      Workforce.audit(me, "swap.rejected", %{request_id: row.id, reason: reason})

      Enum.each(
        [row.user_id, row.target_user_id],
        &Workforce.notify(&1, "Échange annulé", reason)
      )
    end)

    :ok
  end

  def swaps(me) do
    ids = Workforce.visible_ids(me)

    rows =
      Repo.all(
        from s in Swap,
          where: s.user_id in ^ids or s.target_user_id == ^me.id,
          order_by: [desc: s.id]
      )

    {:ok, Enum.map(rows, &Workforce.plain/1)}
  end

  def request_swap(me, attrs) do
    with {:ok, source} <- Workforce.fetch(Shift, attrs["shift_id"]),
         {:ok, target} <- Workforce.fetch(Shift, attrs["target_shift_id"]),
         {:ok, plan} <- Workforce.fetch(Plan, source.plan_id),
         {:ok, _} <- Workforce.team(me, plan.team_id),
         :ok <-
           Workforce.check(
             source.user_id == me.id and target.user_id != me.id and
               target.plan_id == source.plan_id
           ),
         :ok <-
           if(
             is_binary(attrs["reason"]) and String.length(String.trim(attrs["reason"])) in 1..500,
             do: :ok,
             else: Workforce.invalid("Indiquez un motif de 1 à 500 caractères.")
           ) do
      Repo.transact(fn ->
        with {:ok, plan} <- Workforce.fetch(Plan, plan.id, true),
             :ok <-
               if(plan.revision == plan.published_revision,
                 do: :ok,
                 else:
                   Workforce.conflict(
                     "Le planning doit être publié sans modifications en attente."
                   )
               ),
             {:ok, source} <- Workforce.fetch(Shift, source.id, true),
             {:ok, target} <- Workforce.fetch(Shift, target.id, true),
             :ok <-
               Workforce.check(
                 source.user_id == me.id and target.user_id != me.id and target.plan_id == plan.id
               ),
             :ok <-
               if(
                 source.kind in ["day", "night", "oncall"] and
                   target.kind in ["day", "night", "oncall"],
                 do: :ok,
                 else: Workforce.invalid("Seules les gardes travaillées peuvent être échangées.")
               ),
             :ok <- valid_shift(plan, source),
             :ok <- valid_shift(plan, target),
             :ok <-
               if(
                 Repo.exists?(
                   from s in Swap,
                     where: s.shift_id == ^source.id and s.status in ["pending", "consented"]
                 ), do: Workforce.conflict("Un échange est déjà en attente."), else: :ok),
             {:ok, row} <-
               Repo.insert(%Swap{
                 user_id: me.id,
                 target_user_id: target.user_id,
                 shift_id: source.id,
                 target_shift_id: target.id,
                 reason: String.trim(attrs["reason"]),
                 proposal: %{"source" => string_shift(source), "target" => string_shift(target)}
               }) do
          Workforce.audit(me, "swap.requested", %{request_id: row.id})

          Workforce.notify(
            target.user_id,
            "Échange proposé",
            "Un collègue propose un échange de gardes. Votre accord est nécessaire."
          )

          {:ok, Workforce.plain(row)}
        end
      end)
    end
  end

  def consent(me, id, accepted) do
    Repo.transact(fn ->
      with {:ok, row} <- Workforce.fetch(Swap, id, true),
           :ok <- Workforce.check(row.target_user_id == me.id),
           :ok <-
             if(row.status == "pending" and is_boolean(accepted),
               do: :ok,
               else: Workforce.conflict("Cette proposition n’est plus en attente.")
             ),
           {:ok, row} <-
             Repo.update(
               Ecto.Changeset.change(row, status: if(accepted, do: "consented", else: "rejected"))
             ) do
        Workforce.audit(me, "swap.consent", %{request_id: row.id, accepted: accepted})

        Workforce.notify(
          row.user_id,
          "Réponse à l’échange",
          if(accepted,
            do: "Votre collègue accepte l’échange ; le responsable doit le valider.",
            else: "Votre collègue refuse l’échange."
          )
        )

        if accepted,
          do:
            Workforce.notify_reviewers(
              me,
              "Échange à examiner",
              "Un échange accepté par les deux agents attend votre décision."
            )

        {:ok, Workforce.plain(row)}
      end
    end)
  end

  def review_swap(me, id, attrs) do
    with {:ok, initial} <- Workforce.fetch(Swap, id),
         :ok <-
           Workforce.check(
             Workforce.allowed?(me, initial.user_id, :validate) and
               Workforce.allowed?(me, initial.target_user_id, :validate)
           ),
         :ok <- TimeSheets.valid_decision(attrs) do
      Repo.transact(fn ->
        lock_organization(me.organization_id)

        with {:ok, source} <- Workforce.fetch(Shift, initial.shift_id),
             {:ok, plan} <- Workforce.fetch(Plan, source.plan_id, true),
             {:ok, row} <- Workforce.fetch(Swap, id, true),
             :ok <-
               if(row.status == "consented",
                 do: :ok,
                 else:
                   Workforce.conflict(
                     "L’accord du collègue est nécessaire et la demande ne doit pas être déjà traitée."
                   )
               ),
             :ok <- apply_swap(me, plan, row, attrs["status"]),
             {:ok, row} <-
               Repo.update(
                 Ecto.Changeset.change(row,
                   status: attrs["status"],
                   reviewer_id: me.id,
                   reviewed_at: Workforce.now(),
                   review_reason: attrs["reason"] || ""
                 )
               ) do
          Workforce.audit(me, "swap.#{row.status}", %{request_id: row.id})

          Enum.each(
            [row.user_id, row.target_user_id],
            &Workforce.notify(
              &1,
              "Échange examiné",
              "Votre échange est #{row.status}. #{row.review_reason}"
            )
          )

          {:ok, Workforce.plain(row)}
        end
      end)
    end
  end

  defp apply_swap(_, _, _, "rejected"), do: :ok

  defp apply_swap(me, plan, row, "approved") do
    with {:ok, team} <- Workforce.team(me, plan.team_id, :publish),
         {:ok, source} <- Workforce.fetch(Shift, row.shift_id, true),
         {:ok, target} <- Workforce.fetch(Shift, row.target_shift_id, true),
         :ok <-
           if(
             string_shift(source) == row.proposal["source"] and
               string_shift(target) == row.proposal["target"] and
               plan.revision == plan.published_revision,
             do: :ok,
             else: Workforce.conflict("Les gardes ont changé depuis la proposition.")
           ),
         :ok <- valid_shift(plan, source),
         :ok <- valid_shift(plan, target),
         :ok <-
           if(
             Enum.all?([source.user_id, target.user_id], fn id ->
               Enum.any?(team.members, &(&1.id == id))
             end), do: :ok, else: Workforce.conflict("La composition de l’équipe a changé.")),
         {:ok, _} <- Repo.update(Ecto.Changeset.change(source, user_id: target.user_id)),
         {:ok, _} <- Repo.update(Ecto.Changeset.change(target, user_id: source.user_id)),
         candidates = shifts(plan.id),
         :ok <-
           constraints(
             candidates,
             plan.id,
             team.organization_id,
             Workforce.rules(team.organization_id)
           ),
         {:ok, _} <-
           Repo.update(
             Ecto.Changeset.change(plan,
               revision: plan.revision + 1,
               published_revision: plan.revision + 1,
               snapshot: %{"shifts" => Enum.map(candidates, &string_shift/1)},
               published_at: Workforce.now()
             )
           ),
         do: :ok
  end
end
