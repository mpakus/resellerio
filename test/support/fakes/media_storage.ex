defmodule Reseller.Support.Fakes.MediaStorage do
  @behaviour Reseller.Media.Storage

  @impl true
  def sign_upload(storage_key, opts) do
    send(self(), {:media_storage_called, storage_key, opts})

    {:ok,
     %{
       "method" => "PUT",
       "upload_url" => "https://uploads.example.test/#{storage_key}",
       "headers" => %{
         "content-type" => Keyword.get(opts, :content_type, "application/octet-stream")
       },
       "expires_at" => "2026-03-29T12:00:00Z"
     }}
  end

  @impl true
  def upload_object(storage_key, body, opts) do
    send(self(), {:media_storage_uploaded, storage_key, body, opts})

    {:ok,
     %{
       storage_key: storage_key,
       content_type: Keyword.get(opts, :content_type, "application/octet-stream"),
       byte_size: byte_size(body)
     }}
  end

  @impl true
  def sign_download(storage_key, opts) do
    send(self(), {:media_storage_download_signed, storage_key, opts})

    Keyword.get_lazy(opts, :sign_download_result, fn ->
      base_url = Keyword.get(opts, :public_base_url, "https://downloads.example.test")

      {:ok,
       %{
         "method" => "GET",
         "download_url" => join_url(base_url, storage_key),
         "expires_at" => "2026-03-29T12:00:00Z"
       }}
    end)
  end

  defp join_url(base_url, storage_key) do
    base = String.trim_trailing(base_url, "/")
    base <> "/" <> storage_key
  end
end
