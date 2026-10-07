defmodule TimeManagerWeb.RateLimiter do
  @moduledoc """
  Fixed-window counters in an ETS table, for `TimeManagerWeb.Plugs.RateLimit`.

  The counters live in this node's memory: they are lost on restart and not
  shared between several nodes, which is enough for the single server of this
  project. This process owns the table and purges expired windows every minute.
  """
  use GenServer

  @table __MODULE__
  @sweep_every :timer.minutes(1)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Counts one hit for `key`. Returns `:ok` while the window holds at most
  `limit` hits, `{:error, retry_after_seconds}` beyond.
  """
  def hit(key, limit, period_ms) do
    now = System.system_time(:millisecond)
    window = div(now, period_ms)
    expires_at = (window + 1) * period_ms
    count = :ets.update_counter(@table, {key, window}, {2, 1}, {{key, window}, 0, expires_at})

    if count <= limit, do: :ok, else: {:error, max(div(expires_at - now, 1000), 1)}
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    schedule_sweep()
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.system_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_every)
end
