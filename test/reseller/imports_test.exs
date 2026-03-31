defmodule Reseller.ImportsTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
  alias Reseller.Imports

  test "request_import_for_user/3 recreates products, images, and generated metadata" do
    user = user_fixture(%{"email" => "importer@example.com"})

    zip_binary =
      build_import_zip(
        [
          %{
            "status" => "ready",
            "title" => "Vintage Levi's Jacket",
            "brand" => "Levi's",
            "category" => "Jackets",
            "condition" => "Used - Good",
            "color" => "Blue",
            "size" => "M",
            "material" => "Denim",
            "price" => "89.00",
            "cost" => "20.00",
            "sku" => "IMP-1",
            "tags" => ["denim", "vintage"],
            "notes" => "Imported from archive",
            "ai_summary" => "Classic denim jacket",
            "ai_confidence" => 0.92,
            "description_draft" => %{
              "status" => "generated",
              "suggested_title" => "Levi's Denim Trucker Jacket",
              "short_description" => "Vintage denim jacket with classic wash",
              "long_description" => "Longer imported description",
              "key_features" => ["Button front", "Chest pockets"],
              "seo_keywords" => ["levis", "denim jacket"]
            },
            "price_research" => %{
              "status" => "generated",
              "currency" => "USD",
              "suggested_min_price" => "75.00",
              "suggested_target_price" => "89.00",
              "suggested_max_price" => "110.00",
              "suggested_median_price" => "90.00",
              "pricing_confidence" => 0.8,
              "rationale_summary" => "Comparable sold listings support a mid-range ask."
            },
            "marketplace_listings" => [
              %{
                "marketplace" => "ebay",
                "status" => "generated",
                "generated_title" => "Levi's Denim Jacket - eBay",
                "generated_description" => "eBay listing body",
                "generated_tags" => ["denim", "vintage"],
                "generated_price_suggestion" => "92.00",
                "generation_version" => "zip-import",
                "compliance_warnings" => []
              }
            ],
            "images" => [
              %{
                "kind" => "original",
                "position" => 1,
                "content_type" => "image/jpeg",
                "background_style" => nil,
                "processing_status" => "ready",
                "path" => "images/source/1-original.jpg"
              }
            ]
          }
        ],
        %{"images/source/1-original.jpg" => "jpeg-binary"}
      )

    assert {:ok, import_record} =
             Imports.request_import_for_user(user, %{
               "filename" => "catalog.zip",
               "archive_base64" => Base.encode64(zip_binary)
             })

    assert import_record.status == "completed"

    assert import_record.source_storage_key ==
             "users/#{user.id}/imports/#{import_record.id}/source.zip"

    assert import_record.total_products == 1
    assert import_record.imported_products == 1
    assert import_record.failed_products == 0
    assert import_record.payload["created_product_ids"] != []

    [product] = Catalog.list_products_for_user(user)

    assert product.source == "import"
    assert product.title == "Vintage Levi's Jacket"
    assert product.brand == "Levi's"
    assert product.status == "ready"
    assert product.tags == ["denim", "vintage"]
    assert product.description_draft.short_description == "Vintage denim jacket with classic wash"
    assert Decimal.equal?(product.price_research.suggested_target_price, Decimal.new("89.00"))
    assert Enum.map(product.marketplace_listings, & &1.marketplace) == ["ebay"]
    assert Enum.map(product.images, & &1.kind) == ["original"]
    assert Enum.all?(product.images, &(&1.processing_status == "ready"))

    source_key = "users/#{user.id}/imports/#{import_record.id}/source.zip"

    assert_received {:media_storage_uploaded, ^source_key, ^zip_binary, source_opts}
    assert source_opts[:content_type] == "application/zip"

    assert_received {:media_storage_uploaded, image_key, "jpeg-binary", image_opts}
    assert image_key =~ "/products/#{product.id}/imports/1-original-"
    assert image_opts[:content_type] == "image/jpeg"
  end

  test "request_import_for_user/3 records per-product failures without aborting the whole import" do
    user = user_fixture(%{"email" => "partial-import@example.com"})

    zip_binary =
      build_import_zip(
        [
          %{
            "status" => "ready",
            "title" => "Imported Product",
            "sku" => "GOOD-1",
            "images" => [
              %{
                "kind" => "original",
                "position" => 1,
                "content_type" => "image/jpeg",
                "processing_status" => "ready",
                "path" => "images/ok/1-original.jpg"
              }
            ]
          },
          %{
            "status" => "ready",
            "title" => "Broken Product",
            "sku" => "BAD-1",
            "images" => [
              %{
                "kind" => "original",
                "position" => 1,
                "content_type" => "image/jpeg",
                "processing_status" => "ready",
                "path" => "images/missing/1-original.jpg"
              }
            ]
          }
        ],
        %{"images/ok/1-original.jpg" => "ok-binary"}
      )

    assert {:ok, import_record} =
             Imports.request_import_for_user(user, %{
               "filename" => "partial.zip",
               "archive_base64" => Base.encode64(zip_binary)
             })

    assert import_record.status == "completed"
    assert import_record.total_products == 2
    assert import_record.imported_products == 1
    assert import_record.failed_products == 1

    assert import_record.failure_details == %{
             "items" => [
               %{
                 "index" => 2,
                 "reason" => "Missing image entry: images/missing/1-original.jpg",
                 "sku" => "BAD-1",
                 "title" => "Broken Product"
               }
             ]
           }

    assert Enum.map(Catalog.list_products_for_user(user), & &1.sku) == ["GOOD-1"]
  end

  test "request_import_for_user/3 marks the import as failed for an invalid zip archive" do
    user = user_fixture(%{"email" => "invalid-import@example.com"})

    assert {:ok, import_record} =
             Imports.request_import_for_user(user, %{
               "filename" => "invalid.zip",
               "archive_base64" => Base.encode64("not-a-real-zip")
             })

    assert import_record.status == "failed"
    assert import_record.error_message =~ "invalid_zip_archive"
    assert Catalog.list_products_for_user(user) == []
  end

  test "fetch_archive/2 downloads the stored archive when no inline archive binary is given" do
    user = user_fixture(%{"email" => "fetch-import@example.com"})
    zip_binary = build_import_zip([], %{})

    assert {:ok, import_record} =
             Imports.request_import_for_user(user, %{
               "filename" => "catalog.zip",
               "archive_base64" => Base.encode64(zip_binary)
             })

    assert {:ok, "downloaded-archive"} =
             Imports.fetch_archive(import_record,
               public_base_url: "https://cdn.example.test",
               download_request_fun: fn archive_url ->
                 assert archive_url =~ import_record.source_storage_key
                 {:ok, %{status: 200, body: "downloaded-archive"}}
               end
             )
  end

  test "fetch_archive/2 returns an error for non-success download responses" do
    user = user_fixture(%{"email" => "fetch-import-error@example.com"})
    zip_binary = build_import_zip([], %{})

    assert {:ok, import_record} =
             Imports.request_import_for_user(user, %{
               "filename" => "catalog.zip",
               "archive_base64" => Base.encode64(zip_binary)
             })

    assert {:error, :archive_download_failed} =
             Imports.fetch_archive(import_record,
               public_base_url: "https://cdn.example.test",
               download_request_fun: fn _archive_url ->
                 {:ok, %{status: 500, body: "boom"}}
               end
             )
  end

  defp build_import_zip(products, image_entries) do
    entries =
      [
        {~c"manifest.json", Jason.encode!(%{"products" => products}, pretty: true)},
        {~c"Products.xls", "<Workbook></Workbook>"}
      ] ++
        Enum.map(image_entries, fn {path, body} -> {String.to_charlist(path), body} end)

    {:ok, {_filename, zip_binary}} = :zip.create(~c"import.zip", entries, [:memory])
    zip_binary
  end
end
