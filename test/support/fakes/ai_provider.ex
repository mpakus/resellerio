defmodule Reseller.Support.Fakes.AIProvider do
  @behaviour Reseller.AI.Provider

  @impl true
  def recognize_images(images, attrs, opts) do
    send(self(), {:ai_provider_called, :recognize_images, images, attrs, opts})

    Keyword.get(
      opts,
      :recognize_result,
      {:ok, %{operation: :recognize_images, images: images, attrs: attrs}}
    )
  end

  @impl true
  def generate_description(attrs, opts) do
    send(self(), {:ai_provider_called, :generate_description, attrs, opts})

    Keyword.get(
      opts,
      :description_result,
      {:ok, %{operation: :generate_description, attrs: attrs}}
    )
  end

  @impl true
  def research_price(attrs, search_results, opts) do
    send(self(), {:ai_provider_called, :research_price, attrs, search_results, opts})

    Keyword.get(
      opts,
      :price_result,
      {:ok, %{operation: :research_price, attrs: attrs, search_results: search_results}}
    )
  end

  @impl true
  def reconcile_product(recognition_result, search_results, opts) do
    send(
      self(),
      {:ai_provider_called, :reconcile_product, recognition_result, search_results, opts}
    )

    Keyword.get(
      opts,
      :reconcile_result,
      {:ok,
       %{
         operation: :reconcile_product,
         recognition_result: recognition_result,
         search_results: search_results
       }}
    )
  end
end
