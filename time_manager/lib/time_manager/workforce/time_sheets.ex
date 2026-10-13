defmodule TimeManager.Workforce.TimeSheets do
  import Ecto.Query
  alias TimeManager.{Accounts, Clocks, Repo, Workforce, WorkingTimes}
  alias TimeManager.Workforce.{Correction, Sheet}
  alias TimeManager.Accounts.User

  def week(value) do
    with {:ok, date} <- Workforce.date(value),
         :ok <-
           if(Date.day_of_week(date) == 1,
             do: :ok,
             else: Workforce.invalid("La semaine doit commencer un lundi.")
           ),
         do: {:ok, date}
  end

  def list(me, value) do
    with {:ok, week} <- week(value) do
      ids = Workforce.visible_ids(me)
      users = Repo.all(from u in User, where: u.id in ^ids)

      {:ok,
       Enum.map(users, fn user ->
         sheet_data(
           Repo.get_by(Sheet, user_id: user.id, week: week) ||
             %Sheet{user_id: user.id, week: week}
         )
       end)}
    end
  end

  def get_note(me, id, value) do
    with {:ok, user} <- Workforce.target(me, id),
         {:ok, week} <- week(value),
         do:
           {:ok,
            sheet_data(
              Repo.get_by(Sheet, user_id: user.id, week: week) ||
                %Sheet{user_id: user.id, week: week}
            )}
  end

  def put_note(me, id, value, note) do
    with {:ok, user} <- Workforce.target(me, id),
         :ok <- Workforce.check(user.id == me.id),
         {:ok, week} <- week(value),
         :ok <-
           if(is_binary(note) and String.length(note) <= 2000,
             do: :ok,
             else: Workforce.invalid("La note est limitée à 2000 caractères.")
           ) do
      Repo.transact(fn ->
        {:ok, _} = Workforce.fetch(User, user.id, true)

        row =
          Repo.get_by(Sheet, user_id: user.id, week: week) || %Sheet{user_id: user.id, week: week}

        with :ok <-
               if(row.status == "open",
                 do: :ok,
                 else:
                   Workforce.conflict("La semaine doit être rouverte avant de changer sa note.")
               ),
             {:ok, row} <-
               Repo.insert_or_update(Ecto.Changeset.change(row, note: String.trim(note))) do
          Workforce.audit(me, "note.updated", %{user_id: user.id, week: week})

          Workforce.notify_reviewers(
            user,
            "Note partagée",
            "#{user.username} a partagé une note pour la semaine du #{week}."
          )

          {:ok, sheet_data(row)}
        end
      end)
    end
  end

  def validate_batch(me, params) do
    ids = params["user_ids"]

    with {:ok, week} <- week(params["week"]),
         :ok <-
           if(
             is_list(ids) and length(ids) in 1..100 and
               Enum.all?(ids, &(is_integer(&1) and &1 > 0)),
             do: :ok,
             else: Workforce.invalid("Sélectionnez de 1 à 100 comptes.")
           ),
         :ok <-
           if(Date.compare(Date.add(week, 7), Date.utc_today()) != :gt,
             do: :ok,
             else: Workforce.invalid("Seules les semaines terminées peuvent être validées.")
           ) do
      Repo.transact(fn ->
        ids
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.reduce_while({:ok, []}, fn id, {:ok, rows} ->
          result =
            with {:ok, user} <- Accounts.fetch_user(id),
                 :ok <- Workforce.check(Workforce.allowed?(me, id, :validate)),
                 {:ok, _} <- Workforce.fetch(User, id, true),
                 :ok <- verify_week(user, week) do
              row = Repo.get_by(Sheet, user_id: id, week: week) || %Sheet{user_id: id, week: week}

              with :ok <-
                     if(row.status == "open",
                       do: :ok,
                       else:
                         Workforce.conflict(
                           "Une semaine sélectionnée est déjà validée ou clôturée."
                         )
                     ),
                   {:ok, row} <-
                     Repo.insert_or_update(
                       Ecto.Changeset.change(row,
                         status: "validated",
                         reviewer_id: me.id,
                         reviewed_at: Workforce.now()
                       )
                     ) do
                Workforce.audit(me, "sheet.validated", %{user_id: id, week: week})

                Workforce.notify(
                  id,
                  "Heures validées",
                  "Vos heures de la semaine du #{week} ont été validées."
                )

                {:ok, sheet_data(row)}
              end
            end

          case result do
            {:ok, row} -> {:cont, {:ok, rows ++ [row]}}
            error -> {:halt, error}
          end
        end)
      end)
    end
  end

  def transition(me, id, value, action, reason) do
    with {:ok, user} <- Workforce.target(me, id),
         :ok <- Workforce.check(Workforce.allowed?(me, user.id, :validate)),
         {:ok, week} <- week(value),
         :ok <- if(action in ["close", "reopen"], do: :ok, else: {:error, :bad_request}),
         :ok <-
           if(is_binary(reason) and String.length(String.trim(reason)) in 1..500,
             do: :ok,
             else: Workforce.invalid("Indiquez un motif de 1 à 500 caractères.")
           ) do
      Repo.transact(fn ->
        {:ok, _} = Workforce.fetch(User, user.id, true)
        row = Repo.get_by(Sheet, user_id: user.id, week: week)

        cond do
          is_nil(row) ->
            {:error, :not_found}

          action == "close" and row.status != "validated" ->
            Workforce.conflict("La semaine doit être validée avant clôture.")

          action == "reopen" and row.status == "open" ->
            Workforce.conflict("Cette semaine est déjà ouverte.")

          true ->
            status = if action == "close", do: "closed", else: "open"

            with {:ok, row} <-
                   Repo.update(
                     Ecto.Changeset.change(row,
                       status: status,
                       reviewer_id: me.id,
                       reviewed_at: Workforce.now(),
                       reason: String.trim(reason)
                     )
                   ) do
              Workforce.audit(me, "sheet.#{action}", %{
                user_id: user.id,
                week: week,
                reason: reason
              })

              Workforce.notify(
                user.id,
                "État de votre semaine modifié",
                "Semaine du #{week} : #{status}. #{reason}"
              )

              {:ok, sheet_data(row)}
            end
        end
      end)
    end
  end

  defp verify_week(user, week) do
    end_date = Date.add(week, 7)
    {:ok, start} = DateTime.new(week, ~T[00:00:00], "Etc/UTC")
    {:ok, finish} = DateTime.new(end_date, ~T[00:00:00], "Etc/UTC")
    history = Clocks.list_clocks(user)

    open_service =
      history
      |> Enum.reduce(nil, fn clock, open ->
        case clock.kind do
          :arrival -> clock.time
          :departure -> nil
          _ -> open
        end
      end)

    pending =
      Repo.exists?(
        from c in Correction,
          where:
            c.user_id == ^user.id and c.status == "pending" and c.before_start < ^finish and
              c.before_end > ^start
      )

    cond do
      open_service && DateTime.compare(open_service, finish) == :lt ->
        Workforce.conflict("Un départ manquant bloque la validation.")

      pending ->
        Workforce.conflict("Une demande de correction est encore en attente.")

      true ->
        :ok
    end
  end

  def corrections(me, params) do
    ids = Workforce.visible_ids(me)

    with {:ok, ids} <- filter_ids(ids, params["user_id"]) do
      rows = Repo.all(from c in Correction, where: c.user_id in ^ids, order_by: [desc: c.id])
      {:ok, Enum.map(rows, &correction_data/1)}
    end
  end

  defp filter_ids(ids, nil), do: {:ok, ids}

  defp filter_ids(ids, value) do
    with {:ok, id} <- Workforce.id(value), :ok <- Workforce.check(id in ids), do: {:ok, [id]}
  end

  def request_correction(me, period_id, attrs) when is_map(attrs) do
    Repo.transact(fn ->
      {:ok, _} = Workforce.fetch(User, me.id, true)

      with {:ok, period} <- Workforce.fetch(TimeManager.WorkingTimes.WorkingTime, period_id, true),
           :ok <- Workforce.check(period.user_id == me.id),
           :ok <- Workforce.mutable(me.id, period.start, period.end),
           {:ok, start} <- Workforce.datetime(attrs["start"]),
           {:ok, finish} <- Workforce.datetime(attrs["end"]),
           :ok <- valid_proposal(start, finish, attrs["reason"]),
           :ok <- Workforce.mutable(me.id, start, finish) do
        pending =
          Repo.exists?(
            from c in Correction, where: c.period_id == ^period.id and c.status == "pending"
          )

        if pending do
          Workforce.conflict("Une correction est déjà en attente pour cette période.")
        else
          row = %Correction{
            user_id: me.id,
            period_id: period.id,
            before_start: period.start,
            before_end: period.end,
            start: start,
            end: finish,
            reason: String.trim(attrs["reason"])
          }

          with {:ok, row} <-
                 Repo.insert(
                   Ecto.Changeset.change(row)
                   |> Ecto.Changeset.unique_constraint(:period_id, name: :one_pending_correction)
                 ) do
            Workforce.audit(me, "correction.requested", %{
              request_id: row.id,
              period_id: period.id
            })

            Workforce.notify_reviewers(
              me,
              "Correction à examiner",
              "#{me.username} propose une correction de ses horaires."
            )

            {:ok, correction_data(row)}
          end
        end
      end
    end)
  end

  def request_correction(_, _, _), do: {:error, :bad_request}

  defp valid_proposal(start, finish, reason) do
    cond do
      not is_binary(reason) or String.length(String.trim(reason)) not in 1..500 ->
        Workforce.invalid("Indiquez un motif de 1 à 500 caractères.")

      DateTime.compare(finish, start) != :gt ->
        Workforce.invalid("Le départ doit suivre l’arrivée.")

      DateTime.compare(finish, Workforce.now()) == :gt ->
        Workforce.invalid("Les horaires ne peuvent pas être dans le futur.")

      true ->
        :ok
    end
  end

  def review_correction(me, id, attrs) do
    with {:ok, initial} <- Workforce.fetch(Correction, id),
         :ok <- Workforce.check(Workforce.allowed?(me, initial.user_id, :correct)) do
      Repo.transact(fn ->
        {:ok, _} = Workforce.fetch(User, initial.user_id, true)

        with {:ok, row} <- Workforce.fetch(Correction, id, true),
             :ok <-
               if(row.status == "pending",
                 do: :ok,
                 else: Workforce.conflict("Cette demande a déjà été traitée.")
               ),
             :ok <- valid_decision(attrs),
             :ok <- apply_correction(row, attrs["status"], me),
             {:ok, row} <-
               Repo.update(
                 Ecto.Changeset.change(row,
                   status: attrs["status"],
                   reviewer_id: me.id,
                   reviewed_at: Workforce.now(),
                   review_reason: String.trim(attrs["reason"] || "")
                 )
               ) do
          Workforce.audit(me, "correction.#{row.status}", %{
            request_id: row.id,
            user_id: row.user_id,
            reason: row.review_reason
          })

          Workforce.notify(
            row.user_id,
            if(row.status == "approved", do: "Correction acceptée", else: "Correction refusée"),
            if(row.status == "approved",
              do:
                "Votre demande de correction des heures a été acceptée. Vos horaires ont été mis à jour. ",
              else:
                "Votre demande de correction des heures a été refusée. Vos horaires sont inchangés. "
            ) <> row.review_reason
          )

          {:ok, correction_data(row)}
        end
      end)
    end
  end

  def valid_decision(attrs) when is_map(attrs) do
    reason = attrs["reason"] || ""

    cond do
      attrs["status"] not in ["approved", "rejected"] ->
        {:error, :bad_request}

      not is_binary(reason) or String.length(reason) > 500 ->
        Workforce.invalid("Motif invalide.")

      attrs["status"] == "rejected" and String.trim(reason) == "" ->
        Workforce.invalid("Le motif du refus est obligatoire.")

      true ->
        :ok
    end
  end

  def valid_decision(_), do: {:error, :bad_request}

  defp apply_correction(_, "rejected", _), do: :ok

  defp apply_correction(row, "approved", actor) do
    with {:ok, period} <-
           Workforce.fetch(TimeManager.WorkingTimes.WorkingTime, row.period_id, true),
         :ok <-
           if(period.start == row.before_start and period.end == row.before_end,
             do: :ok,
             else: Workforce.conflict("Les horaires ont changé depuis la demande.")
           ),
         {:ok, _} <-
           WorkingTimes.update_working_time(period, %{start: row.start, end: row.end}, actor),
         do: :ok
  end

  def correction_data(row) do
    user = Repo.get(User, row.user_id)
    reviewer = row.reviewer_id && Repo.get(User, row.reviewer_id)

    %{
      id: row.id,
      user_id: row.user_id,
      period_id: row.period_id,
      username: (user && user.username) || "Compte supprimé",
      before: %{start: row.before_start, end: row.before_end},
      proposal: %{start: row.start, end: row.end},
      reason: row.reason,
      status: row.status,
      created_at: row.inserted_at,
      reviewed_at: row.reviewed_at,
      reviewed_by: reviewer && reviewer.username,
      review_reason: row.review_reason
    }
  end

  defp sheet_data(row), do: Workforce.plain(row)
end
