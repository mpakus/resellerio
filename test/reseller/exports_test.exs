defmodule Reseller.ExportsTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
  alias Reseller.Exports

  test "request_export_for_user/2 builds a zip, uploads it, and notifies the user" do
    user = user_fixture(%{"email" => "exporter@example.com"})

    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{
          "title" => "Nike Air Max",
          "brand" => "Nike",
          "category" => "Sneakers",
          "tags" => ["running", "air-max"]
        },
        [%{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: _finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    assert {:ok, export} =
             Exports.request_export_for_user(user,
               download_request_fun: fn image_url ->
                 assert image_url =~ "/users/#{user.id}/products/#{product.id}/originals/"
                 {:ok, %{status: 200, body: "jpeg-binary"}}
               end,
               public_base_url: "https://cdn.example.test"
             )

    assert export.status == "completed"
    assert export.storage_key == "users/#{user.id}/exports/#{export.id}.zip"
    assert export.completed_at
    assert export.expires_at

    storage_key = export.storage_key
    download_url = "https://cdn.example.test/users/#{user.id}/exports/#{export.id}.zip"

    assert_received {:media_storage_uploaded, ^storage_key, zip_binary, opts}
    assert opts[:content_type] == "application/zip"
    assert_received {:export_notifier_called, "exporter@example.com", export_id, ^download_url}

    assert export_id == export.id

    zip_path = Path.join(System.tmp_dir!(), "reseller-export-#{export.id}.zip")
    File.write!(zip_path, zip_binary)
    {:ok, entries} = :zip.extract(String.to_charlist(zip_path), [:memory])

    entries_by_name =
      Map.new(entries, fn {name, body} ->
        {to_string(name), body}
      end)

    assert Map.has_key?(entries_by_name, "index.json")
    assert Map.has_key?(entries_by_name, "images/#{product.id}/1-original.jpg")
    assert entries_by_name["images/#{product.id}/1-original.jpg"] == "jpeg-binary"

    index = Jason.decode!(entries_by_name["index.json"])
    [exported_product] = index["products"]

    assert exported_product["title"] == "Nike Air Max"
    assert exported_product["tags"] == ["running", "air-max"]

    assert exported_product["images"] == [
             %{
               "background_style" => nil,
               "content_type" => "image/jpeg",
               "id" => image.id,
               "kind" => "original",
               "path" => "images/#{product.id}/1-original.jpg",
               "position" => 1,
               "processing_status" => "processing"
             }
           ]
  end

  test "request_export_for_user/2 marks the export as failed when image downloads fail" do
    user = user_fixture(%{"email" => "export-failure@example.com"})

    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Broken export", "brand" => "Nike", "category" => "Sneakers"},
        [%{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: _finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    assert {:ok, export} =
             Exports.request_export_for_user(user,
               download_request_fun: fn _image_url -> {:error, :upstream_unavailable} end,
               public_base_url: "https://cdn.example.test"
             )

    assert export.status == "failed"
    assert export.error_message =~ "image_download_failed"
    assert export.storage_key == nil

    refute_received {:export_notifier_called, _, _, _}
  end
end
