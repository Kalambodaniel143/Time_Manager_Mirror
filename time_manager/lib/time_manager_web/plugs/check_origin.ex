defmodule TimeManagerWeb.Plugs.CheckOrigin do
  @moduledoc "Compare l'origine complète : protocole, domaine et port."
  import Plug.Conn

  def init(opts), do: opts
  def call(%Plug.Conn{method: method} = conn, _) when method in ~w(GET HEAD OPTIONS), do: conn

  def call(conn, _) do
    expected =
      Application.get_env(:time_manager, :public_origin) ||
        URI.to_string(%URI{scheme: to_string(conn.scheme), host: conn.host, port: conn.port})

    valid =
      case {get_req_header(conn, "origin"), get_req_header(conn, "referer")} do
        {[], []} -> get_req_header(conn, "sec-fetch-site") != ["cross-site"]
        {[source], _} -> same_origin?(source, expected)
        {[], [source]} -> same_origin?(source, expected)
        _ -> false
      end

    if valid, do: conn, else: forbidden(conn)
  end

  defp same_origin?(source, expected) do
    origin = URI.parse(source)
    target = URI.parse(expected)

    origin.scheme == "http" and is_nil(origin.userinfo) and
      {origin.scheme, origin.host, origin.port} == {target.scheme, target.host, target.port}
  rescue
    _ -> false
  end

  defp forbidden(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, Jason.encode!(%{errors: %{detail: "Origine de la requête refusée."}}))
    |> halt()
  end
end
