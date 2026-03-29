defmodule Reseller.Search do
  @moduledoc """
  Entry point for external search providers that enrich AI recognition and pricing.
  """

  alias Reseller.Search.Provider

  @spec lens_matches(String.t(), keyword()) :: Provider.provider_result()
  def lens_matches(image_url, opts \\ []) when is_binary(image_url) do
    provider(opts).lens_matches(image_url, opts)
  end

  @spec shopping_matches(String.t(), keyword()) :: Provider.provider_result()
  def shopping_matches(query, opts \\ []) when is_binary(query) do
    provider(opts).shopping_matches(query, opts)
  end

  @spec provider(keyword()) :: module()
  def provider(opts \\ []) do
    Keyword.get(opts, :provider, Application.fetch_env!(:reseller, __MODULE__)[:provider])
  end
end
