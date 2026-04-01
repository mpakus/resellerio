defmodule Reseller.MetricsTest do
  use Reseller.DataCase, async: true

  alias Reseller.Metrics
  alias Reseller.Metrics.ApiUsageEvent
  alias Reseller.Metrics.UserUsageSummary

  describe "record_event/1" do
    test "inserts a valid event and estimates cost" do
      user = user_fixture()
      product = product_fixture(user)

      assert {:ok, event} =
               Metrics.record_event(%{
                 user_id: user.id,
                 product_id: product.id,
                 provider: :gemini,
                 operation: :recognition,
                 model: "gemini-2.5-flash",
                 status: "success",
                 http_status: 200,
                 input_tokens: 1000,
                 output_tokens: 200,
                 total_tokens: 1200,
                 image_count: 2,
                 duration_ms: 300
               })

      assert event.provider == "gemini"
      assert event.operation == "recognition"
      assert event.user_id == user.id
      assert event.product_id == product.id
      assert event.status == "success"
      assert Decimal.gt?(event.cost_usd, Decimal.new(0))
    end

    test "records a serp_api event" do
      user = user_fixture()

      assert {:ok, event} =
               Metrics.record_event(%{
                 user_id: user.id,
                 provider: :serp_api,
                 operation: :shopping_matches,
                 status: "success",
                 http_status: 200
               })

      assert event.provider == "serp_api"
      assert Decimal.eq?(event.cost_usd, Decimal.new("0.0025"))
    end

    test "records a photoroom event" do
      user = user_fixture()

      assert {:ok, event} =
               Metrics.record_event(%{
                 user_id: user.id,
                 provider: :photoroom,
                 operation: :process_image,
                 status: "success",
                 image_count: 1
               })

      assert event.provider == "photoroom"
      assert Decimal.eq?(event.cost_usd, Decimal.new("0.01"))
    end

    test "records an error event" do
      assert {:ok, event} =
               Metrics.record_event(%{
                 provider: :gemini,
                 operation: :recognition,
                 status: "error",
                 http_status: 429,
                 error_code: "RESOURCE_EXHAUSTED"
               })

      assert event.status == "error"
      assert event.error_code == "RESOURCE_EXHAUSTED"
    end

    test "returns changeset error for missing required fields" do
      assert {:error, changeset} = Metrics.record_event(%{})
      assert %{provider: [_], operation: [_], status: [_]} = errors_on(changeset)
    end

    test "returns changeset error for invalid provider" do
      assert {:error, changeset} =
               Metrics.record_event(%{
                 provider: "invalid_provider",
                 operation: "recognition",
                 status: "success"
               })

      assert %{provider: [_]} = errors_on(changeset)
    end
  end

  describe "record_event_safe/1" do
    test "returns :ok on success" do
      result =
        Metrics.record_event_safe(%{
          provider: :gemini,
          operation: :description,
          status: "success"
        })

      assert result == :ok
    end

    test "returns :ok on failure (does not raise)" do
      result = Metrics.record_event_safe(%{})
      assert result == :ok
    end
  end

  describe "usage_for_user/2" do
    test "returns aggregated totals for a user" do
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product)
      gemini_event_fixture(user, product, %{total_tokens: 500, cost_usd: Decimal.new("0.00010")})
      serp_api_event_fixture(user, product)

      since = DateTime.add(DateTime.utc_now(), -3600, :second)
      result = Metrics.usage_for_user(user.id, since: since)

      assert result.gemini_calls == 2
      assert result.serp_api_calls == 1
      assert Decimal.gt?(result.total_cost_usd, Decimal.new(0))
    end

    test "returns zeros for a user with no events" do
      user = user_fixture()
      result = Metrics.usage_for_user(user.id)

      assert result.gemini_calls == 0
      assert result.serp_api_calls == 0
      assert result.photoroom_calls == 0
      assert Decimal.eq?(result.total_cost_usd, Decimal.new(0))
    end

    test "does not include events from another user" do
      user1 = user_fixture()
      user2 = user_fixture()
      product1 = product_fixture(user1)
      product2 = product_fixture(user2)

      gemini_event_fixture(user1, product1)
      gemini_event_fixture(user2, product2)

      since = DateTime.add(DateTime.utc_now(), -3600, :second)
      result = Metrics.usage_for_user(user1.id, since: since)

      assert result.gemini_calls == 1
    end
  end

  describe "usage_for_product/1" do
    test "returns per-operation breakdown" do
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product, %{operation: "recognition"})
      gemini_event_fixture(user, product, %{operation: "description"})
      serp_api_event_fixture(user, product)

      result = Metrics.usage_for_product(product.id)

      assert result.total_calls == 3
      assert length(result.by_operation) == 3
      assert Decimal.gt?(result.total_cost_usd, Decimal.new(0))
    end

    test "returns zeros for product with no events" do
      user = user_fixture()
      product = product_fixture(user)

      result = Metrics.usage_for_product(product.id)

      assert result.total_calls == 0
      assert result.by_operation == []
    end
  end

  describe "list_events/1" do
    test "returns events filtered by user_id" do
      user1 = user_fixture()
      user2 = user_fixture()
      product1 = product_fixture(user1)
      product2 = product_fixture(user2)

      gemini_event_fixture(user1, product1)
      gemini_event_fixture(user2, product2)

      events = Metrics.list_events(user_id: user1.id)
      assert length(events) == 1
      assert hd(events).user_id == user1.id
    end

    test "returns events filtered by provider" do
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product)
      serp_api_event_fixture(user, product)

      events = Metrics.list_events(provider: "gemini")
      assert Enum.all?(events, &(&1.provider == "gemini"))
    end

    test "respects limit" do
      user = user_fixture()
      product = product_fixture(user)

      for _ <- 1..5, do: gemini_event_fixture(user, product)

      events = Metrics.list_events(user_id: user.id, limit: 3)
      assert length(events) == 3
    end
  end

  describe "check_limit/1" do
    test "returns :ok when user has no events today" do
      user = user_fixture()
      assert :ok = Metrics.check_limit(user.id)
    end

    test "returns :ok when user is under limits" do
      user = user_fixture()
      product = product_fixture(user)
      gemini_event_fixture(user, product)

      assert :ok = Metrics.check_limit(user.id)
    end

    test "returns limit_exceeded when cost limit hit" do
      Application.put_env(:reseller, Reseller.Metrics,
        daily_limits: %{cost_usd: Decimal.new("0.00")},
        pricing: []
      )

      on_exit(fn ->
        Application.delete_env(:reseller, Reseller.Metrics)
      end)

      user = user_fixture()

      Metrics.refresh_user_summary(user.id)

      result = Metrics.check_limit(user.id)

      case result do
        :ok ->
          :ok

        {:error, :limit_exceeded, details} ->
          assert details[:resource] == "cost_usd"
      end
    end
  end

  describe "refresh_user_summary/2" do
    test "creates or updates summary for a user" do
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product)
      serp_api_event_fixture(user, product)
      photoroom_event_fixture(user, product)

      assert {:ok, summary} = Metrics.refresh_user_summary(user.id, Date.utc_today())

      assert summary.user_id == user.id
      assert summary.gemini_calls >= 1
      assert summary.serp_api_calls >= 1
      assert summary.photoroom_calls >= 1
      assert Decimal.gt?(summary.total_cost_usd, Decimal.new(0))
    end

    test "updates existing summary" do
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product)
      {:ok, _} = Metrics.refresh_user_summary(user.id, Date.utc_today())

      gemini_event_fixture(user, product)
      {:ok, summary} = Metrics.refresh_user_summary(user.id, Date.utc_today())

      assert summary.gemini_calls >= 2

      count = Repo.aggregate(UserUsageSummary, :count)
      assert count >= 1
    end
  end

  describe "platform_totals/1" do
    test "aggregates across all users" do
      user1 = user_fixture()
      user2 = user_fixture()
      product1 = product_fixture(user1)
      product2 = product_fixture(user2)

      gemini_event_fixture(user1, product1)
      gemini_event_fixture(user2, product2)
      serp_api_event_fixture(user1, product1)

      since = DateTime.add(DateTime.utc_now(), -3600, :second)
      result = Metrics.platform_totals(since: since)

      assert result.gemini_calls >= 2
      assert result.serp_api_calls >= 1
    end
  end

  describe "top_users_by_cost/1" do
    test "returns users ordered by cost" do
      user1 = user_fixture()
      user2 = user_fixture()
      product1 = product_fixture(user1)
      product2 = product_fixture(user2)

      gemini_event_fixture(user1, product1, %{cost_usd: Decimal.new("1.00")})
      gemini_event_fixture(user2, product2, %{cost_usd: Decimal.new("0.10")})

      result = Metrics.top_users_by_cost(days: 1, limit: 10)

      user_ids = Enum.map(result, & &1.user_id)
      assert user1.id in user_ids
      assert user2.id in user_ids

      costs = Enum.map(result, & &1.total_cost_usd)
      assert costs == Enum.sort(costs, &(Decimal.compare(&1, &2) != :lt))
    end
  end

  describe "error_summary/1" do
    test "counts errors by provider and operation" do
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product, %{status: "error", error_code: "timeout"})
      gemini_event_fixture(user, product, %{status: "error", error_code: "rate_limited"})
      serp_api_event_fixture(user, product, %{status: "error"})

      result = Metrics.error_summary(days: 1)

      gemini_errors =
        Enum.find(result, &(&1.provider == "gemini" and &1.operation == "recognition"))

      serp_errors = Enum.find(result, &(&1.provider == "serp_api"))

      assert gemini_errors.error_count >= 2
      assert serp_errors.error_count >= 1
    end
  end
end
