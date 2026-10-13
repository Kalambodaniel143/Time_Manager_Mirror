defmodule TimeManager.Accounts.PasswordRecovery do
  @moduledoc "One-use recovery codes: 15 minutes, five attempts, hashed at rest."
  use Ecto.Schema
  import Ecto.Query
  alias TimeManager.Accounts.User
  alias TimeManager.{Accounts, Email, EmailDelivery, Repo}

  @primary_key {:user_id, :id, autogenerate: false}
  schema "password_recoveries" do
    field :code_hash, :string, redact: true
    field :expires_at, :utc_datetime
    field :attempts, :integer, default: 0
  end

  def request(email) do
    result =
      Repo.transact(fn ->
        case Repo.one(from u in User, where: u.email == ^normalize(email), lock: "FOR UPDATE") do
          %User{} = user when not is_nil(user.email_verified_at) ->
            code =
              :crypto.strong_rand_bytes(4)
              |> :binary.decode_unsigned()
              |> rem(100_000_000)
              |> Integer.to_string()
              |> String.pad_leading(8, "0")

            attrs = %{
              user_id: user.id,
              code_hash: hash(code),
              expires_at: DateTime.add(now(), 900),
              attempts: 0
            }

            Repo.insert_all(__MODULE__, [attrs],
              on_conflict: {:replace, [:code_hash, :expires_at, :attempts]},
              conflict_target: :user_id
            )

            {:ok, {user.email, code}}

          _ ->
            {:ok, nil}
        end
      end)

    case result do
      {:ok, {address, code}} ->
        # Do not disclose account existence or codes in public responses/logs.
        EmailDelivery.send_later(Email.password_recovery(address, code))

      {:ok, nil} ->
        :ok

      error ->
        error
    end
  end

  def complete(email, code, password) do
    result =
      Repo.transact(fn ->
        user = Repo.one(from u in User, where: u.email == ^normalize(email), lock: "FOR UPDATE")
        recovery = user && Repo.get(__MODULE__, user.id)

        result =
          cond do
            is_nil(recovery) or DateTime.compare(recovery.expires_at, now()) != :gt or
                recovery.attempts >= 5 ->
              invalid_code()

            not Plug.Crypto.secure_compare(recovery.code_hash, hash(code)) ->
              recovery |> Ecto.Changeset.change(attempts: recovery.attempts + 1) |> Repo.update!()
              invalid_code()

            true ->
              changeset =
                user
                |> User.password_changeset(%{"password" => password})
                |> Ecto.Changeset.put_change(:session_version, user.session_version + 1)

              case Repo.update(changeset) do
                {:ok, updated} ->
                  Repo.delete!(recovery)
                  {:ok, updated}

                error ->
                  error
              end
          end

        # Commit failed-attempt counters, even when the public outcome is an error.
        {:ok, result}
      end)

    case result do
      {:ok, {:ok, user}} ->
        Accounts.deliver_password_changed(user)
        :ok

      {:ok, error} ->
        error

      error ->
        error
    end
  end

  defp invalid_code,
    do:
      {:error,
       {:unprocessable_entity,
        "Le code est incorrect, expiré ou déjà utilisé. Demandez un nouveau code et saisissez les huit chiffres du dernier email reçu."}}

  defp normalize(email), do: email |> String.trim() |> String.downcase()
  defp hash(code), do: :crypto.hash(:sha256, code) |> Base.encode16(case: :lower)
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
