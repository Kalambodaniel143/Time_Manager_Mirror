defmodule TimeManager.OrganizationsConcurrencyTest do
  # Independent database connections are required to exercise the row lock.
  use ExUnit.Case, async: false

  import Ecto.Query
  import TimeManager.AccountsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias TimeManager.Accounts.User
  alias TimeManager.Organizations
  alias TimeManager.Organizations.{JoinRequest, Organization}
  alias TimeManager.Repo

  setup do
    {admin, request} =
      Sandbox.unboxed_run(Repo, fn ->
        admin = organization_admin_fixture()
        {request, _reference} = join_request_fixture(admin.organization_id)
        {admin, request}
      end)

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        org = admin.organization_id
        Repo.delete_all(from r in JoinRequest, where: r.organization_id == ^org)
        Repo.delete_all(from u in User, where: u.organization_id == ^org)
        Repo.delete_all(from o in Organization, where: o.id == ^org)
      end)
    end)

    %{admin: admin, request: request, supervisor: start_supervised!({Task.Supervisor, []})}
  end

  test "two concurrent approvals create a single account",
       %{admin: admin, request: request} = ctx do
    approve = fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Organizations.approve_join_request(
          admin.organization_id,
          request.id,
          valid_password(),
          admin
        )
      end)
    end

    results =
      [approve, approve]
      |> Enum.map(&Task.Supervisor.async(ctx.supervisor, &1))
      |> Task.await_many(10_000)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, {:conflict, _, _}}, &1)) == 1

    Sandbox.unboxed_run(Repo, fn ->
      email = request.email
      assert Repo.aggregate(from(u in User, where: u.email == ^email), :count) == 1
    end)
  end
end
