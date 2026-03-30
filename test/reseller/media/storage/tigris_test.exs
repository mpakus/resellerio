defmodule Reseller.Media.Storage.TigrisTest do
  use ExUnit.Case, async: true

  alias Reseller.Media.Storage.Tigris

  test "sign_upload/2 returns a presigned put url" do
    request_time = ~U[2026-03-29 18:30:00Z]

    assert {:ok, result} =
             Tigris.sign_upload(
               "users/1/products/2/originals/example.jpg",
               content_type: "image/jpeg",
               expires_in: 600,
               request_time: request_time,
               config: [
                 access_key_id: "tigris-access",
                 secret_access_key: "tigris-secret",
                 base_url: "https://bucket.example.tigris.dev",
                 region: "auto",
                 expires_in: 900
               ]
             )

    assert result.method == "PUT"
    assert result.headers == %{"content-type" => "image/jpeg"}
    assert result.expires_at == "2026-03-29T18:40:00Z"
    assert result.headers == %{"content-type" => "image/jpeg"}

    assert result.upload_url =~
             "https://bucket.example.tigris.dev/users/1/products/2/originals/example.jpg?"

    assert result.upload_url =~ "Content-Type=image%2Fjpeg"
    assert result.upload_url =~ "X-Amz-Algorithm=AWS4-HMAC-SHA256"

    assert result.upload_url =~
             "X-Amz-Credential=tigris-access%2F20260329%2Fauto%2Fs3%2Faws4_request"

    assert result.upload_url =~ "X-Amz-SignedHeaders=host"
    assert result.upload_url =~ "X-Amz-Signature="
  end

  test "sign_upload/2 supports endpoint-style Tigris config with bucket_name" do
    request_time = ~U[2026-03-29 18:30:00Z]

    assert {:ok, result} =
             Tigris.sign_upload(
               "users/1/products/2/originals/example.jpg",
               content_type: "image/jpeg",
               expires_in: 600,
               request_time: request_time,
               config: [
                 access_key_id: "tigris-access",
                 secret_access_key: "tigris-secret",
                 base_url: "https://t3.storage.dev",
                 bucket_name: "reseller-images",
                 region: "auto",
                 expires_in: 900
               ]
             )

    assert result.upload_url =~
             "https://t3.storage.dev/reseller-images/users/1/products/2/originals/example.jpg?"
  end

  test "public_base_url/1 includes the bucket_name for endpoint-style config" do
    assert {:ok, "https://t3.storage.dev/reseller-images"} =
             Tigris.public_base_url(
               base_url: "https://t3.storage.dev",
               bucket_name: "reseller-images"
             )
  end

  test "sign_upload/2 returns a configuration error when required values are missing" do
    assert {:error, {:missing_config, :access_key_id}} =
             Tigris.sign_upload(
               "users/1/products/2/originals/example.jpg",
               config: [
                 base_url: "https://bucket.example.tigris.dev",
                 secret_access_key: "secret"
               ]
             )
  end

  test "sign_upload/2 requires bucket_name when using a generic Tigris endpoint" do
    assert {:error, {:missing_config, :bucket_name}} =
             Tigris.sign_upload(
               "users/1/products/2/originals/example.jpg",
               config: [
                 access_key_id: "tigris-access",
                 secret_access_key: "tigris-secret",
                 base_url: "https://t3.storage.dev"
               ]
             )
  end
end
