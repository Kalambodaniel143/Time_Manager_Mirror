defmodule TimeManagerWeb.PasswordRecoveryTest do
  use TimeManagerWeb.ConnCase, async: true
  import TimeManager.AccountsFixtures
  alias TimeManager.{Accounts, Repo}
  alias TimeManager.Accounts.PasswordRecovery

  test "known and unknown accounts receive the same response; recovery is single use and revokes sessions" do
    user = user_fixture()
    previous_session = log_in(build_conn(), user)
    known = post(build_conn(), "/api/auth/forgot-password", email: user.email)
    unknown = post(build_conn(), "/api/auth/forgot-password", email: "unknown@example.com")
    assert json_response(known, 202) == json_response(unknown, 202)
    assert_receive {:email, email}
    [code] = Regex.run(~r/\d{8}/, email.text_body)
    refute Repo.get!(PasswordRecovery, user.id).code_hash == code
    refute response(known, 202) =~ code
    refute_receive {:email, _}

    reset =
      post(build_conn(), "/api/auth/reset-password",
        email: user.email,
        code: code,
        password: "a new secret phrase"
      )

    assert json_response(reset, 200)["data"]["message"] =~ "réinitialisé"
    assert_receive {:email, changed}
    assert changed.subject =~ "Password changed"
    refute changed.text_body =~ "a new secret phrase"
    assert {:error, :invalid_credentials} = Accounts.authenticate(user.email, valid_password())
    assert {:ok, _} = Accounts.authenticate(user.email, "a new secret phrase")
    assert json_response(get(previous_session, "/api/auth/me"), 401)

    assert json_response(
             post(build_conn(), "/api/auth/reset-password",
               email: user.email,
               code: code,
               password: "another secret phrase"
             ),
             422
           )
  end

  test "five wrong codes invalidate recovery and the counter is persisted" do
    user = user_fixture()
    assert :ok = PasswordRecovery.request(user.email)
    assert_receive {:email, email}
    [code] = Regex.run(~r/\d{8}/, email.text_body)

    for _ <- 1..5,
        do:
          assert(
            {:error, _} =
              PasswordRecovery.complete(user.email, "wrong-code", "a new secret phrase")
          )

    assert Repo.get!(PasswordRecovery, user.id).attempts == 5
    assert {:error, _} = PasswordRecovery.complete(user.email, code, "a new secret phrase")
    assert {:ok, _} = Accounts.authenticate(user.email, valid_password())
  end

  test "expired and replaced codes fail; a weak password does not consume a correct code" do
    user = user_fixture()
    PasswordRecovery.request(user.email)
    assert_receive {:email, first}
    [old_code] = Regex.run(~r/\d{8}/, first.text_body)
    PasswordRecovery.request(user.email)
    assert_receive {:email, second}
    [code] = Regex.run(~r/\d{8}/, second.text_body)

    if code != old_code,
      do:
        assert(
          {:error, _} = PasswordRecovery.complete(user.email, old_code, "a new secret phrase")
        )

    assert {:error, %Ecto.Changeset{}} = PasswordRecovery.complete(user.email, code, "123456789")
    assert Repo.get!(PasswordRecovery, user.id)

    Repo.get!(PasswordRecovery, user.id)
    |> Ecto.Changeset.change(
      expires_at: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), -1)
    )
    |> Repo.update!()

    assert {:error, _} = PasswordRecovery.complete(user.email, code, "a new secret phrase")
  end

  test "changing a password invalidates outstanding recovery codes and sends an email" do
    user = user_fixture()
    PasswordRecovery.request(user.email)
    assert_receive {:email, _}
    conn = log_in(build_conn(), user)

    changed =
      put(conn, "/api/users/#{user.id}",
        user: %{current_password: valid_password(), password: "my new password phrase"}
      )

    assert json_response(changed, 200)
    assert_receive {:email, email}
    assert email.subject =~ "Password changed"
    assert is_nil(Repo.get(PasswordRecovery, user.id))
    assert json_response(get(conn, "/api/auth/me"), 401)
  end
end
