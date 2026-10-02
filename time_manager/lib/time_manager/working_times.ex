defmodule TimeManager.WorkingTimes do
  import Ecto.Query, warn: false
  alias TimeManager.Repo

  alias TimeManager.Accounts.User
  alias TimeManager.WorkingTimes.WorkingTime

  def list_working_times(user_id, filters \\ %{}) do
    with {:ok, user_id} <- cast_id(user_id),
         :ok <- ensure_user_exists(user_id),
         {:ok, start} <- cast_filter(filters, "start"),
         {:ok, finish} <- cast_filter(filters, "end") do
      working_times =
        WorkingTime
        |> where([w], w.user_id == ^user_id)
        |> filter_start(start)
        |> filter_end(finish)
        |> order_by([w], asc: w.start)
        |> Repo.all()

      {:ok, working_times}
    end
  end

  def get_working_time(user_id, id) do
    with {:ok, user_id} <- cast_id(user_id),
         {:ok, id} <- cast_id(id) do
      WorkingTime
      |> Repo.get_by(id: id, user_id: user_id)
      |> found_or_not_found()
    end
  end

  def get_working_time(id) do
    with {:ok, id} <- cast_id(id) do
      WorkingTime
      |> Repo.get(id)
      |> found_or_not_found()
    end
  end

  def create_working_time(user_id, attrs) do
    with {:ok, user_id} <- cast_id(user_id),
         :ok <- ensure_user_exists(user_id) do
      %WorkingTime{user_id: user_id}
      |> WorkingTime.changeset(attrs)
      |> Repo.insert()
    end
  end

  def update_working_time(%WorkingTime{} = working_time, attrs) do
    working_time
    |> WorkingTime.changeset(attrs)
    |> Repo.update()
  end

  def delete_working_time(%WorkingTime{} = working_time) do
    Repo.delete(working_time)
  end

  defp filter_start(query, nil), do: query
  defp filter_start(query, start), do: where(query, [w], w.start >= ^start)

  defp filter_end(query, nil), do: query
  defp filter_end(query, finish), do: where(query, [w], w.end <= ^finish)

  defp cast_filter(filters, key) do
    case Map.get(filters, key) do
      nil -> {:ok, nil}
      "" -> {:ok, nil}
      value -> with :error <- Ecto.Type.cast(:utc_datetime, value), do: {:error, :bad_request}
    end
  end

  defp ensure_user_exists(user_id) do
    if Repo.exists?(from u in User, where: u.id == ^user_id), do: :ok, else: {:error, :not_found}
  end

  defp cast_id(id) do
    with :error <- Ecto.Type.cast(:id, id), do: {:error, :not_found}
  end

  defp found_or_not_found(nil), do: {:error, :not_found}
  defp found_or_not_found(working_time), do: {:ok, working_time}
end
