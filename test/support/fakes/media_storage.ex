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
end
