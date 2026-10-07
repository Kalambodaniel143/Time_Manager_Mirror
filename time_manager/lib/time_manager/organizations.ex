defmodule TimeManager.Organizations do
  @moduledoc """
  Organizations, requests to join them and their members
  (docs/CONTRAT_BACKEND_ORGANISATIONS.md).

    * Anyone can create an organization: its creator becomes its administrator.
    * Anyone can ask to join one. The request holds no password and creates no
      account; it is followed with a private, random reference.
    * Only an administrator of the organization approves a request (which
      creates an employee with the password the administrator chose), rejects
      it, or switches a member between employee and manager.

  Errors are `{:error, changeset}` (422), `{:error, {:not_found, detail}}`,
  `{:error, {:conflict, detail, field_errors}}` (409) or
  `{:error, {:forbidden, detail}}`. Permissions are checked by the caller
  (`TimeManager.Authorization.organization_admin?/2`).
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias TimeManager.Accounts
  alias TimeManager.Accounts.User
  alias TimeManager.Organizations.{JoinRequest, Organization}
  alias TimeManager.Repo

  @member_roles ~w(employee manager)

  @name_taken {:conflict, "Une organisation porte déjà ce nom.",
               %{name: ["Ce nom est déjà utilisé."]}}
  @email_taken {:conflict, "Cette adresse email possède déjà un compte.",
                %{email: ["Cette adresse est déjà utilisée."]}}
  @request_pending {:conflict,
                    "Une demande est déjà en attente pour cette adresse dans cette organisation.",
                    %{email: ["Une demande est déjà en attente."]}}
  @already_reviewed {:conflict, "Cette demande a déjà été traitée.", %{}}

  ## Organizations

  @doc """
  Creates the organization and its administrator in one transaction: either
  both exist afterwards, or neither. Both are validated before anything is
  written, so every invalid field is reported at once.
  """
  def create_organization(name, profile, password) do
    organization = Organization.changeset(%Organization{}, %{"name" => name})
    role = Accounts.get_role_by_name("administrator")

    admin =
      User.member_changeset(%User{}, map(profile), password, role.id, nil,
        personal_details: false
      )

    if organization.valid? and admin.valid? do
      Repo.transact(fn ->
        with {:ok, organization} <- Repo.insert(organization) |> conflict(:name, @name_taken),
             {:ok, admin} <-
               admin
               |> Changeset.put_change(:organization_id, organization.id)
               |> Repo.insert()
               |> conflict(:email, @email_taken) do
          {:ok, Repo.preload(admin, [:role, :organization])}
        end
      end)
    else
      {:error, merge_errors(admin, organization)}
    end
  end

  @doc "Finds an organization by its exact normalized name."
  def lookup_organization(name) when is_binary(name) do
    case Repo.get_by(Organization, normalized_name: Organization.normalize_name(name)) do
      nil -> {:error, organization_not_found()}
      organization -> {:ok, organization}
    end
  end

  def lookup_organization(_name), do: {:error, organization_not_found()}

  ## Join requests

  @doc """
  Records a pending request and returns it with its private reference. The
  reference is only returned here: the database keeps its SHA-256.
  """
  def submit_join_request(organization_id, profile) do
    reference = 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    with {:ok, organization} <- fetch_organization(organization_id),
         %Changeset{valid?: true} = changeset <-
           JoinRequest.submit_changeset(
             %JoinRequest{},
             map(profile),
             organization.id,
             hash(reference)
           ),
         :ok <- ensure_no_account(Changeset.get_field(changeset, :email)),
         {:ok, request} <- changeset |> Repo.insert() |> conflict(:email, @request_pending) do
      {:ok, %{request | organization: organization}, reference}
    else
      %Changeset{} = changeset -> {:error, changeset}
      error -> error
    end
  end

  @doc "The request matching a private reference."
  def fetch_join_request_by_reference(reference) when is_binary(reference) do
    case Repo.get_by(JoinRequest, reference_hash: hash(reference)) do
      nil -> {:error, {:not_found, "Référence de demande introuvable."}}
      request -> {:ok, Repo.preload(request, :organization)}
    end
  end

  def fetch_join_request_by_reference(_reference),
    do: {:error, {:not_found, "Référence de demande introuvable."}}

  def list_join_requests(organization_id) do
    from(r in JoinRequest, where: r.organization_id == ^organization_id, order_by: r.inserted_at)
    |> Repo.all()
    |> Repo.preload(:organization)
  end

  @doc """
  Approves a pending request: creates the employee with `password` and marks
  the request approved, in one transaction. The request row is locked, so two
  concurrent approvals create a single account; the second one gets a conflict.
  On any error the request stays pending and no account is created.
  """
  def approve_join_request(organization_id, id, password, %User{} = reviewer) do
    role = Accounts.get_role_by_name("employee")

    Repo.transact(fn ->
      with {:ok, request} <- lock_pending_request(organization_id, id),
           {:ok, user} <-
             %User{}
             |> User.member_changeset(
               JoinRequest.profile(request),
               password,
               role.id,
               organization_id
             )
             |> Repo.insert()
             |> conflict(:email, @email_taken),
           {:ok, request} <- request |> JoinRequest.approve_changeset(reviewer) |> Repo.update() do
        {:ok, %{request: request, user: Repo.preload(user, :role)}}
      end
    end)
  end

  @doc "Rejects a pending request with a reason (1 to 500 characters)."
  def reject_join_request(organization_id, id, reason, %User{} = reviewer) do
    Repo.transact(fn ->
      with {:ok, request} <- lock_pending_request(organization_id, id) do
        request |> JoinRequest.reject_changeset(reason, reviewer) |> Repo.update()
      end
    end)
  end

  ## Members

  @doc """
  Switches a member between employee and manager. Administrators are out of
  reach: the creator of an organization can be neither demoted nor duplicated
  from here.
  """
  def set_member_role(organization_id, member_id, role) when role in @member_roles do
    with {:ok, member} <- Accounts.fetch_organization_member(organization_id, member_id),
         :ok <- ensure_not_administrator(member) do
      Accounts.change_role(member, role)
    else
      {:error, :not_found} -> {:error, {:not_found, "Membre introuvable."}}
      error -> error
    end
  end

  def set_member_role(_organization_id, _member_id, _role) do
    changeset =
      %User{}
      |> Changeset.change()
      |> Changeset.add_error(:role, "must be employee or manager",
        validation: :inclusion,
        enum: @member_roles
      )

    {:error, changeset}
  end

  ## Helpers

  defp fetch_organization(id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Organization{} = organization <- Repo.get(Organization, id) do
      {:ok, organization}
    else
      _ -> {:error, organization_not_found()}
    end
  end

  defp lock_pending_request(organization_id, id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %JoinRequest{} = request <-
           Repo.one(
             from r in JoinRequest,
               where: r.id == ^id and r.organization_id == ^organization_id,
               lock: "FOR UPDATE"
           ) do
      if request.status == "pending",
        do: {:ok, Repo.preload(request, :organization)},
        else: {:error, @already_reviewed}
    else
      _ -> {:error, {:not_found, "Demande introuvable."}}
    end
  end

  defp ensure_no_account(email) do
    if Accounts.list_users(%{"email" => email}) == [], do: :ok, else: {:error, @email_taken}
  end

  defp ensure_not_administrator(%User{role: %{name: "administrator"}}),
    do: {:error, {:forbidden, "Seuls les rôles employé et manager peuvent être modifiés ici."}}

  defp ensure_not_administrator(_member), do: :ok

  # A unique index violated on `field` becomes a 409 instead of a 422.
  defp conflict({:error, %Changeset{errors: errors} = changeset}, field, conflict) do
    case errors[field] do
      {_message, opts} ->
        if opts[:constraint] == :unique, do: {:error, conflict}, else: {:error, changeset}

      nil ->
        {:error, changeset}
    end
  end

  defp conflict(result, _field, _conflict), do: result

  defp merge_errors(changeset, other) do
    Enum.reduce(other.errors, %{changeset | valid?: false}, fn {field, {message, opts}}, acc ->
      Changeset.add_error(acc, field, message, opts)
    end)
  end

  defp organization_not_found,
    do: {:not_found, "Aucune organisation ne porte ce nom. Vérifiez son orthographe."}

  defp map(profile) when is_map(profile), do: profile
  defp map(_profile), do: %{}

  defp hash(reference), do: :crypto.hash(:sha256, reference)
end
