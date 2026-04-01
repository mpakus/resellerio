defmodule Reseller.MetricsFixtures do
  alias Reseller.Metrics
  alias Reseller.Metrics.ApiUsageEvent
  alias Reseller.Repo

  def api_usage_event_fixture(attrs \\ %{}) do
    defaults = %{
      provider: "gemini",
      operation: "recognition",
      model: "gemini-2.5-flash",
      status: "success",
      http_status: 200,
      request_count: 1,
      image_count: 2,
      input_tokens: 1000,
      output_tokens: 200,
      total_tokens: 1200,
      cost_usd: Decimal.new("0.00015"),
      duration_ms: 850,
      metadata: %{}
    }

    attrs = Enum.into(attrs, defaults)

    %ApiUsageEvent{}
    |> ApiUsageEvent.create_changeset(attrs)
    |> Repo.insert!()
  end

  def gemini_event_fixture(user, product, attrs \\ %{}) do
    defaults = %{
      user_id: user.id,
      product_id: product.id,
      provider: "gemini",
      operation: "recognition",
      status: "success",
      total_tokens: 1500,
      cost_usd: Decimal.new("0.00020")
    }

    api_usage_event_fixture(Enum.into(attrs, defaults))
  end

  def serp_api_event_fixture(user, product, attrs \\ %{}) do
    defaults = %{
      user_id: user.id,
      product_id: product.id,
      provider: "serp_api",
      operation: "shopping_matches",
      status: "success",
      cost_usd: Decimal.new("0.0025")
    }

    api_usage_event_fixture(Enum.into(attrs, defaults))
  end

  def photoroom_event_fixture(user, product, attrs \\ %{}) do
    defaults = %{
      user_id: user.id,
      product_id: product.id,
      provider: "photoroom",
      operation: "process_image",
      image_count: 1,
      status: "success",
      cost_usd: Decimal.new("0.01")
    }

    api_usage_event_fixture(Enum.into(attrs, defaults))
  end

  def record_event(attrs) do
    Metrics.record_event(attrs)
  end
end
