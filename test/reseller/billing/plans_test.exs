defmodule Reseller.Billing.PlansTest do
  use ExUnit.Case, async: true

  alias Reseller.Billing.Plans

  describe "limits_for/1" do
    test "returns starter limits" do
      limits = Plans.limits_for("starter")
      assert limits.ai_drafts == 50
      assert limits.background_removals == 150
      assert limits.lifestyle == 150
      assert limits.price_research == 50
    end

    test "returns growth limits" do
      limits = Plans.limits_for("growth")
      assert limits.ai_drafts == 250
      assert limits.background_removals == 750
      assert limits.lifestyle == 750
      assert limits.price_research == 250
    end

    test "returns pro limits" do
      limits = Plans.limits_for("pro")
      assert limits.ai_drafts == 1000
      assert limits.background_removals == 3000
      assert limits.lifestyle == 3000
      assert limits.price_research == 1000
    end

    test "falls back to free for unknown plan" do
      limits = Plans.limits_for("unknown_plan")
      assert limits.ai_drafts == 5
    end

    test "returns free limits" do
      limits = Plans.limits_for("free")
      assert limits.ai_drafts == 5
      assert limits.background_removals == 15
      assert limits.lifestyle == 0
      assert limits.price_research == 5
    end
  end

  describe "limits_for_user/1" do
    test "reads plan from user struct" do
      user = %{plan: "growth"}
      assert Plans.limits_for_user(user) == Plans.limits_for("growth")
    end

    test "falls back to free for nil plan" do
      user = %{plan: nil}
      assert Plans.limits_for_user(user) == Plans.limits_for("free")
    end
  end

  describe "all/0" do
    test "returns 4 plans in ascending price order" do
      plans = Plans.all()
      assert length(plans) == 4
      keys = Enum.map(plans, & &1.key)
      assert keys == ["free", "starter", "growth", "pro"]
    end

    test "each plan has required fields" do
      for plan <- Plans.all() do
        assert is_binary(plan.key)
        assert is_binary(plan.name)
        assert is_integer(plan.ai_drafts)
      end
    end
  end

  describe "plan_info/1" do
    test "returns map with name and monthly_usd for known plan" do
      info = Plans.plan_info("starter")
      assert info.name == "Starter"
      assert info.monthly_usd == 19
    end

    test "returns nil for unknown plan" do
      assert Plans.plan_info("unknown") == nil
    end
  end

  describe "valid_plans/0" do
    test "includes all expected plans" do
      plans = Plans.valid_plans()
      assert "free" in plans
      assert "starter" in plans
      assert "growth" in plans
      assert "pro" in plans
    end
  end
end
