defmodule TimeManager.Workforce.Absences do
  import Ecto.Query
  alias TimeManager.{Repo, Workforce}
  alias TimeManager.Workforce.{Absence, TimeSheets}
  alias TimeManager.Accounts.User

  def list(me) do
    ids = Workforce.visible_ids(me)

    {:ok,
     Repo.all(from a in Absence, where: a.user_id in ^ids, order_by: [desc: a.id])
     |> Enum.map(&Workforce.plain/1)}
  end

  def create(me, attrs) when is_map(attrs) do
    with {:ok, start} <- Workforce.datetime(attrs["start"]),
         {:ok, finish} <- Workforce.datetime(attrs["end"]),
         :ok <-
           if(
             DateTime.diff(finish, start) in 1..31_622_400 and
               attrs["kind"] in ["leave", "sick", "recup"],
             do: :ok,
             else: Workforce.invalid("Durée ou type d’absence invalide.")
           ),
         :ok <-
           if(is_binary(attrs["reason"] || "") and String.length(attrs["reason"] || "") <= 500,
             do: :ok,
             else: Workforce.invalid("Motif limité à 500 caractères.")
           ) do
      Repo.transact(fn ->
        {:ok, _} = Workforce.fetch(User, me.id, true)

        with :ok <- Workforce.mutable(me.id, start, finish),
             :ok <- no_overlap(me.id, start, finish),
             {:ok, row} <-
               Repo.insert(%Absence{
                 user_id: me.id,
                 start: start,
                 end: finish,
                 kind: attrs["kind"],
                 reason: attrs["reason"] || ""
               }) do
          Workforce.audit(me, "absence.requested", %{request_id: row.id})

          Workforce.notify_reviewers(
            me,
            "Absence à examiner",
            "#{me.username} a envoyé une demande d’absence."
          )

          {:ok, Workforce.plain(row)}
        end
      end)
    end
  end

  def create(_, _), do: {:error, :bad_request}

  def cancel(me, id, attrs) do
    with {:ok, initial} <- Workforce.fetch(Absence, id),
         :ok <-
           Workforce.check(
             (initial.user_id == me.id and initial.status == "pending") or
               Workforce.allowed?(me, initial.user_id, :validate)
           ),
         :ok <-
           if(
             is_binary(attrs["reason"]) and String.length(String.trim(attrs["reason"])) in 1..500,
             do: :ok,
             else: Workforce.invalid("Indiquez un motif d’annulation.")
           ) do
      Repo.transact(fn ->
        {:ok, _} = Workforce.fetch(User, initial.user_id, true)

        with {:ok, row} <- Workforce.fetch(Absence, id, true),
             :ok <-
               Workforce.check(
                 (row.user_id == me.id and row.status == "pending") or
                   Workforce.allowed?(me, row.user_id, :validate)
               ),
             :ok <-
               if(row.status in ["pending", "approved"],
                 do: :ok,
                 else: Workforce.conflict("Cette absence n’est plus active.")
               ),
             :ok <- Workforce.mutable(row.user_id, row.start, row.end),
             {:ok, row} <-
               Repo.update(
                 Ecto.Changeset.change(row,
                   status: "cancelled",
                   reviewer_id: me.id,
                   reviewed_at: Workforce.now(),
                   review_reason: String.trim(attrs["reason"])
                 )
               ) do
          Workforce.audit(me, "absence.cancelled", %{
            request_id: row.id,
            user_id: row.user_id,
            reason: row.review_reason
          })

          Workforce.notify(row.user_id, "Absence annulée", row.review_reason)
          {:ok, Workforce.plain(row)}
        end
      end)
    end
  end

  def no_overlap(id, start, finish, except \\ 0) do
    if Repo.exists?(
         from a in Absence,
           where:
             a.user_id == ^id and a.id != ^except and a.status in ["pending", "approved"] and
               a.start < ^finish and a.end > ^start
       ), do: Workforce.conflict("Une absence existe déjà sur cette période."), else: :ok
  end

  def payment(me, id, attrs) do
    with {:ok, initial} <- Workforce.fetch(Absence, id),
         :ok <- Workforce.check(Workforce.allowed?(me, initial.user_id, :validate)) do
      Repo.transact(fn ->
        {:ok, _} = Workforce.fetch(User, initial.user_id, true)

        with {:ok, row} <- Workforce.fetch(Absence, id, true),
             :ok <-
               if(row.status == "approved",
                 do: :ok,
                 else:
                   Workforce.conflict(
                     "Seule une absence approuvée peut être complétée pour la paie."
                   )
               ),
             :ok <- Workforce.mutable(row.user_id, row.start, row.end),
             {:ok, hours} <- payable_hours(row, attrs),
             :ok <-
               if(not is_nil(hours),
                 do: :ok,
                 else: Workforce.invalid("Renseignez le nombre d’heures rémunérables.")
               ),
             {:ok, row} <- Repo.update(Ecto.Changeset.change(row, payable_hours: hours)) do
          Workforce.audit(me, "absence.payment.updated", %{
            request_id: row.id,
            user_id: row.user_id,
            payable_hours: hours
          })

          Workforce.notify(
            row.user_id,
            "Heures d’absence confirmées",
            "Les heures rémunérables de votre absence ont été confirmées."
          )

          {:ok, Workforce.plain(row)}
        end
      end)
    end
  end

  defp payable_hours(row, attrs) do
    case attrs["payable_hours"] do
      nil ->
        {:ok, row.payable_hours}

      value ->
        case Decimal.cast(value) do
          {:ok, %Decimal{coef: coef} = hours} when is_integer(coef) ->
            limit = Decimal.div(Decimal.new(DateTime.diff(row.end, row.start)), Decimal.new(3600))

            if row.kind != "recup" and Decimal.compare(hours, Decimal.new(0)) != :lt and
                 Decimal.compare(hours, limit) != :gt,
               do: {:ok, Decimal.round(hours, 4)},
               else:
                 Workforce.invalid(
                   "Les heures rémunérables doivent être positives et ne pas dépasser la plage d’absence ; la récupération prise n’est pas rémunérée."
                 )

          _ ->
            Workforce.invalid("Nombre d’heures rémunérables invalide.")
        end
    end
  end

  def review(me, id, attrs) do
    with {:ok, initial} <- Workforce.fetch(Absence, id),
         :ok <- Workforce.check(Workforce.allowed?(me, initial.user_id, :validate)),
         :ok <- TimeSheets.valid_decision(attrs) do
      Repo.transact(fn ->
        {:ok, _} = Workforce.fetch(User, initial.user_id, true)

        with {:ok, row} <- Workforce.fetch(Absence, id, true),
             :ok <-
               if(row.status == "pending",
                 do: :ok,
                 else: Workforce.conflict("Cette demande a déjà été traitée.")
               ),
             :ok <-
               if(attrs["status"] == "approved",
                 do: Workforce.mutable(row.user_id, row.start, row.end),
                 else: :ok
               ),
             :ok <-
               if(attrs["status"] == "approved",
                 do: no_overlap(row.user_id, row.start, row.end, row.id),
                 else: :ok
               ),
             :ok <-
               if(
                 attrs["status"] == "approved" and
                   Repo.exists?(
                     from p in TimeManager.WorkingTimes.WorkingTime,
                       where:
                         p.user_id == ^row.user_id and p.start < ^row.end and p.end > ^row.start
                   ),
                 do: Workforce.conflict("Des heures travaillées existent sur cette absence."),
                 else: :ok
               ),
             {:ok, payable} <- payable_hours(row, attrs),
             {:ok, row} <-
               Repo.update(
                 Ecto.Changeset.change(row,
                   payable_hours: payable,
                   status: attrs["status"],
                   reviewer_id: me.id,
                   reviewed_at: Workforce.now(),
                   review_reason: attrs["reason"] || ""
                 )
               ) do
          Workforce.audit(me, "absence.#{row.status}", %{request_id: row.id, user_id: row.user_id})

          Workforce.notify(
            row.user_id,
            "Absence examinée",
            "Votre demande est #{row.status}. #{row.review_reason}"
          )

          {:ok, Workforce.plain(row)}
        end
      end)
    end
  end
end
