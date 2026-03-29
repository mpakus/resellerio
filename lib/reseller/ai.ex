defmodule Reseller.AI do
  @moduledoc """
  Entry point for AI-backed product recognition, description generation,
  pricing research, and reconciliation flows.
  """

  alias Reseller.AI.Provider

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

  @spec provider(keyword()) :: module()
  def provider(opts \\ []) do
    Keyword.get(opts, :provider, Application.fetch_env!(:reseller, __MODULE__)[:provider])
  end
end
