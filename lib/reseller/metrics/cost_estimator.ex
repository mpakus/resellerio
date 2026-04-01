defmodule Reseller.Metrics.CostEstimator do
  @moduledoc """
  Estimates the USD cost of a single external API call based on configurable
  pricing rates stored under `config :reseller, Reseller.Metrics`.

  Rates are expressed as:
  - Gemini: per-million input tokens, per-million output tokens, per-image
  - SerpApi: per search call
  - Photoroom: per edit call
  """

  @spec estimate(atom(), atom(), map()) :: Decimal.t()
  def estimate(provider, operation, attrs \\ %{})

  def estimate(:gemini, _operation, attrs) do
    config = pricing_config(:gemini)
    model = Map.get(attrs, :model) || Map.get(attrs, "model") || ""

    {input_rate, output_rate, image_rate} = gemini_rates(model, config)

    input_tokens = coerce_integer(Map.get(attrs, :input_tokens) || Map.get(attrs, "input_tokens"))

    output_tokens =
      coerce_integer(Map.get(attrs, :output_tokens) || Map.get(attrs, "output_tokens"))

    image_count = coerce_integer(Map.get(attrs, :image_count) || Map.get(attrs, "image_count"))

    input_cost =
      Decimal.mult(Decimal.new(input_tokens), Decimal.div(input_rate, Decimal.new(1_000_000)))

    output_cost =
      Decimal.mult(Decimal.new(output_tokens), Decimal.div(output_rate, Decimal.new(1_000_000)))

    image_cost = Decimal.mult(Decimal.new(image_count), image_rate)

    Decimal.add(input_cost, Decimal.add(output_cost, image_cost))
  end

  def estimate(:serp_api, _operation, _attrs) do
    pricing_config(:serp_api)[:per_call] || Decimal.new("0.0025")
  end

  def estimate(:photoroom, _operation, _attrs) do
    pricing_config(:photoroom)[:per_edit] || Decimal.new("0.01")
  end

  def estimate(_provider, _operation, _attrs), do: Decimal.new(0)

  defp gemini_rates(model, config) do
    rates = config[:models] || %{}

    matched =
      rates
      |> Enum.sort_by(fn {k, _v} -> -String.length(k) end)
      |> Enum.find(fn {prefix, _v} -> String.starts_with?(model, prefix) end)

    case matched do
      {_prefix, rate_map} ->
        {
          Decimal.new(to_string(rate_map[:input_per_million] || "0.10")),
          Decimal.new(to_string(rate_map[:output_per_million] || "0.40")),
          Decimal.new(to_string(rate_map[:per_image] || "0"))
        }

      nil ->
        {
          Decimal.new(to_string(config[:default_input_per_million] || "0.10")),
          Decimal.new(to_string(config[:default_output_per_million] || "0.40")),
          Decimal.new(to_string(config[:default_per_image] || "0"))
        }
    end
  end

  defp pricing_config(provider) do
    Application.get_env(:reseller, Reseller.Metrics, [])
    |> Keyword.get(:pricing, [])
    |> Keyword.get(provider, [])
  end

  defp coerce_integer(nil), do: 0
  defp coerce_integer(n) when is_integer(n), do: n
  defp coerce_integer(n) when is_float(n), do: round(n)

  defp coerce_integer(n) when is_binary(n) do
    case Integer.parse(n) do
      {v, _} -> v
      :error -> 0
    end
  end

  defp coerce_integer(_), do: 0
end
