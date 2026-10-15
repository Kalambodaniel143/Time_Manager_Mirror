defmodule TimeManager.Pagination do
  @moduledoc "Pagination par identifiant, sans OFFSET coûteux ni taille libre."
  import Ecto.Query

  def parse(params) do
    with {:ok, limit} <- number(Map.get(params, "limit", "100"), 1, 200),
         {:ok, cursor} <- number(Map.get(params, "cursor", "0"), 0, 9_223_372_036_854_775_807) do
      {:ok, %{limit: limit, cursor: cursor}}
    end
  end

  def apply(query, %{limit: size, cursor: cursor}) do
    query
    |> exclude(:order_by)
    |> where([row], row.id > ^cursor)
    |> order_by([row], asc: row.id)
    |> limit(^size)
  end

  def optional(query, nil), do: query
  def optional(query, page), do: __MODULE__.apply(query, page)

  def header(conn, rows, %{limit: size}) when length(rows) == size,
    do: Plug.Conn.put_resp_header(conn, "x-next-cursor", to_string(List.last(rows).id))

  def header(conn, _, _), do: conn

  defp number(value, minimum, maximum) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number >= minimum and number <= maximum -> {:ok, number}
      _ -> {:error, :bad_request}
    end
  end

  defp number(_, _, _), do: {:error, :bad_request}
end
