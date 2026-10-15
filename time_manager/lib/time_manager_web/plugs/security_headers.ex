defmodule TimeManagerWeb.Plugs.SecurityHeaders do
  @moduledoc "Protège le transport et évite la mise en cache des réponses privées."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn =
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("referrer-policy", "no-referrer")
      |> put_resp_header("x-frame-options", "DENY")

    if Application.get_env(:time_manager, :require_https, false) do
      if conn.scheme == :https do
        put_resp_header(conn, "strict-transport-security", "max-age=31536000")
      else
        # Destination fixe : un Host fourni par le client ne choisit pas la redirection.
        conn
        |> put_resp_header(
          "location",
          Application.fetch_env!(:time_manager, :public_origin) <> conn.request_path
        )
        |> send_resp(308, "HTTPS required")
        |> halt()
      end
    else
      conn
    end
  end
end
