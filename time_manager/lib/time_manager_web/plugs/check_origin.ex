defmodule TimeManagerWeb.Plugs.CheckOrigin do
  @moduledoc """
  Refuses (403) a state-changing request (POST, PUT, PATCH, DELETE) sent by a
  browser from another site.

  The API is served under the same origin as the front-end (Nginx or Vite
  proxy), so a legitimate browser request has an `Origin` (or, failing that, a
  `Referer`) whose host is the host of the request. This completes the CSRF
  token and the SameSite cookie, and also covers the public routes that have no
  session yet (login, organization creation). A request without either header
  (curl, server-to-server) is let through: it carries no browser cookie to abuse.
  """
  import Plug.Conn

  @safe_methods ~w(GET HEAD OPTIONS)

  def init(opts), do: opts

  def call(%Plug.Conn{method: method} = conn, _opts) when method in @safe_methods, do: conn

  def call(conn, _opts) do
    case source(conn) do
      nil -> conn
      source -> if URI.parse(source).host == conn.host, do: conn, else: forbidden(conn)
    end
  end

  defp source(conn) do
    case {get_req_header(conn, "origin"), get_req_header(conn, "referer")} do
      {[origin | _], _} -> origin
      {[], [referer | _]} -> referer
      {[], []} -> nil
    end
  end

  defp forbidden(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, Jason.encode!(%{errors: %{detail: "Origine de la requête refusée."}}))
    |> halt()
  end
end
