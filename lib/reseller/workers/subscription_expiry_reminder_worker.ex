defmodule Reseller.Workers.SubscriptionExpiryReminderWorker do
  @moduledoc """
  Daily worker that sends subscription expiry reminder emails and expires
  subscriptions that have passed their `plan_expires_at`.

  This worker is intended to be scheduled once per day, e.g. via Oban cron
  or a GenServer with `Process.send_after`. It performs three sweeps:

  1. Users expiring within 7 days who haven't received the 7-day reminder yet.
  2. Users expiring within 2 days who haven't received the 2-day reminder yet.
  3. Users whose `plan_expires_at` has already passed — expire and email them.
  """

  require Logger

  alias Reseller.Billing
  alias Reseller.Billing.Emails

  @spec run() :: :ok
  def run do
    Logger.info("[SubscriptionExpiryReminderWorker] Starting sweep")

    send_7_day_reminders()
    send_2_day_reminders()
    expire_past_due_subscriptions()

    Logger.info("[SubscriptionExpiryReminderWorker] Sweep complete")
    :ok
  end

  defp send_7_day_reminders do
    users = Billing.users_expiring_within(7, :subscription_reminder_7d_sent_at)
    Logger.info("[SubscriptionExpiryReminderWorker] 7-day reminders: #{length(users)} users")

    Enum.each(users, fn user ->
      days_left = Billing.days_until_expiry(user)

      case Emails.deliver(Emails.expiring_soon_email(user, days_left)) do
        {:ok, _} ->
          Billing.apply_subscription(user, %{
            subscription_reminder_7d_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })

        {:error, reason} ->
          Logger.error(
            "[SubscriptionExpiryReminderWorker] 7-day email failed user=#{user.id}: #{inspect(reason)}"
          )
      end
    end)
  end

  defp send_2_day_reminders do
    users = Billing.users_expiring_within(2, :subscription_reminder_2d_sent_at)
    Logger.info("[SubscriptionExpiryReminderWorker] 2-day reminders: #{length(users)} users")

    Enum.each(users, fn user ->
      case Emails.deliver(Emails.expiring_urgent_email(user)) do
        {:ok, _} ->
          Billing.apply_subscription(user, %{
            subscription_reminder_2d_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })

        {:error, reason} ->
          Logger.error(
            "[SubscriptionExpiryReminderWorker] 2-day email failed user=#{user.id}: #{inspect(reason)}"
          )
      end
    end)
  end

  defp expire_past_due_subscriptions do
    users = Billing.users_past_expiry()
    Logger.info("[SubscriptionExpiryReminderWorker] Expiring: #{length(users)} users")

    Enum.each(users, fn user ->
      case Billing.expire_subscription(user) do
        {:ok, updated_user} ->
          Emails.deliver(Emails.expired_email(updated_user))

        {:error, reason} ->
          Logger.error(
            "[SubscriptionExpiryReminderWorker] Expire failed user=#{user.id}: #{inspect(reason)}"
          )
      end
    end)
  end
end
