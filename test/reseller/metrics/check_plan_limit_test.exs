defmodule Reseller.Metrics.CheckPlanLimitTest do
  use Reseller.DataCase, async: true

  alias Reseller.Billing
  alias Reseller.Metrics

  defp growth_user do
    user = user_fixture()
    {:ok, user} = Billing.apply_subscription(user, %{plan: "growth", plan_status: "active"})
    user
  end

  defp starter_user do
    user = user_fixture()
    {:ok, user} = Billing.apply_subscription(user, %{plan: "starter", plan_status: "active"})
    user
  end

  describe "check_plan_limit/1 for free users" do
    test "always returns :ok for free plan users" do
      user = user_fixture()
      assert :ok = Metrics.check_plan_limit(user)
    end

    test "always returns :ok for nil plan users" do
      assert :ok = Metrics.check_plan_limit(%{plan: nil})
    end
  end

  describe "check_processing_limit/1" do
    test "delegates to check_plan_limit for paid users" do
      user = growth_user()
      assert :ok = Metrics.check_processing_limit(user)
    end

    test "returns :ok for free users with no usage" do
      user = user_fixture()
      assert :ok = Metrics.check_processing_limit(user)
    end

    test "returns limit_exceeded with absolute upgrade_path for paid users over limit" do
      user = starter_user()
      product = product_fixture(user)

      for _ <- 1..51 do
        gemini_event_fixture(user, product, %{operation: "recognition"})
      end

      assert {:error, :limit_exceeded, details} = Metrics.check_processing_limit(user)
      assert String.starts_with?(details.upgrade_path, "https://")
    end
  end

  describe "check_plan_limit/1 for paid users" do
    test "returns :ok when usage is under limit" do
      user = growth_user()
      assert :ok = Metrics.check_plan_limit(user)
    end

    test "returns limit_exceeded when ai_drafts exhausted" do
      user = starter_user()
      product = product_fixture(user)

      for _ <- 1..51 do
        gemini_event_fixture(user, product, %{operation: "recognition"})
      end

      assert {:error, :limit_exceeded, details} = Metrics.check_plan_limit(user)
      assert details.operation == :ai_drafts
      assert details.used >= 51
      assert details.limit == 50
    end

    test "returns limit_exceeded when background_removals exhausted" do
      user = starter_user()
      product = product_fixture(user)

      for _ <- 1..151 do
        photoroom_event_fixture(user, product)
      end

      assert {:error, :limit_exceeded, details} = Metrics.check_plan_limit(user)
      assert details.operation == :background_removals
    end

    test "returns limit_exceeded when lifestyle images exhausted" do
      user = starter_user()
      product = product_fixture(user)

      for _ <- 1..151 do
        gemini_event_fixture(user, product, %{operation: "lifestyle_image"})
      end

      assert {:error, :limit_exceeded, details} = Metrics.check_plan_limit(user)
      assert details.operation == :lifestyle
    end

    test "returns :ok when addon_credits cover the overage" do
      user = starter_user()
      {:ok, user} = Billing.credit_addon(user, "ai_drafts", 100)
      product = product_fixture(user)

      for _ <- 1..51 do
        gemini_event_fixture(user, product, %{operation: "recognition"})
      end

      assert :ok = Metrics.check_plan_limit(user)
    end

    test "returns limit_exceeded when both plan and addon credits are exhausted" do
      user = starter_user()
      {:ok, user} = Billing.credit_addon(user, "ai_drafts", 5)
      product = product_fixture(user)

      for _ <- 1..60 do
        gemini_event_fixture(user, product, %{operation: "recognition"})
      end

      assert {:error, :limit_exceeded, details} = Metrics.check_plan_limit(user)
      assert details.operation == :ai_drafts
      assert details.addon_credits == 5
    end
  end

  describe "monthly_usage_for_user/2" do
    test "returns zero map for user with no events" do
      user = user_fixture()
      usage = Metrics.monthly_usage_for_user(user.id)
      assert usage.ai_drafts == 0
      assert usage.background_removals == 0
      assert usage.lifestyle == 0
      assert usage.price_research == 0
    end

    test "counts gemini recognition events as ai_drafts" do
      user = user_fixture()
      product = product_fixture(user)
      gemini_event_fixture(user, product, %{operation: "recognition"})
      gemini_event_fixture(user, product, %{operation: "description"})
      gemini_event_fixture(user, product, %{operation: "reconciliation"})

      usage = Metrics.monthly_usage_for_user(user.id)
      assert usage.ai_drafts == 3
    end

    test "counts photoroom events as background_removals" do
      user = user_fixture()
      product = product_fixture(user)
      photoroom_event_fixture(user, product)
      photoroom_event_fixture(user, product)

      usage = Metrics.monthly_usage_for_user(user.id)
      assert usage.background_removals == 2
    end

    test "counts lifestyle_image gemini events as lifestyle" do
      user = user_fixture()
      product = product_fixture(user)
      gemini_event_fixture(user, product, %{operation: "lifestyle_image"})

      usage = Metrics.monthly_usage_for_user(user.id)
      assert usage.lifestyle == 1
    end

    test "counts serp_api and price_research gemini events as price_research" do
      user = user_fixture()
      product = product_fixture(user)
      serp_api_event_fixture(user, product)
      gemini_event_fixture(user, product, %{operation: "price_research"})
      gemini_event_fixture(user, product, %{operation: "price_research_grounded"})

      usage = Metrics.monthly_usage_for_user(user.id)
      assert usage.price_research == 3
    end

    test "does not count events from other users" do
      user = user_fixture()
      other = user_fixture()
      product = product_fixture(other)
      gemini_event_fixture(other, product, %{operation: "recognition"})

      usage = Metrics.monthly_usage_for_user(user.id)
      assert usage.ai_drafts == 0
    end

    test "does not count failed events" do
      user = user_fixture()
      product = product_fixture(user)
      gemini_event_fixture(user, product, %{operation: "recognition", status: "error"})

      usage = Metrics.monthly_usage_for_user(user.id)
      assert usage.ai_drafts == 0
    end
  end
end
