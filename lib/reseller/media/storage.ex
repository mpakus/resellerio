defmodule Reseller.Media.Storage do
  @moduledoc """
  Behaviour and facade for media storage upload signing.
  """

  @type upload_result :: {:ok, map()} | {:error, term()}

  @callback sign_upload(String.t(), keyword()) :: upload_result()

  @spec sign_upload(String.t(), keyword()) :: upload_result()
  def sign_upload(storage_key, opts \\ []) when is_binary(storage_key) do
    provider(opts).sign_upload(storage_key, opts)
  end

  @spec provider(keyword()) :: module()
  def provider(opts \\ []) do
    Keyword.get(opts, :provider, Application.fetch_env!(:reseller, Reseller.Media)[:storage])
  end
end
