defmodule TimeManager.Organizations.JoinRequest do
  @moduledoc """
  A request to join an organization. It holds the applicant's profile but no
  password and no account: the account is only created when an administrator
  of the organization approves it (`TimeManager.Organizations`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TimeManager.Accounts.Profile

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "join_requests" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :gender, :string
    field :birth_date, :date
    field :birth_place, :string
    field :status, :string, default: "pending"
    field :reference_hash, :binary, redact: true
    field :rejection_reason, :string
    field :reviewed_at, :utc_datetime

    belongs_to :organization, TimeManager.Organizations.Organization, type: :binary_id
    belongs_to :reviewed_by, TimeManager.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def submit_changeset(request, profile, organization_id, reference_hash) do
    request
    |> cast(profile, Profile.identity_fields() ++ Profile.personal_fields())
    |> Profile.validate_identity()
    |> Profile.validate_personal_details()
    |> put_change(:organization_id, organization_id)
    |> put_change(:reference_hash, reference_hash)
    |> unique_constraint(:email, name: :join_requests_pending_email_index)
  end

  def approve_changeset(request, reviewer) do
    change(request, status: "approved", reviewed_at: now(), reviewed_by_id: reviewer.id)
  end

  @doc """
  The reason is trimmed and must keep 1 to 500 characters. Its errors are
  reported on `reason`, the field of the request body.
  """
  def reject_changeset(request, reason, reviewer) do
    reason = String.trim(reason)

    changeset =
      change(request,
        status: "rejected",
        rejection_reason: reason,
        reviewed_at: now(),
        reviewed_by_id: reviewer.id
      )

    cond do
      reason == "" ->
        add_error(changeset, :reason, "can't be blank", validation: :required)

      String.length(reason) > 500 ->
        add_error(changeset, :reason, "should be at most %{count} character(s)",
          count: 500,
          validation: :length,
          kind: :max,
          type: :string
        )

      true ->
        changeset
    end
  end

  @doc "The profile fields, as attributes for the account to create."
  def profile(%__MODULE__{} = request) do
    Map.take(request, Profile.identity_fields() ++ Profile.personal_fields())
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
