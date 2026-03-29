defmodule Reseller.Workers.NoopProductProcessor do
  @moduledoc """
  Placeholder processor used until the AI/image worker pipeline is connected.
  """

  @behaviour Reseller.Workers.ProductProcessor

  @impl true
  def process(product, _opts) do
    {:ok,
     %{
       step: "awaiting_ai",
       payload: %{
         "message" => "Background processing foundation executed",
         "product_id" => product.id
       }
     }}
  end
end
