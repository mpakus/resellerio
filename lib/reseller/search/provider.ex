defmodule Reseller.Search.Provider do
  @moduledoc """
  Behaviour for external search providers used by `Reseller.Search`.
  """

  @type provider_result :: {:ok, map()} | {:error, term()}

  @callback lens_matches(String.t(), keyword()) :: provider_result()
  @callback shopping_matches(String.t(), keyword()) :: provider_result()
end
