defmodule Reseller.Media.Processor do
  @moduledoc """
  Behaviour and facade for image-processing providers such as Photoroom.
  """

  @type variant_profile :: %{kind: String.t(), background_style: String.t() | nil}
  @type process_result :: {:ok, map()} | {:error, term()}

  @callback process_image(String.t(), variant_profile(), keyword()) :: process_result()

  @spec process_image(String.t(), variant_profile(), keyword()) :: process_result()
  def process_image(image_url, profile, opts \\ [])
      when is_binary(image_url) and is_map(profile) do
    provider(opts).process_image(image_url, profile, opts)
  end

  @spec provider(keyword()) :: module()
  def provider(opts \\ []) do
    Keyword.get(opts, :provider, Application.fetch_env!(:reseller, Reseller.Media)[:processor])
  end
end
