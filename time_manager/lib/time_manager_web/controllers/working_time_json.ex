defmodule TimeManagerWeb.WorkingTimeJSON do
  alias TimeManager.WorkingTimes.WorkingTime

  def index(%{working_times: working_times}) do
    %{data: for(working_time <- working_times, do: data(working_time))}
  end

  def show(%{working_time: working_time}) do
    %{data: data(working_time)}
  end

  defp data(%WorkingTime{} = working_time) do
    %{
      id: working_time.id,
      start: format_datetime(working_time.start),
      end: format_datetime(working_time.end),
      user_id: working_time.user_id
    }
  end

  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
end
