defmodule Reseller.AI.Provider do
  @moduledoc """
  Behaviour for AI providers used by `Reseller.AI`.
  """

  @type image_input :: map()
  @type attrs :: map()
  @type provider_result :: {:ok, map()} | {:error, term()}

  @callback recognize_images([image_input()], attrs(), keyword()) :: provider_result()
  @callback generate_description(attrs(), keyword()) :: provider_result()
  @callback research_price(attrs(), attrs(), keyword()) :: provider_result()
  @callback generate_marketplace_listing(attrs(), keyword()) :: provider_result()
  @callback generate_lifestyle_image(attrs(), [image_input()], keyword()) :: provider_result()
  @callback reconcile_product(attrs(), attrs(), keyword()) :: provider_result()
end
