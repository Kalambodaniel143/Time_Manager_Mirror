defmodule TimeManager.Workforce do
  @moduledoc "Shared policy, preferences, audit and notifications for persisted workflows."
  import Ecto.Query
  alias TimeManager.{Accounts, Authorization, Repo, Teams}
  alias TimeManager.Accounts.User
  alias TimeManager.Workforce.{Event, Notification, Permission, Preference, Setting, Sheet}

  @rules %{
    "maxConsecutiveNights" => 3,
    "maxNightsPerWeek" => 0,
    "maxNightsPerMonth" => 0,
    "overtimeThreshold" => 40,
    "publishDaysAhead" => 14,
    "nightStart" => 22,
    "nightEnd" => 6,
    "nightMultiplier" => 1.5,
    "overtimeMultiplier" => 2,
    "paidAbsenceKinds" => [],
    "timezone" => "Etc/UTC"
  }
  @preferences %{
    "theme" => "light",
    "strong_text" => false,
    "tour_seen" => false,
    "speech_enabled" => false,
    "speech_rate" => 1,
    "speech_voice" => ""
  }
  @default_permissions %{validate: true, correct: true, publish: false}

  def check(true), do: :ok
  def check(false), do: {:error, :forbidden}
  def invalid(detail), do: {:error, {:unprocessable_entity, detail}}
  def conflict(detail), do: {:error, {:conflict, detail}}
  def now, do: DateTime.utc_now() |> DateTime.truncate(:second)
  def monday(date), do: Date.add(date, 1 - Date.day_of_week(date))

  def date(value) do
    case Ecto.Type.cast(:date, value) do
      {:ok, date} when not is_nil(date) -> {:ok, date}
      _ -> {:error, :bad_request}
    end
  end

  def id(value) do
    case Ecto.Type.cast(:id, value) do
      {:ok, id} when is_integer(id) and id > 0 -> {:ok, id}
      _ -> {:error, :bad_request}
    end
  end

  def datetime(value) do
    case Ecto.Type.cast(:utc_datetime, value) do
      {:ok, date} when not is_nil(date) -> {:ok, date}
      _ -> {:error, :bad_request}
    end
  end

  def fetch(schema, id, lock \\ false) do
    with {:ok, id} <- Ecto.Type.cast(:id, id), true <- is_integer(id) and id > 0 do
      query = from r in schema, where: r.id == ^id

      query =
        cond do
          not lock -> query
          schema == User -> lock(query, "FOR NO KEY UPDATE")
          true -> lock(query, "FOR UPDATE")
        end

      case Repo.one(query) do
        nil -> {:error, :not_found}
        record -> {:ok, record}
      end
    else
      _ -> {:error, :not_found}
    end
  end

  def visible_ids(me) do
    case Authorization.user_scope(me) do
      {:organization, org} -> Accounts.list_users(%{}, {:organization, org}) |> Enum.map(& &1.id)
      ids when is_list(ids) -> ids
      _ -> [me.id]
    end
  end

  def target(me, id) do
    with {:ok, user} <- Accounts.fetch_user(id),
         :ok <- check(Authorization.can_view?(me, user.id)),
         do: {:ok, user}
  end

  def team(me, id, action \\ :view) do
    with {:ok, team} <- Teams.fetch_team(id) do
      admin = Authorization.administrator_of_team?(me, team)
      manager = Authorization.manager?(me) and team.manager_id == me.id
      member = Enum.any?(team.members, &(&1.id == me.id))

      allowed =
        case action do
          :view -> admin or manager or member
          :admin -> admin
          key -> admin or (manager and permission(team.id)[key])
        end

      with :ok <- check(allowed), do: {:ok, team}
    end
  end

  def permission(team_id) do
    case Repo.get_by(Permission, team_id: team_id) do
      nil -> @default_permissions
      p -> Map.take(p, [:validate, :correct, :publish])
    end
  end

  def allowed?(me, user_id, key) do
    me.id != user_id and
      (Authorization.administrator_of?(me, user_id) or
         (Authorization.manager?(me) and
            Teams.list_managed_teams(me)
            |> Enum.any?(fn team ->
              Enum.any?(team.members, &(&1.id == user_id)) and permission(team.id)[key]
            end)))
  end

  def rules(org_id) do
    saved = if org_id, do: Repo.get_by(Setting, organization_id: org_id)
    Map.merge(@rules, if(saved, do: saved.rules, else: %{}))
  end

  def get_rules(me, org_id) do
    with :ok <- check(me.organization_id == org_id and not is_nil(org_id)),
         do: {:ok, rules(org_id)}
  end

  def update_rules(me, org_id, attrs) when is_map(attrs) do
    with :ok <- check(Authorization.organization_admin?(me, org_id)),
         :ok <- validate_rules(attrs) do
      Repo.transact(fn ->
        # A shared lock prevents settings, publication and rules checks racing.
        Repo.query!("SELECT id FROM organizations WHERE id = $1::uuid FOR UPDATE", [
          Ecto.UUID.dump!(org_id)
        ])

        old = Repo.get_by(Setting, organization_id: org_id) || %Setting{organization_id: org_id}
        merged = Map.merge(rules(org_id), attrs)

        with :ok <-
               if(merged["nightStart"] != merged["nightEnd"],
                 do: :ok,
                 else: invalid("Le début et la fin des heures de nuit doivent être différents.")
               ),
             {:ok, _} <- Repo.insert_or_update(Ecto.Changeset.change(old, rules: merged)) do
          audit(me, "rules.updated", %{rules: merged})

          notify_managers(
            org_id,
            "Règles modifiées",
            "Les règles de votre organisation ont été mises à jour."
          )

          {:ok, merged}
        end
      end)
    end
  end

  def update_rules(_, _, _), do: {:error, :bad_request}

  defp validate_rules(attrs) do
    bounds = %{
      "maxConsecutiveNights" => {1, 31},
      "maxNightsPerWeek" => {0, 7},
      "maxNightsPerMonth" => {0, 31},
      "overtimeThreshold" => {1, 168},
      "publishDaysAhead" => {0, 365},
      "nightStart" => {0, 23},
      "nightEnd" => {0, 23}
    }

    valid =
      Enum.all?(attrs, fn {key, value} ->
        cond do
          Map.has_key?(bounds, key) ->
            {low, high} = bounds[key]
            is_integer(value) and value >= low and value <= high

          key in ["nightMultiplier", "overtimeMultiplier"] ->
            is_number(value) and value >= 1 and value <= 10

          key == "paidAbsenceKinds" ->
            is_list(value) and length(value) <= 2 and Enum.all?(value, &(&1 in ["leave", "sick"]))

          key == "timezone" ->
            value == "Etc/UTC"

          true ->
            false
        end
      end)

    if valid, do: :ok, else: invalid("Règles invalides. Le fuseau de cette version est Etc/UTC.")
  end

  def update_permission(me, team_id, attrs) when is_map(attrs) do
    with {:ok, team} <- team(me, team_id, :admin),
         :ok <-
           if(
             Enum.all?(attrs, fn {k, v} ->
               k in ["validate", "correct", "publish"] and is_boolean(v)
             end),
             do: :ok,
             else: invalid("Permissions invalides.")
           ) do
      Repo.transact(fn ->
        {:ok, _} = fetch(TimeManager.Teams.Team, team.id, true)
        row = Repo.get_by(Permission, team_id: team.id) || %Permission{team_id: team.id}

        changes =
          Map.new(attrs, fn {key, value} ->
            {Map.fetch!(
               %{"validate" => :validate, "correct" => :correct, "publish" => :publish},
               key
             ), value}
          end)

        with {:ok, _} <- Repo.insert_or_update(Ecto.Changeset.change(row, changes)) do
          audit(me, "permissions.updated", %{team_id: team.id, permissions: attrs})

          if team.manager_id,
            do:
              notify(
                team.manager_id,
                "Permissions modifiées",
                "Vos droits pour #{team.name} ont été mis à jour."
              )

          {:ok, permission(team.id)}
        end
      end)
    end
  end

  def update_permission(_, _, _), do: {:error, :bad_request}

  def preferences(me) do
    saved = Repo.get_by(Preference, user_id: me.id)
    Map.merge(@preferences, if(saved, do: saved.settings, else: %{}))
  end

  def update_preferences(me, attrs) when is_map(attrs) do
    valid =
      Enum.all?(attrs, fn {key, value} ->
        case key do
          "theme" -> value in ["light", "night", "contrast"]
          key when key in ["strong_text", "tour_seen", "speech_enabled"] -> is_boolean(value)
          "speech_rate" -> is_number(value) and value >= 0.5 and value <= 2
          "speech_voice" -> is_binary(value) and String.length(value) <= 200
          _ -> false
        end
      end)

    if valid do
      Repo.transact(fn ->
        {:ok, _} = fetch(User, me.id, true)
        old = Repo.get_by(Preference, user_id: me.id) || %Preference{user_id: me.id}
        settings = Map.merge(preferences(me), attrs)

        with {:ok, _} <- Repo.insert_or_update(Ecto.Changeset.change(old, settings: settings)),
             do: {:ok, settings}
      end)
    else
      invalid("Préférences invalides.")
    end
  end

  def update_preferences(_, _), do: {:error, :bad_request}

  def audit(me, action, details) do
    actor_id = if Repo.exists?(from u in User, where: u.id == ^me.id), do: me.id, else: nil

    Repo.insert!(%Event{
      organization_id: me.organization_id,
      actor_id: actor_id,
      action: action,
      details: Jason.decode!(Jason.encode!(details))
    })
  end

  def record(me, action, details, callback) do
    Repo.transact(fn ->
      with {:ok, result} <- callback.() do
        audit(me, action, if(is_function(details, 1), do: details.(result), else: details))
        {:ok, result}
      end
    end)
  end

  def notify(user_id, title, body),
    do: Repo.insert!(%Notification{user_id: user_id, title: title, body: body})

  def notify_managers(org, title, body) do
    Accounts.list_users(%{}, {:organization, org})
    |> Enum.filter(&(&1.role.name in ["manager", "administrator"]))
    |> Enum.each(&notify(&1.id, title, body))
  end

  def notify_reviewers(user, title, body) do
    Accounts.list_users(%{}, {:organization, user.organization_id})
    |> Enum.filter(&(allowed?(&1, user.id, :validate) or allowed?(&1, user.id, :correct)))
    |> Enum.each(&notify(&1.id, title, body))
  end

  def journal(me, page \\ nil) do
    with :ok <- check(Authorization.administrator?(me)) do
      query = from e in Event, order_by: [desc: e.id], limit: 200

      query =
        if me.organization_id,
          do: where(query, [e], e.organization_id == ^me.organization_id),
          else: where(query, [e], is_nil(e.organization_id))

      rows = query |> TimeManager.Pagination.optional(page) |> Repo.all()
      {:ok, Enum.map(rows, &plain/1)}
    end
  end

  def notifications(me, page \\ nil),
    do:
      from(n in Notification, where: n.user_id == ^me.id, order_by: [desc: n.id], limit: 100)
      |> TimeManager.Pagination.optional(page)
      |> Repo.all()
      |> Enum.map(&plain/1)

  def read_notification(me, id) do
    with {:ok, row} <- fetch(Notification, id),
         :ok <- check(row.user_id == me.id),
         {:ok, row} <- Repo.update(Ecto.Changeset.change(row, read_at: now())),
         do: {:ok, plain(row)}
  end

  def mutable(user_id, start, finish) do
    first = monday(DateTime.to_date(start))
    last = monday(DateTime.to_date(DateTime.add(finish, -1, :second)))

    locked =
      Repo.exists?(
        from s in Sheet,
          where:
            s.user_id == ^user_id and s.week >= ^first and s.week <= ^last and s.status != "open"
      )

    if locked,
      do:
        conflict(
          "Cette semaine est validée ou clôturée. Faites-la rouvrir avant de modifier ses heures."
        ),
      else: :ok
  end

  def plain(record) do
    record
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Map.new(fn {k, v} -> {k, scalar(v)} end)
  end

  defp scalar(%DateTime{} = v), do: DateTime.to_iso8601(v)
  defp scalar(%Date{} = v), do: Date.to_iso8601(v)
  defp scalar(%Decimal{} = v), do: Decimal.to_string(v)
  defp scalar(v), do: v
end
