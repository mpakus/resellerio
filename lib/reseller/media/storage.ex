defmodule Reseller.Media.Storage do
  @moduledoc """
  Behaviour and facade for media storage upload signing.
  """

  @type upload_result :: {:ok, map()} | {:error, term()}
  @type put_result :: {:ok, map()} | {:error, term()}

  @callback sign_upload(String.t(), keyword()) :: upload_result()
  @callback upload_object(String.t(), binary(), keyword()) :: put_result()

  @spec sign_upload(String.t(), keyword()) :: upload_result()
  def sign_upload(storage_key, opts \\ []) when is_binary(storage_key) do
    provider(opts).sign_upload(storage_key, opts)
  end

  @spec upload_object(String.t(), binary(), keyword()) :: put_result()
  def upload_object(storage_key, body, opts \\ [])
      when is_binary(storage_key) and is_binary(body) do
    provider(opts).upload_object(storage_key, body, opts)
  end

  @spec provider(keyword()) :: module()
  def provider(opts \\ []) do
    Keyword.get(opts, :provider, Application.fetch_env!(:reseller, Reseller.Media)[:storage])
  end
end
