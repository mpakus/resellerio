defmodule Reseller.Support.Fakes.ProductProcessor do
  @behaviour Reseller.Workers.ProductProcessor

  @impl true
  def process(product, opts) do
    send(self(), {:product_processor_called, product.id, opts})

    Keyword.get(
      opts,
      :processor_result,
      {:ok,
       %{
         step: "awaiting_ai",
         payload: %{
           "processor" => "fake",
           "product_id" => product.id
         }
       }}
    )
  end
end
