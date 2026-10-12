defmodule TimeManager.Workforce.Payroll do
  @moduledoc "UTC calendar aggregation with exclusive night/overtime categories and decimal amounts."
  import Ecto.Query
  alias TimeManager.{Accounts, Authorization, Repo, Workforce}
  alias TimeManager.WorkingTimes.WorkingTime
  alias TimeManager.Workforce.{Absence, PayProfile}

  def month(value) when is_binary(value) do
    case Date.from_iso8601(value <> "-01") do
      {:ok, first} ->
        last = Date.add(first, Date.days_in_month(first))
        {:ok, first, last}

      _ ->
        {:error, :bad_request}
    end
  end

  def month(_), do: {:error, :bad_request}

  def report(me, value) do
    with :ok <- Workforce.check(Authorization.administrator?(me)),
         {:ok, first, last} <- month(value) do
      users = Accounts.list_users(%{}, {:organization, me.organization_id})
      rows = Enum.map(users, &user_report(&1, first, last))

      {:ok,
       %{
         month: value,
         timezone: "Etc/UTC",
         rules: Workforce.rules(me.organization_id),
         rows: rows,
         total: Enum.reduce(rows, 0, &(&1.total + &2)),
         currency_totals: currency_totals(rows)
       }}
    end
  end

  defp currency_totals(rows) do
    rows
    |> Enum.filter(& &1.amount)
    |> Enum.group_by(& &1.currency)
    |> Map.new(fn {currency, rows} ->
      {currency,
       rows
       |> Enum.reduce(Decimal.new(0), fn row, total ->
         Decimal.add(total, Decimal.new(row.amount))
       end)
       |> Decimal.to_string()}
    end)
  end

  def user_report(user, first, last) do
    rules = Workforce.rules(user.organization_id)
    from = midnight(Workforce.monday(first))
    finish = midnight(last)

    periods =
      Repo.all(
        from p in WorkingTime,
          where: p.user_id == ^user.id and p.start < ^finish and p.end > ^from,
          order_by: [asc: p.start, asc: p.id]
      )

    {seconds, _weeks} =
      Enum.reduce(periods, {empty(), %{}}, fn period, acc ->
        accumulate(period, first, last, rules, acc)
      end)

    absences =
      Repo.all(
        from a in Absence,
          where:
            a.user_id == ^user.id and a.status == "approved" and a.start < ^finish and
              a.end > ^midnight(first)
      )

    seconds =
      Enum.reduce(absences, seconds, fn absence, sums ->
        Map.update!(
          sums,
          Map.fetch!(
            %{"leave" => :leave, "sick" => :sick, "recup" => :recup_taken},
            absence.kind
          ),
          &(&1 + overlap(absence.start, absence.end, midnight(first), finish))
        )
      end)

    hours = Map.new(seconds, fn {key, value} -> {key, value / 3600} end)
    profile = Repo.get_by(PayProfile, user_id: user.id) || %PayProfile{user_id: user.id}

    all_work =
      Repo.all(
        from p in WorkingTime,
          where: p.user_id == ^user.id and p.start < ^finish and p.end > ^midnight(first)
      )

    paid_absence_seconds =
      Enum.filter(absences, &(&1.kind in rules["paidAbsenceKinds"]))
      |> Enum.reduce(0, fn absence, total ->
        overlap_seconds = overlap(absence.start, absence.end, midnight(first), finish)

        declared_seconds =
          if absence.payable_hours,
            do:
              absence.payable_hours
              |> Decimal.mult(Decimal.new(3600))
              |> Decimal.round(0)
              |> Decimal.to_integer(),
            else: 0

        covered =
          round(declared_seconds * overlap_seconds / DateTime.diff(absence.end, absence.start))

        worked =
          Enum.reduce(all_work, 0, fn period, sum ->
            lower =
              if DateTime.compare(period.start, midnight(first)) == :gt,
                do: period.start,
                else: midnight(first)

            upper = if DateTime.compare(period.end, finish) == :lt, do: period.end, else: finish
            sum + overlap(absence.start, absence.end, lower, upper)
          end)

        total + max(0, covered - worked)
      end)

    incomplete_absence =
      Enum.any?(absences, &(&1.kind in rules["paidAbsenceKinds"] and is_nil(&1.payable_hours)))

    absence_conflict =
      Enum.any?(absences, fn absence ->
        Enum.any?(
          all_work,
          &(DateTime.compare(&1.start, absence.end) == :lt and
              DateTime.compare(&1.end, absence.start) == :gt)
        )
      end)

    weighted =
      Decimal.new(seconds.day)
      |> Decimal.add(
        Decimal.mult(
          Decimal.new(seconds.night),
          Decimal.from_float(rules["nightMultiplier"] * 1.0)
        )
      )
      |> Decimal.add(
        Decimal.mult(
          Decimal.new(seconds.sup),
          Decimal.from_float(rules["overtimeMultiplier"] * 1.0)
        )
      )
      |> Decimal.add(Decimal.new(seconds.oncall))
      |> Decimal.add(Decimal.new(paid_absence_seconds))

    amount =
      if profile.hourly_rate && not incomplete_absence,
        do:
          weighted
          |> Decimal.div(Decimal.new(3600))
          |> Decimal.mult(profile.hourly_rate)
          |> Decimal.round(2)
          |> Decimal.to_string()

    Map.merge(hours, %{
      id: user.id,
      name:
        Enum.reject([user.first_name, user.last_name], &is_nil/1)
        |> Enum.join(" ")
        |> then(fn name -> if name == "", do: user.username, else: name end),
      email: user.email,
      total: (seconds.day + seconds.night + seconds.sup + seconds.recup + seconds.oncall) / 3600,
      hourly_rate: profile.hourly_rate && Decimal.to_string(profile.hourly_rate),
      currency: profile.currency,
      amount: amount,
      paid_absence_hours: paid_absence_seconds / 3600,
      absence_payment_incomplete: incomplete_absence,
      absence_conflict: absence_conflict,
      absence_payment: rules["paidAbsenceKinds"],
      confirmed:
        not incomplete_absence and not absence_conflict and confirmed?(user.id, first, last)
    })
  end

  defp confirmed?(id, first, last) do
    weeks =
      Stream.iterate(Workforce.monday(first), &Date.add(&1, 7))
      |> Enum.take_while(&(Date.compare(&1, last) == :lt))

    rows =
      Repo.all(
        from s in TimeManager.Workforce.Sheet,
          where: s.user_id == ^id and s.week in ^weeks and s.status in ["validated", "closed"]
      )

    length(rows) == length(weeks)
  end

  defp empty,
    do: %{day: 0, night: 0, sup: 0, recup: 0, oncall: 0, leave: 0, sick: 0, recup_taken: 0}

  def midnight(date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  def overlap(start, finish, from, to),
    do:
      max(
        0,
        min(DateTime.to_unix(finish), DateTime.to_unix(to)) -
          max(DateTime.to_unix(start), DateTime.to_unix(from))
      )

  defp accumulate(period, first, last, rules, acc) do
    cursor =
      max(DateTime.to_unix(period.start), DateTime.to_unix(midnight(Workforce.monday(first))))

    finish = min(DateTime.to_unix(period.end), DateTime.to_unix(midnight(last)))
    pieces(cursor, finish, period.kind, first, rules, acc)
  end

  defp pieces(cursor, finish, _kind, _first, _rules, acc) when cursor >= finish, do: acc

  defp pieces(cursor, finish, kind, first, rules, {sums, weeks}) do
    date = DateTime.from_unix!(cursor)
    seconds = min(finish - cursor, 3600 - rem(cursor, 3600))
    week = Workforce.monday(DateTime.to_date(date))
    used = Map.get(weeks, week, 0)
    threshold = rules["overtimeThreshold"] * 3600
    base = if kind == "work", do: min(seconds, max(0, threshold - used)), else: seconds
    overtime = if kind == "work", do: seconds - base, else: 0

    ordinary_kind =
      case kind do
        "oncall" -> :oncall
        "recup" -> :recup
        _ -> if night?(date.hour, rules), do: :night, else: :day
      end

    sums =
      if Date.compare(DateTime.to_date(date), first) != :lt do
        sums |> Map.update!(ordinary_kind, &(&1 + base)) |> Map.update!(:sup, &(&1 + overtime))
      else
        sums
      end

    weeks = if kind == "work", do: Map.put(weeks, week, used + seconds), else: weeks
    pieces(cursor + seconds, finish, kind, first, rules, {sums, weeks})
  end

  def night?(hour, rules) do
    start = rules["nightStart"]
    finish = rules["nightEnd"]
    if start > finish, do: hour >= start or hour < finish, else: hour >= start and hour < finish
  end

  def profile(me, id) do
    with {:ok, user} <- Workforce.target(me, id),
         :ok <- Workforce.check(me.id == user.id or Authorization.administrator_of?(me, user.id)),
         do:
           {:ok,
            Workforce.plain(
              Repo.get_by(PayProfile, user_id: user.id) || %PayProfile{user_id: user.id}
            )}
  end

  def update_profile(me, id, attrs) when is_map(attrs) do
    with {:ok, user} <- Workforce.target(me, id),
         :ok <- Workforce.check(Authorization.administrator_of?(me, user.id)),
         :ok <- rate_input(attrs["hourly_rate"]) do
      Repo.transact(fn ->
        {:ok, _} = Workforce.fetch(TimeManager.Accounts.User, user.id, true)
        row = Repo.get_by(PayProfile, user_id: user.id) || %PayProfile{user_id: user.id}

        changeset =
          row
          |> Ecto.Changeset.cast(attrs, [:hourly_rate, :currency])
          |> Ecto.Changeset.validate_number(:hourly_rate,
            greater_than_or_equal_to: 0,
            less_than_or_equal_to: 100_000
          )
          |> Ecto.Changeset.validate_inclusion(:currency, ["EUR", "USD", "GBP"])

        changeset =
          Ecto.Changeset.validate_change(changeset, :hourly_rate, fn :hourly_rate, value ->
            if is_integer(value.coef) and Decimal.equal?(value, Decimal.round(value, 2)),
              do: [],
              else: [hourly_rate: "must be finite and have at most two decimal places"]
          end)

        with {:ok, row} <- Repo.insert_or_update(changeset) do
          Workforce.audit(me, "payroll.profile.updated", %{
            user_id: user.id,
            hourly_rate: row.hourly_rate,
            currency: row.currency
          })

          {:ok, Workforce.plain(row)}
        end
      end)
    end
  end

  def update_profile(_, _, _), do: {:error, :bad_request}
  defp rate_input(nil), do: :ok

  defp rate_input(value) do
    case Decimal.cast(value) do
      {:ok, %Decimal{coef: coef} = decimal} when is_integer(coef) ->
        if Decimal.equal?(decimal, Decimal.round(decimal, 2)),
          do: :ok,
          else: Workforce.invalid("Le taux doit avoir au maximum deux décimales.")

      _ ->
        Workforce.invalid("Le taux horaire doit être un nombre fini.")
    end
  end

  def csv(report) do
    columns = [
      :name,
      :email,
      :day,
      :night,
      :sup,
      :recup,
      :oncall,
      :leave,
      :sick,
      :recup_taken,
      :paid_absence_hours,
      :total,
      :hourly_rate,
      :currency,
      :amount,
      :confirmed
    ]

    header =
      "Agent;Email;Jour;Nuit;Heures supplémentaires;Récupération;Astreinte;Congé;Maladie;Récupération prise;Absence rémunérée;Total travaillé;Taux horaire;Devise;Montant calculé;Semaines validées"

    Enum.join(
      [
        header
        | Enum.map(report.rows, fn row -> Enum.map_join(columns, ";", &cell(Map.get(row, &1))) end)
      ],
      "\n"
    )
  end

  defp cell(value) do
    text = if is_nil(value), do: "", else: to_string(value)
    text = if Regex.match?(~r/^\s*[=+@-]/, text), do: "'" <> text, else: text
    "\"" <> String.replace(text, "\"", "\"\"") <> "\""
  end
end
