defmodule Reseller.ExportsTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
  alias Reseller.Exports
  alias Reseller.Exports.Export
  alias Reseller.Repo

  test "request_export_for_user/2 builds a filtered zip, uploads it, and notifies the user" do
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

    _non_match = product_fixture(user, %{"title" => "Canvas tote", "status" => "ready"})

    [image] = product.images

    {:ok, %{product: _finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    assert {:ok, export} =
             Exports.request_export_for_user(user,
               name: "Air inventory export",
               filters: %{"query" => "Air"},
               download_request_fun: fn image_url ->
                 assert image_url =~ "/users/#{user.id}/products/#{product.id}/originals/"
                 {:ok, %{status: 200, body: "jpeg-binary"}}
               end,
               public_base_url: "https://cdn.example.test"
             )

    assert export.name == "Air inventory export"
    assert export.status == "completed"
    assert export.filter_params == %{"query" => "Air"}
    assert export.product_count == 1
    assert export.file_name =~ "air-inventory-export-"

    assert export.storage_key ==
             "users/#{user.id}/exports/#{export.id}/#{export.file_name}"

    assert export.completed_at
    assert export.expires_at

    storage_key = export.storage_key
    download_url = "https://cdn.example.test/#{storage_key}"

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

    assert Map.has_key?(entries_by_name, "Products.xls")
    assert Map.has_key?(entries_by_name, "manifest.json")
    assert Map.has_key?(entries_by_name, "images/#{product.id}/1-original-shoe-1.jpg")
    assert entries_by_name["images/#{product.id}/1-original-shoe-1.jpg"] == "jpeg-binary"
    assert entries_by_name["Products.xls"] =~ "Nike Air Max"
    assert entries_by_name["Products.xls"] =~ "Air inventory export"

    manifest = Jason.decode!(entries_by_name["manifest.json"])
    assert manifest["export"]["name"] == "Air inventory export"
    assert manifest["export"]["filter_params"] == %{"query" => "Air"}

    [exported_product] = manifest["products"]

    assert exported_product["title"] == "Nike Air Max"
    assert exported_product["tags"] == ["running", "air-max"]

    assert exported_product["images"] == [
             %{
               "approved_at" => nil,
               "background_style" => nil,
               "byte_size" => 123_000,
               "checksum" => "abc123",
               "content_type" => "image/jpeg",
               "filename" => "1-original-shoe-1.jpg",
               "height" => 1600,
               "id" => image.id,
               "kind" => "original",
               "original_filename" => "shoe-1.jpg",
               "path" => "images/#{product.id}/1-original-shoe-1.jpg",
               "position" => 1,
               "processing_status" => "processing",
               "scene_key" => nil,
               "seller_approved" => false,
               "source_image_ids" => [],
               "storage_key" => image.storage_key,
               "variant_index" => nil,
               "width" => 1200
             }
           ]
  end

  test "request_export_for_user/2 marks the export as failed with a readable image error" do
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
               name: "Broken export",
               download_request_fun: fn _image_url -> {:error, :upstream_unavailable} end,
               public_base_url: "https://cdn.example.test"
             )

    assert export.status == "failed"

    assert export.error_message ==
             "Export failed because product image ##{image.id} could not be downloaded. Check storage access and retry."

    assert export.storage_key == nil

    refute_received {:export_notifier_called, _, _, _}
  end

  test "request_export_for_user/2 stores a concise failure when storage returns a large XML body" do
    user = user_fixture(%{"email" => "export-404@example.com"})

    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Missing image export", "brand" => "Nike", "category" => "Sneakers"},
        [%{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: _finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    xml_body =
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <Error><Code>NoSuchKey</Code><Message>The specified key does not exist.</Message></Error>
      """ <> String.duplicate("x", 600)

    assert {:ok, export} =
             Exports.request_export_for_user(user,
               name: "Missing image export",
               download_request_fun: fn _image_url ->
                 {:ok, %{status: 404, body: xml_body}}
               end,
               public_base_url: "https://cdn.example.test"
             )

    assert export.status == "failed"

    assert export.error_message ==
             "Export failed because product image ##{image.id} is missing from storage (HTTP 404 NoSuchKey). Re-upload the image and retry."

    assert String.length(export.error_message) < 255
  end

  test "mark_failed/2 truncates oversized messages before persisting" do
    user = user_fixture(%{"email" => "export-truncation@example.com"})

    export =
      %Export{}
      |> Export.create_changeset(%{
        "name" => "Truncation test",
        "file_name" => "truncation-test.zip",
        "filter_params" => %{},
        "product_count" => 1,
        "status" => "queued",
        "requested_at" => DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Repo.insert!()

    long_message = String.duplicate("x", 550)

    assert {:ok, failed_export} = Exports.mark_failed(export, long_message)
    assert failed_export.status == "failed"
    assert String.length(failed_export.error_message) == 500
    assert String.ends_with?(failed_export.error_message, "...")
  end
end
