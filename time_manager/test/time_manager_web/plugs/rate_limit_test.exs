defmodule TimeManagerWeb.Plugs.RateLimitTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias TimeManagerWeb.Plugs.RateLimit

  defp run(opts, params \\ %{}) do
    conn = conn(:post, "/api/auth/login", params) |> Plug.Conn.fetch_query_params()
    RateLimit.call(%{conn | params: params}, RateLimit.init([enabled: true] ++ opts))
  end

  test "lets `limit` requests through, then answers 429 with Retry-After" do
    opts = [bucket: make_ref(), limit: 2, period: :timer.minutes(1)]

    refute run(opts).halted
    refute run(opts).halted

    blocked = run(opts)
    assert blocked.halted
    assert blocked.status == 429
    assert [retry_after] = Plug.Conn.get_resp_header(blocked, "retry-after")
    assert String.to_integer(retry_after) in 1..60
    assert Jason.decode!(blocked.resp_body)["errors"]["detail"]
  end

  test "by: :email counts each account separately, whatever the case" do
    opts = [bucket: make_ref(), limit: 1, by: :email]

    refute run(opts, %{"email" => "a@example.com"}).halted
    assert run(opts, %{"email" => " A@Example.com"}).halted
    refute run(opts, %{"email" => "b@example.com"}).halted
  end
end
