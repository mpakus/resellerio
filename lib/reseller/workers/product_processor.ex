defmodule Reseller.Workers.ProductProcessor do
  @moduledoc """
  Behaviour for background product processors.
  """

  @type processor_result ::
          {:ok, %{step: String.t(), payload: map()}}
          | {:error, %{code: String.t(), message: String.t(), payload: map()}}

  @callback process(Reseller.Catalog.Product.t(), keyword()) :: processor_result()
end
