#!/usr/bin/env bash
# Explicit operator provisioning. Passwords are prompted, never saved in the repo.
set -euo pipefail

if [[ ! -t 0 ]]; then
  printf 'Lancez cette commande dans votre terminal pour saisir le mot de passe de façon masquée.\n' >&2
  exit 1
fi

task_repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$task_repo_root/time_manager"

read -r -p "Email [nando@gotham.city] : " task_admin_email
read -r -p "Prénom [Nando] (reprendre celui du mock) : " task_admin_first_name
read -r -p "Nom [Martin] (reprendre celui du mock) : " task_admin_last_name
IFS= read -r -s -p "Ancien mot de passe du mock : " task_admin_password
printf '\n'
IFS= read -r -s -p "Confirme le même mot de passe : " task_admin_confirmation
printf '\n'

if [[ "$task_admin_password" != "$task_admin_confirmation" ]]; then
  printf 'Les mots de passe ne correspondent pas. Aucun compte créé.\n' >&2
  exit 1
fi
if (( ${#task_admin_password} < 8 || ${#task_admin_password} > 128 )); then
  printf 'Le mot de passe doit contenir entre 8 et 128 caractères. Aucun compte créé.\n' >&2
  exit 1
fi

export ADMIN_EMAIL="${task_admin_email:-nando@gotham.city}"
export ADMIN_FIRST_NAME="${task_admin_first_name:-Nando}"
export ADMIN_LAST_NAME="${task_admin_last_name:-Martin}"
export ADMIN_PASSWORD="$task_admin_password"
unset task_admin_password task_admin_confirmation

task_provision_file="$(mktemp /tmp/gotham-admin-provision.XXXXXX.exs)"
trap 'rm -f "$task_provision_file"; unset ADMIN_PASSWORD' EXIT
cat > "$task_provision_file" <<'ELIXIR'
Logger.configure(level: :warning)

alias TimeManager.{Accounts, Organizations, Repo}
alias TimeManager.Accounts.User
alias TimeManager.Organizations.Organization
import Ecto.Query

profile = %{
  "first_name" => String.trim(System.fetch_env!("ADMIN_FIRST_NAME")),
  "last_name" => String.trim(System.fetch_env!("ADMIN_LAST_NAME")),
  "email" => System.fetch_env!("ADMIN_EMAIL") |> String.trim() |> String.downcase()
}
password = System.fetch_env!("ADMIN_PASSWORD")

if Enum.any?(["first_name", "last_name", "email"], &(profile[&1] == "")) do
  raise "Prénom, nom et email doivent être renseignés. Aucun compte créé."
end

if is_nil(Accounts.get_role_by_name("administrator")) do
  raise "Le rôle administrator est absent. Appliquez les migrations de référence avant cette commande."
end

result =
  case Accounts.list_users(%{"email" => profile["email"]}) do
    [user] ->
      case Organizations.lookup_organization("Gotham City") do
        {:ok, organization} ->
          if user.organization_id == organization.id and user.role.name == "administrator" and
               user.first_name == profile["first_name"] and user.last_name == profile["last_name"] and
               User.valid_password?(user, password) and User.verified?(user) do
            {:ok, user}
          else
            {:error, :existing_account_differs}
          end

        _ ->
          {:error, :existing_account_differs}
      end

    [] ->
      case Organizations.lookup_organization("Gotham City") do
        {:ok, organization} ->
          Repo.transact(fn ->
            # Serialize this provisioning against another invocation on the same city.
            Repo.one!(from o in Organization, where: o.id == ^organization.id, lock: "FOR UPDATE")
            has_admin =
              Repo.exists?(from u in User, join: r in assoc(u, :role),
                where: u.organization_id == ^organization.id and r.name == "administrator")

            if has_admin do
              {:error, :administrator_already_exists}
            else
              attrs = Map.merge(profile, %{"username" => profile["email"], "password" => password})
              Accounts.create_user(attrs, "administrator", organization.id)
            end
          end)

        {:error, _} ->
          Organizations.create_organization("Gotham City", profile, password)
      end
  end

case result do
  {:ok, user} ->
    IO.puts("Super administrateur prêt : #{user.email} — Gotham City.")
    IO.puts("Connectez-vous en mode réel avec le mot de passe saisi.")

  {:error, :existing_account_differs} ->
    IO.puts(:stderr, "Cet email existe déjà, mais son identité, rôle, organisation ou mot de passe diffère. Aucune modification effectuée.")
    System.halt(1)

  {:error, :administrator_already_exists} ->
    IO.puts(:stderr, "Gotham City possède déjà un autre super administrateur. Aucun compte créé ni remplacé.")
    System.halt(1)

  {:error, %Ecto.Changeset{} = changeset} ->
    IO.puts(:stderr, "Création refusée : #{inspect(changeset.errors)}")
    System.halt(1)

  {:error, _} ->
    IO.puts(:stderr, "Création refusée. Vérifiez les informations, les migrations et la configuration de la base.")
    System.halt(1)
end
ELIXIR

# mix run starts the application/Repo, but must not launch a second HTTP listener.
env -u PHX_SERVER mix run "$task_provision_file"
