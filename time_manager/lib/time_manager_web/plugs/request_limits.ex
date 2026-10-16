defmodule TimeManagerWeb.Plugs.RequestLimits do
  @moduledoc "Borne les paramètres avant le traitement métier."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if byte_size(conn.query_string) <= 4096 and valid?(conn.body_params, 0) do
      conn
    else
      conn |> send_resp(413, "Request too large") |> halt()
    end
  end

  defp valid?(_, depth) when depth > 12, do: false
  defp valid?(%Plug.Conn.Unfetched{}, _), do: true
  defp valid?(value, _) when is_binary(value), do: byte_size(value) <= 8192

  defp valid?(value, depth) when is_map(value),
    do:
      map_size(value) <= 100 and
        Enum.all?(value, fn {key, item} -> valid?(key, depth + 1) and valid?(item, depth + 1) end)

  defp valid?(value, depth) when is_list(value),
    do: length(value) <= 200 and Enum.all?(value, &valid?(&1, depth + 1))

  defp valid?(_, _), do: true
end
