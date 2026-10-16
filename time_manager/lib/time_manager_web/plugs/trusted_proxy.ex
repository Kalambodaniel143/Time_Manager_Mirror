defmodule TimeManagerWeb.Plugs.TrustedProxy do
  @moduledoc "N'accepte les informations réseau que du proxy explicitement déclaré."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    trusted = Application.get_env(:time_manager, :trusted_proxy_ip)

    if trusted && normalize_ip(conn.remote_ip) == normalize_ip(trusted) do
      with [address] <- get_req_header(conn, "x-real-ip"),
           {:ok, ip} <- :inet.parse_address(String.to_charlist(address)),
           ["http"] <- get_req_header(conn, "x-forwarded-proto") do
        %{
          conn
          | remote_ip: normalize_ip(ip),
            scheme: :http
        }
      else
        _ -> conn |> send_resp(400, "Invalid proxy headers") |> halt()
      end
    else
      conn
    end
  end

  # Une socket IPv6 peut représenter un client IPv4 sous la forme ::ffff:a.b.c.d.
  defp normalize_ip({0, 0, 0, 0, 0, 65535, high, low}),
    do: {div(high, 256), rem(high, 256), div(low, 256), rem(low, 256)}

  defp normalize_ip(ip), do: ip
end
