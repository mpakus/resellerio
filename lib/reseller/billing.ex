defmodule Reseller.Billing do
  @moduledoc """
  Manages subscription state for users.

  This context is the single source of truth for plan assignment, status transitions,
  add-on credit management, and expiry helpers. It is driven primarily by
  LemonSqueezy webhook events processed in `Reseller.Billing.WebhookHandler`.
  """

  import Ecto.Query, warn: false

  alias Reseller.Accounts.User
  alias Reseller.Repo

  @doc """
  Applies a subscription update from a LemonSqueezy webhook payload.
  Accepts a map of fields to set on the user (plan, plan_status, etc.).
  """
  @spec apply_subscription(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def apply_subscription(%User{} = user, attrs) do
    user
    |> User.subscription_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks a subscription as canceling. Access continues until `plan_expires_at`.
  """
  @spec cancel_subscription(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def cancel_subscription(%User{} = user) do
    apply_subscription(user, %{plan_status: "canceling"})
  end

  @doc """
  Expires a subscription, reverting the user to the free plan.
  """
  @spec expire_subscription(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def expire_subscription(%User{} = user) do
    apply_subscription(user, %{
      plan: "free",
      plan_status: "expired",
      plan_period: nil,
      ls_variant_id: nil
    })
  end

  @doc """
  Credits an add-on pack to the user's `addon_credits` map.
  The addon_key should be one of: "ai_drafts", "background_removals", "lifestyle", "price_research".
  Credits accumulate and do not expire.
  """
  @spec credit_addon(User.t(), String.t(), pos_integer()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def credit_addon(%User{} = user, addon_key, quantity)
      when is_integer(quantity) and quantity > 0 do
    current = user.addon_credits || %{}
    existing = Map.get(current, addon_key, 0)
    updated = Map.put(current, addon_key, existing + quantity)
    apply_subscription(user, %{addon_credits: updated})
  end

  @doc """
  Consumes add-on credits for a given key. Returns `{:ok, updated_user}` if credits
  were available and consumed, or `{:error, :no_credits}` otherwise.
  """
  @spec consume_addon_credit(User.t(), String.t(), pos_integer()) ::
          {:ok, User.t()} | {:error, :no_credits}
  def consume_addon_credit(%User{} = user, addon_key, quantity \\ 1) do
    current = user.addon_credits || %{}
    available = Map.get(current, addon_key, 0)

    if available >= quantity do
      updated = Map.put(current, addon_key, available - quantity)

      case apply_subscription(user, %{addon_credits: updated}) do
        {:ok, user} -> {:ok, user}
        {:error, _} -> {:error, :no_credits}
      end
    else
      {:error, :no_credits}
    end
  end

  @doc """
  Returns true if the user has an active or trialing subscription.
  """
  @spec subscription_active?(map()) :: boolean()
  def subscription_active?(%{plan_status: status}), do: status in ~w(active trialing)

  @doc """
  Returns true if the user is in a free trial period.
  """
  @spec trial_active?(map()) :: boolean()
  def trial_active?(%{plan_status: "trialing", trial_ends_at: ends_at})
      when not is_nil(ends_at) do
    DateTime.compare(ends_at, DateTime.utc_now()) == :gt
  end

  def trial_active?(_), do: false

  @doc """
  Returns the number of days until the subscription expires, or nil if not expiring.
  Returns 0 if already expired.
  """
  @spec days_until_expiry(map()) :: non_neg_integer() | nil
  def days_until_expiry(%{plan_expires_at: nil}), do: nil

  def days_until_expiry(%{plan_expires_at: expires_at}) do
    now = DateTime.utc_now()
    diff = DateTime.diff(expires_at, now, :second)
    max(0, div(diff, 86_400))
  end

  @doc """
  Finds a user by their LemonSqueezy subscription ID.
  """
  @spec get_user_by_ls_subscription_id(String.t()) :: User.t() | nil
  def get_user_by_ls_subscription_id(ls_subscription_id) do
    Repo.get_by(User, ls_subscription_id: ls_subscription_id)
  end

  @doc """
  Finds a user by their LemonSqueezy customer ID.
  """
  @spec get_user_by_ls_customer_id(String.t()) :: User.t() | nil
  def get_user_by_ls_customer_id(ls_customer_id) do
    Repo.get_by(User, ls_customer_id: ls_customer_id)
  end

  @doc """
  Returns users whose subscriptions expire within the given number of days
  and who have not yet received a reminder at the given sent_at field.

  Covers both paid subscribers (checking `plan_expires_at`) and trial users
  (checking `trial_ends_at`).
  """
  @spec users_expiring_within(pos_integer(), atom()) :: [User.t()]
  def users_expiring_within(days, reminder_field) do
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, days * 86_400, :second)

    paid_query =
      from(u in User,
        where: u.plan_status in ["active", "canceling"],
        where: not is_nil(u.plan_expires_at),
        where: u.plan_expires_at <= ^cutoff,
        where: u.plan_expires_at > ^now,
        where: is_nil(field(u, ^reminder_field))
      )

    trial_query =
      from(u in User,
        where: u.plan_status == "trialing",
        where: not is_nil(u.trial_ends_at),
        where: u.trial_ends_at <= ^cutoff,
        where: u.trial_ends_at > ^now,
        where: is_nil(field(u, ^reminder_field))
      )

    Repo.all(paid_query) ++ Repo.all(trial_query)
  end

  @doc """
  Returns users whose subscriptions have passed their `plan_expires_at`
  and whose status is not yet "expired". Also includes trialing users
  whose `trial_ends_at` has passed.
  """
  @spec users_past_expiry() :: [User.t()]
  def users_past_expiry do
    now = DateTime.utc_now()

    paid_query =
      from(u in User,
        where: u.plan_status in ["active", "canceling", "past_due"],
        where: not is_nil(u.plan_expires_at),
        where: u.plan_expires_at < ^now
      )

    trial_query =
      from(u in User,
        where: u.plan_status == "trialing",
        where: not is_nil(u.trial_ends_at),
        where: u.trial_ends_at < ^now
      )

    Repo.all(paid_query) ++ Repo.all(trial_query)
  end
end
