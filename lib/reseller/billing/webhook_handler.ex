defmodule Reseller.Billing.WebhookHandler do
  @moduledoc """
  Processes incoming LemonSqueezy webhook events and applies the resulting
  state changes to the relevant user's subscription.

  Each handle/2 clause is idempotent — re-processing the same event payload
  with the same data is safe.
  """

  require Logger

  alias Reseller.Accounts
  alias Reseller.Billing
  alias Reseller.Billing.Emails
  alias Reseller.Billing.Plans

  @addon_variant_keys %{
    "addon_ai_drafts" => {"ai_drafts", 100},
    "addon_lifestyle" => {"lifestyle", 50},
    "addon_bg_removals" => {"background_removals", 100},
    "addon_extra_seat" => {"extra_seat", 1}
  }

  @doc """
  Dispatches a parsed LemonSqueezy webhook event to the appropriate handler.
  Returns `:ok` or `{:error, reason}`.
  """
  @spec handle(String.t(), map()) :: :ok | {:error, term()}
  def handle(event_name, payload) do
    Logger.info("[Billing.Webhook] event=#{event_name}")

    case event_name do
      "subscription_created" ->
        handle_subscription_created(payload)

      "subscription_updated" ->
        handle_subscription_updated(payload)

      "subscription_renewed" ->
        handle_subscription_renewed(payload)

      "subscription_cancelled" ->
        handle_subscription_cancelled(payload)

      "subscription_expired" ->
        handle_subscription_expired(payload)

      "subscription_payment_failed" ->
        handle_subscription_payment_failed(payload)

      "order_created" ->
        handle_order_created(payload)

      other ->
        Logger.info("[Billing.Webhook] Unhandled event: #{other}")
        :ok
    end
  end

  defp handle_subscription_created(payload) do
    with {:ok, user} <- find_or_associate_user(payload),
         {:ok, attrs} <- build_subscription_attrs(payload),
         {:ok, updated_user} <- Billing.apply_subscription(user, attrs) do
      Logger.info(
        "[Billing.Webhook] subscription_created user_id=#{user.id} plan=#{attrs[:plan]}"
      )

      plan_name = Plans.plan_info(attrs[:plan] || "free")[:name] || "Starter"
      Emails.deliver(Emails.welcome_email(updated_user, plan_name))
      :ok
    else
      {:error, reason} ->
        Logger.error("[Billing.Webhook] subscription_created failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_subscription_updated(payload) do
    with {:ok, user} <- find_user_by_subscription(payload),
         {:ok, attrs} <- build_subscription_attrs(payload),
         {:ok, _user} <- Billing.apply_subscription(user, attrs) do
      :ok
    else
      {:error, reason} ->
        Logger.error("[Billing.Webhook] subscription_updated failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_subscription_renewed(payload) do
    with {:ok, user} <- find_user_by_subscription(payload),
         {:ok, attrs} <- build_subscription_attrs(payload),
         {:ok, updated_user} <-
           Billing.apply_subscription(
             user,
             Map.merge(attrs, %{
               subscription_reminder_7d_sent_at: nil,
               subscription_reminder_2d_sent_at: nil
             })
           ) do
      plan_name = Plans.plan_info(updated_user.plan || "free")[:name] || "Plan"
      Emails.deliver(Emails.renewal_confirmation_email(updated_user, plan_name))
      :ok
    else
      {:error, reason} ->
        Logger.error("[Billing.Webhook] subscription_renewed failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_subscription_cancelled(payload) do
    with {:ok, user} <- find_user_by_subscription(payload),
         ends_at <- get_in(payload, ["data", "attributes", "ends_at"]) |> parse_datetime(),
         {:ok, _user} <-
           Billing.apply_subscription(user, %{
             plan_status: "canceling",
             plan_expires_at: ends_at
           }) do
      :ok
    else
      {:error, reason} ->
        Logger.error("[Billing.Webhook] subscription_cancelled failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_subscription_expired(payload) do
    with {:ok, user} <- find_user_by_subscription(payload),
         {:ok, updated_user} <- Billing.expire_subscription(user) do
      Emails.deliver(Emails.expired_email(updated_user))
      :ok
    else
      {:error, reason} ->
        Logger.error("[Billing.Webhook] subscription_expired failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_subscription_payment_failed(payload) do
    with {:ok, user} <- find_user_by_subscription(payload),
         {:ok, updated_user} <- Billing.apply_subscription(user, %{plan_status: "past_due"}) do
      Emails.deliver(Emails.payment_failed_email(updated_user))
      :ok
    else
      {:error, reason} ->
        Logger.error("[Billing.Webhook] subscription_payment_failed failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_order_created(payload) do
    attrs = get_in(payload, ["data", "attributes"]) || %{}

    first_item =
      get_in(payload, ["data", "relationships", "order-items", "data"])
      |> List.wrap()
      |> List.first()

    variant_key = resolve_variant_key(get_in(first_item || %{}, ["id"]))

    case Map.get(@addon_variant_keys, variant_key) do
      nil ->
        Logger.info("[Billing.Webhook] order_created: not an addon variant, skipping")
        :ok

      {credit_key, quantity} ->
        email = get_in(attrs, ["user_email"]) || get_in(attrs, ["email"])
        user_id = get_in(attrs, ["custom_data", "user_id"])

        with {:ok, user} <- find_user_for_order(user_id, email),
             {:ok, _user} <- Billing.credit_addon(user, credit_key, quantity) do
          Logger.info(
            "[Billing.Webhook] order_created addon=#{credit_key} qty=#{quantity} user_id=#{user.id}"
          )

          :ok
        else
          {:error, reason} ->
            Logger.error(
              "[Billing.Webhook] order_created addon credit failed: #{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  defp find_user_by_subscription(payload) do
    ls_subscription_id = get_in(payload, ["data", "id"])

    case ls_subscription_id &&
           Billing.get_user_by_ls_subscription_id(to_string(ls_subscription_id)) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp find_or_associate_user(payload) do
    attrs = get_in(payload, ["data", "attributes"]) || %{}
    ls_subscription_id = to_string(get_in(payload, ["data", "id"]) || "")
    user_id = get_in(attrs, ["custom_data", "user_id"])
    email = get_in(attrs, ["user_email"])

    result =
      with nil <-
             ls_subscription_id != "" &&
               Billing.get_user_by_ls_subscription_id(ls_subscription_id),
           nil <- user_id && Accounts.get_user(user_id),
           nil <- email && Accounts.get_user_by_email(email) do
        nil
      else
        user -> user
      end

    case result do
      nil ->
        Logger.error("[Billing.Webhook] Could not find user for subscription payload")
        {:error, :user_not_found}

      user ->
        {:ok, user}
    end
  end

  defp find_user_for_order(user_id, email) do
    result =
      with nil <- user_id && Accounts.get_user(user_id),
           nil <- email && Accounts.get_user_by_email(email) do
        nil
      else
        user -> user
      end

    case result do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp build_subscription_attrs(payload) do
    attrs = get_in(payload, ["data", "attributes"]) || %{}
    ls_subscription_id = to_string(get_in(payload, ["data", "id"]) || "")
    ls_variant_id = to_string(get_in(attrs, ["variant_id"]) || "")
    ls_customer_id = to_string(get_in(attrs, ["customer_id"]) || "")
    status = get_in(attrs, ["status"])
    renews_at = get_in(attrs, ["renews_at"]) |> parse_datetime()
    trial_ends_at = get_in(attrs, ["trial_ends_at"]) |> parse_datetime()

    plan = resolve_plan_from_variant(ls_variant_id)
    plan_period = resolve_period_from_variant(ls_variant_id)
    plan_status = normalize_ls_status(status)

    {:ok,
     %{
       plan: plan,
       plan_status: plan_status,
       plan_period: plan_period,
       plan_expires_at: renews_at,
       trial_ends_at: trial_ends_at,
       ls_subscription_id: ls_subscription_id,
       ls_customer_id: ls_customer_id,
       ls_variant_id: ls_variant_id
     }}
  end

  defp resolve_plan_from_variant(variant_id) do
    variants = Application.get_env(:reseller, Reseller.Billing.LemonSqueezy, [])[:variants] || %{}

    Enum.find_value(variants, "free", fn {key, val} ->
      if to_string(val) == to_string(variant_id) do
        cond do
          String.starts_with?(key, "starter") -> "starter"
          String.starts_with?(key, "growth") -> "growth"
          String.starts_with?(key, "pro") -> "pro"
          true -> nil
        end
      end
    end)
  end

  defp resolve_period_from_variant(variant_id) do
    variants = Application.get_env(:reseller, Reseller.Billing.LemonSqueezy, [])[:variants] || %{}

    Enum.find_value(variants, nil, fn {key, val} ->
      if to_string(val) == to_string(variant_id) do
        cond do
          String.ends_with?(key, "_annual") -> "annual"
          String.ends_with?(key, "_monthly") -> "monthly"
          true -> nil
        end
      end
    end)
  end

  defp resolve_variant_key(variant_id) when is_nil(variant_id), do: nil

  defp resolve_variant_key(variant_id) do
    variants = Application.get_env(:reseller, Reseller.Billing.LemonSqueezy, [])[:variants] || %{}

    Enum.find_value(variants, nil, fn {key, val} ->
      if to_string(val) == to_string(variant_id), do: key
    end)
  end

  defp normalize_ls_status("active"), do: "active"
  defp normalize_ls_status("on_trial"), do: "trialing"
  defp normalize_ls_status("paused"), do: "canceling"
  defp normalize_ls_status("past_due"), do: "past_due"
  defp normalize_ls_status("unpaid"), do: "past_due"
  defp normalize_ls_status("cancelled"), do: "canceling"
  defp normalize_ls_status("expired"), do: "expired"
  defp normalize_ls_status(_), do: "active"

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end
end
