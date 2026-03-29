defmodule Reseller.AI do
  @moduledoc """
  Entry point for AI-backed product recognition, description generation,
  pricing research, and reconciliation flows.
  """

  alias Reseller.AI.Provider
  alias Reseller.AI.ProductDescriptionDraft
  alias Reseller.AI.ProductPriceResearch
  alias Reseller.Catalog.Product
  alias Reseller.Repo

  @spec recognize_images([map()], map(), keyword()) :: Provider.provider_result()
  def recognize_images(images, attrs \\ %{}, opts \\ []) when is_list(images) and is_map(attrs) do
    provider(opts).recognize_images(images, attrs, opts)
  end

  @spec generate_description(map(), keyword()) :: Provider.provider_result()
  def generate_description(product_attrs, opts \\ []) when is_map(product_attrs) do
    provider(opts).generate_description(product_attrs, opts)
  end

  @spec research_price(map(), map(), keyword()) :: Provider.provider_result()
  def research_price(product_attrs, search_results \\ %{}, opts \\ [])
      when is_map(product_attrs) and is_map(search_results) do
    provider(opts).research_price(product_attrs, search_results, opts)
  end

  @spec reconcile_product(map(), map(), keyword()) :: Provider.provider_result()
  def reconcile_product(recognition_result, search_results, opts \\ [])
      when is_map(recognition_result) and is_map(search_results) do
    provider(opts).reconcile_product(recognition_result, search_results, opts)
  end

  @spec run_recognition_pipeline([map()], map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run_recognition_pipeline(images, metadata \\ %{}, opts \\ [])
      when is_list(images) and is_map(metadata) do
    Reseller.AI.RecognitionPipeline.run(images, metadata, opts)
  end

  @spec get_product_description_draft(pos_integer()) :: ProductDescriptionDraft.t() | nil
  def get_product_description_draft(product_id) when is_integer(product_id) do
    Repo.get_by(ProductDescriptionDraft, product_id: product_id)
  end

  @spec upsert_product_description_draft(Product.t(), map()) ::
          {:ok, ProductDescriptionDraft.t()} | {:error, Ecto.Changeset.t()}
  def upsert_product_description_draft(%Product{} = product, description_result)
      when is_map(description_result) do
    attrs = description_draft_attrs(description_result)

    case get_product_description_draft(product.id) do
      nil ->
        %ProductDescriptionDraft{}
        |> ProductDescriptionDraft.create_changeset(attrs)
        |> Ecto.Changeset.put_assoc(:product, product)
        |> Repo.insert()

      draft ->
        draft
        |> ProductDescriptionDraft.update_changeset(attrs)
        |> Repo.update()
    end
  end

  @spec get_product_price_research(pos_integer()) :: ProductPriceResearch.t() | nil
  def get_product_price_research(product_id) when is_integer(product_id) do
    Repo.get_by(ProductPriceResearch, product_id: product_id)
  end

  @spec upsert_product_price_research(Product.t(), map()) ::
          {:ok, ProductPriceResearch.t()} | {:error, Ecto.Changeset.t()}
  def upsert_product_price_research(%Product{} = product, price_result)
      when is_map(price_result) do
    attrs = price_research_attrs(price_result)

    case get_product_price_research(product.id) do
      nil ->
        %ProductPriceResearch{}
        |> ProductPriceResearch.create_changeset(attrs)
        |> Ecto.Changeset.put_assoc(:product, product)
        |> Repo.insert()

      price_research ->
        price_research
        |> ProductPriceResearch.update_changeset(attrs)
        |> Repo.update()
    end
  end

  @spec provider(keyword()) :: module()
  def provider(opts \\ []) do
    Keyword.get(opts, :provider, Application.fetch_env!(:reseller, __MODULE__)[:provider])
  end

  defp description_draft_attrs(result) do
    output =
      case result do
        %{output: output} when is_map(output) -> output
        %{"output" => output} when is_map(output) -> output
        output when is_map(output) -> output
      end

    %{
      "status" => if(Map.get(output, "missing_details_warning"), do: "review", else: "generated"),
      "provider" => provider_name(result),
      "model" => model_name(result),
      "suggested_title" => output["suggested_title"],
      "short_description" => output["short_description"],
      "long_description" => output["long_description"],
      "key_features" => output["key_features"] || [],
      "seo_keywords" => output["seo_keywords"] || [],
      "missing_details_warning" => output["missing_details_warning"],
      "raw_payload" => stringify_keys(output)
    }
  end

  defp price_research_attrs(result) do
    output =
      case result do
        %{output: output} when is_map(output) -> output
        %{"output" => output} when is_map(output) -> output
        output when is_map(output) -> output
      end

    comparable_results =
      output["comparable_results"]
      |> normalize_comparable_results()

    %{
      "status" => price_research_status(output),
      "provider" => provider_name(result),
      "model" => model_name(result),
      "currency" => output["currency"] || "USD",
      "suggested_min_price" => output["suggested_min_price"],
      "suggested_target_price" => output["suggested_target_price"],
      "suggested_max_price" => output["suggested_max_price"],
      "suggested_median_price" => output["suggested_median_price"],
      "pricing_confidence" => output["pricing_confidence"],
      "rationale_summary" => output["rationale_summary"],
      "market_signals" => output["market_signals"] || [],
      "comparable_results" => %{"items" => comparable_results},
      "raw_payload" => stringify_keys(output)
    }
  end

  defp price_research_status(output) do
    if is_binary(output["rationale_summary"]) and String.trim(output["rationale_summary"]) != "" and
         is_number(output["pricing_confidence"]) and output["pricing_confidence"] >= 0.6 do
      "generated"
    else
      "review"
    end
  end

  defp normalize_comparable_results(nil), do: []

  defp normalize_comparable_results(results) when is_list(results),
    do: Enum.map(results, &stringify_keys/1)

  defp normalize_comparable_results(_results), do: []

  defp provider_name(%{provider: provider}) when is_atom(provider), do: Atom.to_string(provider)
  defp provider_name(%{"provider" => provider}) when is_binary(provider), do: provider
  defp provider_name(_result), do: nil

  defp model_name(%{model: model}) when is_binary(model), do: model
  defp model_name(%{"model" => model}) when is_binary(model), do: model
  defp model_name(_result), do: nil

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) -> {to_string(key), stringify_keys(value)}
      {key, value} when is_list(value) -> {to_string(key), Enum.map(value, &stringify_value/1)}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp stringify_value(value) when is_map(value), do: stringify_keys(value)
  defp stringify_value(value), do: value
end
