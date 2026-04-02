defmodule Reseller.Workers.ExpiryScheduler do
  @moduledoc """
  GenServer that runs `SubscriptionExpiryReminderWorker.run/0` once per day at midnight UTC.

  On startup it calculates the milliseconds until the next midnight UTC and
  schedules the first run. Subsequent runs are scheduled every 24 hours.
  """

  use GenServer

  require Logger

  alias Reseller.Workers.SubscriptionExpiryReminderWorker

  @one_day_ms 24 * 60 * 60 * 1_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    ms = ms_until_next_midnight()
    Logger.info("[ExpiryScheduler] First run scheduled in #{div(ms, 60_000)} minutes")
    {:ok, %{}, {:continue, {:schedule, ms}}}
  end

  @impl true
  def handle_continue({:schedule, ms}, state) do
    Process.send_after(self(), :run, ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:run, state) do
    Logger.info("[ExpiryScheduler] Triggering SubscriptionExpiryReminderWorker")

    Task.Supervisor.start_child(Reseller.Workers.TaskSupervisor, fn ->
      SubscriptionExpiryReminderWorker.run()
    end)

    Process.send_after(self(), :run, @one_day_ms)
    {:noreply, state}
  end

  defp ms_until_next_midnight do
    now = DateTime.utc_now()
    today_midnight = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")
    next_midnight = DateTime.add(today_midnight, 1, :day)
    max(0, DateTime.diff(next_midnight, now, :millisecond))
  end
end
