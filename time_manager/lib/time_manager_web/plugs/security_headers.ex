defmodule TimeManagerWeb.Plugs.SecurityHeaders do
  @moduledoc "Ajoute les en-têtes de protection communs aux réponses."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("x-frame-options", "DENY")
  end
end
