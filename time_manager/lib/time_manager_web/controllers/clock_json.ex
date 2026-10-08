defmodule TimeManagerWeb.ClockJSON do
  alias TimeManager.Clocks.Clock

  def index(%{clocks: clocks}), do: %{data: Enum.map(clocks, &data/1)}
  def show(%{clock: clock}), do: %{data: data(clock)}

  defp data(%Clock{} = clock) do
    clock
    |> Map.take([:id, :time, :status, :kind, :user_id])
    |> Map.put(:time, Calendar.strftime(clock.time, "%Y-%m-%d %H:%M:%S"))
  end
end
