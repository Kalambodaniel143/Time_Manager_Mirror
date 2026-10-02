defmodule TimeManagerWeb.ClockJSON do
  alias TimeManager.Clocks.Clock

  def index(%{clocks: clocks}) do
    %{data: Enum.map(clocks, &data/1)}
  end

  def show(%{clock: clock}) do
    %{data: data(clock)}
  end

  defp data(%Clock{} = clock) do
    %{
      id: clock.id,
      time: clock.time,
      status: clock.status,
      user_id: clock.user_id
    }
  end
end
