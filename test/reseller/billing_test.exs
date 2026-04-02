defmodule Reseller.BillingTest do
  use Reseller.DataCase, async: true

  alias Reseller.Billing

  describe "apply_subscription/2" do
    test "updates plan fields on the user" do
      user = user_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires = DateTime.add(now, 30 * 86_400, :second)

      assert {:ok, updated} =
               Billing.apply_subscription(user, %{
                 plan: "growth",
                 plan_status: "active",
                 plan_period: "monthly",
                 plan_expires_at: expires,
                 ls_subscription_id: "sub_123",
                 ls_customer_id: "cust_456"
               })

      assert updated.plan == "growth"
      assert updated.plan_status == "active"
      assert updated.plan_period == "monthly"
      assert updated.ls_subscription_id == "sub_123"
      assert updated.ls_customer_id == "cust_456"
    end

    test "rejects invalid plan value" do
      user = user_fixture()
      assert {:error, changeset} = Billing.apply_subscription(user, %{plan: "enterprise"})
      assert changeset.errors[:plan] != nil
    end

    test "rejects invalid plan_status value" do
      user = user_fixture()
      assert {:error, changeset} = Billing.apply_subscription(user, %{plan_status: "banana"})
      assert changeset.errors[:plan_status] != nil
    end
  end

  describe "cancel_subscription/1" do
    test "sets plan_status to canceling" do
      user = user_fixture()
      {:ok, user} = Billing.apply_subscription(user, %{plan: "starter", plan_status: "active"})

      assert {:ok, updated} = Billing.cancel_subscription(user)
      assert updated.plan_status == "canceling"
      assert updated.plan == "starter"
    end
  end

  describe "expire_subscription/1" do
    test "resets to free plan with expired status" do
      user = user_fixture()

      {:ok, user} =
        Billing.apply_subscription(user, %{
          plan: "pro",
          plan_status: "active",
          ls_variant_id: "v123"
        })

      assert {:ok, updated} = Billing.expire_subscription(user)
      assert updated.plan == "free"
      assert updated.plan_status == "expired"
      assert updated.plan_period == nil
      assert updated.ls_variant_id == nil
    end
  end

  describe "credit_addon/3" do
    test "adds credits to an empty addon_credits map" do
      user = user_fixture()
      assert {:ok, updated} = Billing.credit_addon(user, "ai_drafts", 100)
      assert updated.addon_credits["ai_drafts"] == 100
    end

    test "accumulates credits on top of existing" do
      user = user_fixture()
      {:ok, user} = Billing.credit_addon(user, "lifestyle", 50)
      assert {:ok, updated} = Billing.credit_addon(user, "lifestyle", 50)
      assert updated.addon_credits["lifestyle"] == 100
    end

    test "does not affect other credit keys" do
      user = user_fixture()
      {:ok, user} = Billing.credit_addon(user, "ai_drafts", 100)
      {:ok, updated} = Billing.credit_addon(user, "lifestyle", 20)
      assert updated.addon_credits["ai_drafts"] == 100
      assert updated.addon_credits["lifestyle"] == 20
    end
  end

  describe "consume_addon_credit/3" do
    test "decrements available credits" do
      user = user_fixture()
      {:ok, user} = Billing.credit_addon(user, "ai_drafts", 10)
      assert {:ok, updated} = Billing.consume_addon_credit(user, "ai_drafts", 3)
      assert updated.addon_credits["ai_drafts"] == 7
    end

    test "returns error when no credits available" do
      user = user_fixture()
      assert {:error, :no_credits} = Billing.consume_addon_credit(user, "ai_drafts", 1)
    end

    test "returns error when credits are insufficient" do
      user = user_fixture()
      {:ok, user} = Billing.credit_addon(user, "lifestyle", 2)
      assert {:error, :no_credits} = Billing.consume_addon_credit(user, "lifestyle", 5)
    end
  end

  describe "subscription_active?/1" do
    test "returns true for active status" do
      assert Billing.subscription_active?(%{plan_status: "active"})
    end

    test "returns true for trialing status" do
      assert Billing.subscription_active?(%{plan_status: "trialing"})
    end

    test "returns false for canceling" do
      refute Billing.subscription_active?(%{plan_status: "canceling"})
    end

    test "returns false for expired" do
      refute Billing.subscription_active?(%{plan_status: "expired"})
    end

    test "returns false for free" do
      refute Billing.subscription_active?(%{plan_status: "free"})
    end
  end

  describe "trial_active?/1" do
    test "returns true when trialing with future end date" do
      user = %{
        plan_status: "trialing",
        trial_ends_at: DateTime.add(DateTime.utc_now(), 3 * 86_400, :second)
      }

      assert Billing.trial_active?(user)
    end

    test "returns false when trial has ended" do
      user = %{
        plan_status: "trialing",
        trial_ends_at: DateTime.add(DateTime.utc_now(), -1, :second)
      }

      refute Billing.trial_active?(user)
    end

    test "returns false when not trialing" do
      user = %{plan_status: "active", trial_ends_at: nil}
      refute Billing.trial_active?(user)
    end
  end

  describe "days_until_expiry/1" do
    test "returns nil when plan_expires_at is nil" do
      assert Billing.days_until_expiry(%{plan_expires_at: nil}) == nil
    end

    test "returns positive days for future expiry" do
      expires = DateTime.add(DateTime.utc_now(), 10 * 86_400, :second)
      days = Billing.days_until_expiry(%{plan_expires_at: expires})
      assert days >= 9
      assert days <= 10
    end

    test "returns 0 when already expired" do
      expires = DateTime.add(DateTime.utc_now(), -86_400, :second)
      assert Billing.days_until_expiry(%{plan_expires_at: expires}) == 0
    end
  end

  describe "get_user_by_ls_subscription_id/1" do
    test "finds a user by subscription id" do
      user = user_fixture()
      {:ok, user} = Billing.apply_subscription(user, %{ls_subscription_id: "sub_abc"})
      assert Billing.get_user_by_ls_subscription_id("sub_abc").id == user.id
    end

    test "returns nil for unknown subscription id" do
      assert Billing.get_user_by_ls_subscription_id("sub_nonexistent") == nil
    end
  end

  describe "users_expiring_within/2" do
    test "returns users expiring within the given days without a reminder" do
      user = user_fixture()
      expires = DateTime.add(DateTime.utc_now(), 5 * 86_400, :second)

      {:ok, _} =
        Billing.apply_subscription(user, %{
          plan: "growth",
          plan_status: "active",
          plan_expires_at: expires
        })

      users = Billing.users_expiring_within(7, :subscription_reminder_7d_sent_at)
      assert Enum.any?(users, &(&1.id == user.id))
    end

    test "excludes users who already received the reminder" do
      user = user_fixture()
      expires = DateTime.add(DateTime.utc_now(), 5 * 86_400, :second)
      sent = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Billing.apply_subscription(user, %{
          plan: "growth",
          plan_status: "active",
          plan_expires_at: expires,
          subscription_reminder_7d_sent_at: sent
        })

      users = Billing.users_expiring_within(7, :subscription_reminder_7d_sent_at)
      refute Enum.any?(users, &(&1.id == user.id))
    end

    test "excludes users not expiring within the window" do
      user = user_fixture()
      expires = DateTime.add(DateTime.utc_now(), 30 * 86_400, :second)

      {:ok, _} =
        Billing.apply_subscription(user, %{
          plan: "growth",
          plan_status: "active",
          plan_expires_at: expires
        })

      users = Billing.users_expiring_within(7, :subscription_reminder_7d_sent_at)
      refute Enum.any?(users, &(&1.id == user.id))
    end

    test "includes trialing users whose trial ends within the window" do
      user = user_fixture()
      trial_ends = DateTime.add(DateTime.utc_now(), 3 * 86_400, :second)

      {:ok, _} =
        Billing.apply_subscription(user, %{
          plan_status: "trialing",
          trial_ends_at: trial_ends
        })

      users = Billing.users_expiring_within(7, :subscription_reminder_7d_sent_at)
      assert Enum.any?(users, &(&1.id == user.id))
    end

    test "excludes trialing users whose trial ends outside the window" do
      user = user_fixture()
      trial_ends = DateTime.add(DateTime.utc_now(), 30 * 86_400, :second)

      {:ok, _} =
        Billing.apply_subscription(user, %{
          plan_status: "trialing",
          trial_ends_at: trial_ends
        })

      users = Billing.users_expiring_within(7, :subscription_reminder_7d_sent_at)
      refute Enum.any?(users, &(&1.id == user.id))
    end
  end

  describe "users_past_expiry/0" do
    test "returns users whose plan_expires_at has passed" do
      user = user_fixture()
      expires = DateTime.add(DateTime.utc_now(), -1, :second)

      {:ok, _} =
        Billing.apply_subscription(user, %{
          plan: "starter",
          plan_status: "active",
          plan_expires_at: expires
        })

      users = Billing.users_past_expiry()
      assert Enum.any?(users, &(&1.id == user.id))
    end

    test "excludes already-expired users" do
      user = user_fixture()
      expires = DateTime.add(DateTime.utc_now(), -1, :second)

      {:ok, _} =
        Billing.apply_subscription(user, %{
          plan: "free",
          plan_status: "expired",
          plan_expires_at: expires
        })

      users = Billing.users_past_expiry()
      refute Enum.any?(users, &(&1.id == user.id))
    end

    test "includes trialing users whose trial_ends_at has passed" do
      user = user_fixture()
      trial_ends = DateTime.add(DateTime.utc_now(), -1, :second)

      {:ok, _} =
        Billing.apply_subscription(user, %{
          plan_status: "trialing",
          trial_ends_at: trial_ends
        })

      users = Billing.users_past_expiry()
      assert Enum.any?(users, &(&1.id == user.id))
    end

    test "excludes trialing users whose trial has not yet ended" do
      user = user_fixture()
      trial_ends = DateTime.add(DateTime.utc_now(), 3 * 86_400, :second)

      {:ok, _} =
        Billing.apply_subscription(user, %{
          plan_status: "trialing",
          trial_ends_at: trial_ends
        })

      users = Billing.users_past_expiry()
      refute Enum.any?(users, &(&1.id == user.id))
    end
  end
end
