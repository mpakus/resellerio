defmodule Reseller.Metrics.UsageSummarizerTest do
  use Reseller.DataCase, async: true

  alias Reseller.Metrics.UsageSummarizer
  alias Reseller.Metrics.UserUsageSummary

  describe "run/2" do
    test "creates a summary for a user with no events" do
      user = user_fixture()

      assert {:ok, summary} = UsageSummarizer.run(user.id, Date.utc_today())
      assert summary.user_id == user.id
      assert summary.gemini_calls == 0
      assert summary.serp_api_calls == 0
      assert summary.photoroom_calls == 0
    end

    test "aggregates events by provider" do
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product)
      gemini_event_fixture(user, product)
      serp_api_event_fixture(user, product)
      photoroom_event_fixture(user, product)

      assert {:ok, summary} = UsageSummarizer.run(user.id, Date.utc_today())

      assert summary.gemini_calls == 2
      assert summary.serp_api_calls == 1
      assert summary.photoroom_calls == 1
      assert Decimal.gt?(summary.total_cost_usd, Decimal.new(0))
    end

    test "upserts when called twice" do
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product)
      {:ok, _} = UsageSummarizer.run(user.id, Date.utc_today())

      gemini_event_fixture(user, product)
      {:ok, summary} = UsageSummarizer.run(user.id, Date.utc_today())

      assert summary.gemini_calls == 2

      count =
        Repo.aggregate(
          from(s in UserUsageSummary, where: s.user_id == ^user.id),
          :count
        )

      assert count == 1
    end

    test "only counts events on the given date" do
      user = user_fixture()
      product = product_fixture(user)

      yesterday = Date.add(Date.utc_today(), -1)
      yesterday_dt = DateTime.new!(yesterday, ~T[12:00:00], "Etc/UTC")

      import Ecto.Changeset

      %Reseller.Metrics.ApiUsageEvent{}
      |> Reseller.Metrics.ApiUsageEvent.create_changeset(%{
        user_id: user.id,
        product_id: product.id,
        provider: "gemini",
        operation: "recognition",
        status: "success"
      })
      |> force_change(:inserted_at, yesterday_dt)
      |> Reseller.Repo.insert!()

      %Reseller.Metrics.ApiUsageEvent{}
      |> Reseller.Metrics.ApiUsageEvent.create_changeset(%{
        user_id: user.id,
        product_id: product.id,
        provider: "serp_api",
        operation: "shopping_matches",
        status: "success"
      })
      |> Reseller.Repo.insert!()

      {:ok, today_summary} = UsageSummarizer.run(user.id, Date.utc_today())
      {:ok, yesterday_summary} = UsageSummarizer.run(user.id, yesterday)

      assert today_summary.gemini_calls == 0
      assert today_summary.serp_api_calls == 1
      assert yesterday_summary.gemini_calls == 1
      assert yesterday_summary.serp_api_calls == 0
    end
  end
end
