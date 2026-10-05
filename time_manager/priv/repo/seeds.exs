# Populates the reference data. Safe to run several times (idempotent):
#
#     mix run priv/repo/seeds.exs
#
# 1. The three predefined roles (also inserted by the migrations).
# 2. A first administrator, only when ADMIN_EMAIL and ADMIN_PASSWORD are set.
#    The password never lives in the repository: it comes from the environment
#    (the server's .env, filled by the CI).

alias TimeManager.Accounts
alias TimeManager.Accounts.Role
alias TimeManager.Repo

now = DateTime.utc_now() |> DateTime.truncate(:second)

Repo.insert_all(
  Role,
  Enum.map(Role.names(), &%{name: &1, inserted_at: now, updated_at: now}),
  on_conflict: :nothing,
  conflict_target: :name
)

email = System.get_env("ADMIN_EMAIL")
password = System.get_env("ADMIN_PASSWORD")

cond do
  is_nil(email) or is_nil(password) or email == "" or password == "" ->
    IO.puts("seeds: ADMIN_EMAIL or ADMIN_PASSWORD not set, no administrator created")

  Accounts.list_users(%{"email" => email}) != [] ->
    IO.puts("seeds: administrator #{email} already exists, left unchanged")

  true ->
    attrs = %{
      "username" => System.get_env("ADMIN_USERNAME", "admin"),
      "email" => email,
      "password" => password
    }

    case Accounts.create_user(attrs, "administrator") do
      {:ok, user} ->
        IO.puts("seeds: administrator #{user.email} created")

      {:error, changeset} ->
        raise "seeds: cannot create the administrator: #{inspect(changeset.errors)}"
    end
end
