defmodule Reseller.Support.Fakes.SearchProvider do
  @behaviour Reseller.Search.Provider

  @impl true
  def lens_matches(image_url, opts) do
    send(self(), {:search_provider_called, :lens_matches, image_url, opts})
    {:ok, %{search_type: :lens, image_url: image_url}}
  end

  @impl true
  def shopping_matches(query, opts) do
    send(self(), {:search_provider_called, :shopping_matches, query, opts})
    {:ok, %{search_type: :shopping, query: query}}
  end
end
