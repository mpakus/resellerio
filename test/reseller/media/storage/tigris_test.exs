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
             "https://reseller-images.t3.storage.dev/users/1/products/2/originals/example.jpg?"
  end

  test "public_base_url/1 includes the bucket_name for endpoint-style config" do
    assert {:ok, "https://reseller-images.t3.storage.dev/"} =
             Tigris.public_base_url(
               base_url: "https://t3.storage.dev",
               bucket_name: "reseller-images"
             )
  end

  test "upload_object/3 sends the object through ExAws" do
    send_to_self = fn operation, overrides ->
      send(self(), {:ex_aws_request, operation, overrides})
      {:ok, %{status_code: 200}}
    end

    assert {:ok, %{storage_key: "users/1/products/2/originals/example.jpg", byte_size: 12}} =
             Tigris.upload_object(
               "users/1/products/2/originals/example.jpg",
               "hello tigris",
               content_type: "image/jpeg",
               ex_aws_request_fun: send_to_self,
               config: [
                 access_key_id: "tigris-access",
                 secret_access_key: "tigris-secret",
                 base_url: "https://fly.storage.tigris.dev",
                 bucket_name: "reseller-images",
                 region: "auto"
               ]
             )

    assert_received {:ex_aws_request,
                     %{__struct__: ExAws.Operation.S3, bucket: "reseller-images"} = operation,
                     overrides}

    assert operation.http_method == :put
    assert operation.path == "users/1/products/2/originals/example.jpg"
    assert operation.headers["content-type"] == "image/jpeg"
    assert overrides[:host] == "fly.storage.tigris.dev"
    assert overrides[:virtual_host] == true
  end

  test "upload_object/3 falls back to a presigned PUT when Tigris denies the direct S3 request" do
    direct_request = fn _operation, _overrides ->
      {:error,
       {:http_error, 403,
        %{
          body:
            "<?xml version=\"1.0\"?><Error><Code>AccessDenied</Code><Message>Access Denied.</Message></Error>"
        }}}
    end

    presigned_upload = fn upload, body ->
      send(self(), {:presigned_upload, upload, body})
      {:ok, %{status: 200}}
    end

    assert {:ok, %{storage_key: "users/1/products/2/originals/example.jpg", byte_size: 12}} =
             Tigris.upload_object(
               "users/1/products/2/originals/example.jpg",
               "hello tigris",
               content_type: "image/jpeg",
               ex_aws_request_fun: direct_request,
               upload_request_fun: presigned_upload,
               config: [
                 access_key_id: "tigris-access",
                 secret_access_key: "tigris-secret",
                 base_url: "https://fly.storage.tigris.dev",
                 bucket_name: "reseller-images",
                 region: "auto"
               ]
             )

    assert_received {:presigned_upload, upload, "hello tigris"}
    assert upload.headers == %{"content-type" => "image/jpeg"}

    assert upload.upload_url =~
             "https://reseller-images.fly.storage.tigris.dev/users/1/products/2/originals/example.jpg?"
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
