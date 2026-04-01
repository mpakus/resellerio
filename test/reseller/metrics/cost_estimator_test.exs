defmodule Reseller.Metrics.CostEstimatorTest do
  use ExUnit.Case, async: true

  alias Reseller.Metrics.CostEstimator

  describe "estimate/3 for Gemini" do
    test "returns zero cost when no tokens" do
      cost = CostEstimator.estimate(:gemini, :recognition, %{model: "gemini-2.5-flash"})
      assert Decimal.eq?(cost, Decimal.new(0))
    end

    test "computes cost from input and output tokens" do
      cost =
        CostEstimator.estimate(:gemini, :description, %{
          model: "gemini-2.5-flash",
          input_tokens: 1_000_000,
          output_tokens: 1_000_000,
          image_count: 0
        })

      assert Decimal.gt?(cost, Decimal.new(0))
      assert Decimal.eq?(cost, Decimal.new("0.50"))
    end

    test "handles nil tokens gracefully" do
      cost =
        CostEstimator.estimate(:gemini, :recognition, %{
          model: "gemini-2.5-flash",
          input_tokens: nil,
          output_tokens: nil,
          image_count: nil
        })

      assert Decimal.eq?(cost, Decimal.new(0))
    end

    test "handles unknown model using default rates" do
      cost =
        CostEstimator.estimate(:gemini, :recognition, %{
          model: "gemini-unknown-model",
          input_tokens: 1_000_000,
          output_tokens: 0,
          image_count: 0
        })

      assert Decimal.gt?(cost, Decimal.new(0))
    end

    test "handles string token values" do
      cost =
        CostEstimator.estimate(:gemini, :description, %{
          model: "gemini-2.5-flash",
          input_tokens: "500",
          output_tokens: "100",
          image_count: 0
        })

      assert Decimal.gt?(cost, Decimal.new(0))
    end
  end

  describe "estimate/3 for SerpApi" do
    test "returns fixed per-call cost" do
      cost = CostEstimator.estimate(:serp_api, :shopping_matches, %{})
      assert Decimal.eq?(cost, Decimal.new("0.0025"))
    end
  end

  describe "estimate/3 for Photoroom" do
    test "returns fixed per-edit cost" do
      cost = CostEstimator.estimate(:photoroom, :process_image, %{image_count: 1})
      assert Decimal.eq?(cost, Decimal.new("0.01"))
    end
  end

  describe "estimate/3 for unknown provider" do
    test "returns zero" do
      cost = CostEstimator.estimate(:unknown_provider, :some_op, %{})
      assert Decimal.eq?(cost, Decimal.new(0))
    end
  end
end
