defmodule ResellerWeb.ProductsLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Reseller.Catalog
  alias Reseller.Exports
  alias Reseller.Repo

  test "products index filters by status and updated date", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    ready_product = product_fixture(user, %{"title" => "Ready coat", "status" => "ready"})
    sold_product = product_fixture(user, %{"title" => "Sold shoes", "status" => "sold"})

    stale_product =
      product_fixture(user, %{"title" => "Old sweater", "status" => "ready"})
      |> set_product_updated_at!(~U[2024-01-10 12:00:00Z])

    other_user = user_fixture(%{"email" => "other@example.com"})

    _other_product =
      product_fixture(other_user, %{"title" => "Other user item", "status" => "ready"})

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products?status=ready")

    assert has_element?(view, "#workspace-products-table", ready_product.title)
    assert has_element?(view, "#workspace-products-table", stale_product.title)
    refute has_element?(view, "#workspace-products-table", sold_product.title)
    refute render(view) =~ "Other user item"

    today = Date.utc_today() |> Date.to_iso8601()

    view
    |> form("#product-date-range-form",
      filters: %{"updated_from" => today, "updated_to" => today}
    )
    |> render_change()

    assert has_element?(view, "#workspace-products-table", ready_product.title)
    refute has_element?(view, "#workspace-products-table", stale_product.title)
    refute render(view) =~ "Other user item"
  end

  test "products index route renders its section", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products")
    assert has_element?(view, "#workspace-products")
  end

  test "products index filters by product tab and creates tabs from the modal", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    shoes_tab = product_tab_fixture(user, %{"name" => "Shoes"})
    outerwear_tab = product_tab_fixture(user, %{"name" => "Outerwear"})
    shoe_product = product_fixture(user, %{"title" => "Runner", "product_tab_id" => shoes_tab.id})

    _coat_product =
      product_fixture(user, %{"title" => "Coat", "product_tab_id" => outerwear_tab.id})

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products")

    assert has_element?(view, "#product-tab-filter-#{shoes_tab.id}", "Shoes")
    assert has_element?(view, "#product-tab-filter-#{outerwear_tab.id}", "Outerwear")

    view
    |> element("#product-tab-filter-#{shoes_tab.id}")
    |> render_click()

    assert_patch(view, "/app/products?dir=desc&page=1&sort=updated_at&tab=#{shoes_tab.id}")
    assert has_element?(view, "#workspace-products-table", shoe_product.title)
    refute has_element?(view, "#workspace-products-table", "Coat")

    view
    |> element("#open-product-tab-modal-button")
    |> render_click()

    assert has_element?(view, "#product-tab-modal", "Add a new tab")

    view
    |> form("#product-tab-form", product_tab: %{"name" => "Vintage"})
    |> render_submit()

    created_tab = Catalog.list_product_tabs_for_user(user) |> Enum.find(&(&1.name == "Vintage"))

    assert created_tab
    assert_patch(view, "/app/products?dir=desc&page=1&sort=updated_at&tab=#{created_tab.id}")
    assert has_element?(view, "#product-tab-filter-#{created_tab.id}", "Vintage")
  end

  test "products index edits the active product tab from the modal", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product_tab = product_tab_fixture(user, %{"name" => "Shoes"})
    product_fixture(user, %{"title" => "Runner", "product_tab_id" => product_tab.id})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} =
      live(conn, "/app/products?dir=desc&page=1&sort=updated_at&tab=#{product_tab.id}")

    assert has_element?(view, "#product-tab-action-#{product_tab.id}", "...")
    refute has_element?(view, "#open-edit-product-tab-modal-button")

    view
    |> element("#product-tab-action-#{product_tab.id}")
    |> render_click()

    assert has_element?(view, "#product-tab-modal", "Edit tab")
    assert render(view) =~ ~s(value="Shoes")

    view
    |> form("#product-tab-form", product_tab: %{"name" => "Sneakers"})
    |> render_submit()

    assert_patch(view, "/app/products?dir=desc&page=1&sort=updated_at&tab=#{product_tab.id}")
    assert has_element?(view, "#product-tab-filter-#{product_tab.id}", "Sneakers")
    assert render(view) =~ "Tab: Sneakers"

    assert Enum.any?(
             Catalog.list_product_tabs_for_user(user),
             &(&1.id == product_tab.id and &1.name == "Sneakers")
           )
  end

  test "products index paginates rows", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})

    for index <- 1..16 do
      product_fixture(user, %{
        "title" => "Paged item #{String.pad_leading(Integer.to_string(index), 2, "0")}"
      })
    end

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products")

    assert has_element?(view, "#workspace-products-table", "Paged item 16")
    refute has_element?(view, "#workspace-products-table", "Paged item 01")

    view
    |> element("#products-page-next")
    |> render_click()

    assert has_element?(view, "#workspace-products-table", "Paged item 01")
  end

  test "products index filters rows with real-time full-text search", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product_fixture(user, %{"title" => "Nike runner", "tags" => "retro, vintage"})
    product_fixture(user, %{"title" => "Canvas tote", "notes" => "Farmer market bag"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products")

    view
    |> form("#product-date-range-form", filters: %{"query" => "retro"})
    |> render_change()

    assert render(view) =~ ~s(value="retro")
    assert has_element?(view, "#workspace-products-table", "Nike runner")
    refute has_element?(view, "#workspace-products-table", "Canvas tote")
    assert render(view) =~ ~s(id="workspace-products-empty" class="hidden only:table-row")
  end

  test "products index exports the current filtered result set", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product_tab = product_tab_fixture(user, %{"name" => "Outerwear"})

    product_fixture(user, %{
      "title" => "Fila jacket",
      "status" => "ready",
      "product_tab_id" => product_tab.id
    })

    product_fixture(user, %{"title" => "Canvas tote", "status" => "ready"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products")

    view
    |> element("#product-tab-filter-#{product_tab.id}")
    |> render_click()

    view
    |> form("#product-date-range-form", filters: %{"query" => "Fila"})
    |> render_change()

    view
    |> element("#open-export-modal-button")
    |> render_click()

    assert has_element?(view, "#products-export-modal", "Export the current table results")
    assert render(view) =~ "1 product"
    assert render(view) =~ "Search: Fila"

    view
    |> form("#request-export-form", export: %{"name" => "Fila filtered export"})
    |> render_submit()

    [export] = Exports.list_exports_for_user(user)

    assert export.name == "Fila filtered export"

    assert export.filter_params == %{
             "product_tab_id" => product_tab.id,
             "product_tab_name" => "Outerwear",
             "query" => "Fila"
           }

    assert export.product_count == 1

    assert has_element?(view, "#products-export-modal", "Export is ready")
    assert has_element?(view, "#download-export-link", "Download ZIP")
  end

  test "products index sorts by title", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product_fixture(user, %{"title" => "Zulu cap"})
    product_fixture(user, %{"title" => "Alpha cap"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products")

    view
    |> element("#product-sort-title")
    |> render_click()

    sorted_html = render(view)
    assert_in_order(sorted_html, "Alpha cap", "Zulu cap")
  end

  test "legacy product_id query redirects to the dedicated review route", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = product_fixture(user, %{"title" => "Redirect me"})
    conn = init_test_session(conn, %{user_id: user.id})
    expected_path = "/app/products/#{product.id}"

    assert {:error, {:live_redirect, %{to: ^expected_path}}} =
             live(conn, "/app/products?product_id=#{product.id}")
  end

  test "new product flow uploads images and redirects to the review page", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product_tab = product_tab_fixture(user, %{"name" => "Shoes"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, html} = live(conn, "/app/products/new")

    assert html =~ ~s(id="new-product-form")
    assert html =~ ~s(phx-change="sync_product_uploads")

    upload =
      file_input(view, "#new-product-form", :product_images, [
        %{
          name: "jacket.jpg",
          content: "fake-image-binary",
          type: "image/jpeg"
        }
      ])

    assert render_upload(upload, "jacket.jpg") =~ "jacket.jpg"

    view
    |> form("#new-product-form", product: %{"product_tab_id" => "#{product_tab.id}"})
    |> render_submit()

    [product] = Catalog.list_products_for_user(user)

    assert_redirect(view, "/app/products/#{product.id}")

    {:ok, review_view, _html} = live(conn, "/app/products/#{product.id}")

    assert has_element?(review_view, "#product-review-form")
    assert length(product.images) == 1
    assert hd(product.images).original_filename == "jacket.jpg"
    assert product.product_tab_id == product_tab.id
  end

  test "review page updates product details and lifecycle actions", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product_tab = product_tab_fixture(user, %{"name" => "Outerwear"})
    product = product_fixture(user, %{"title" => "Original product"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    view
    |> form("#product-review-form",
      product: %{
        status: "review",
        product_tab_id: "#{product_tab.id}",
        title: "Updated product",
        brand: "Nike",
        category: "Sneakers",
        tags: "running, retro",
        price: "125.00",
        cost: "85.00",
        notes: "Updated in browser"
      }
    )
    |> render_submit()

    updated_product = Catalog.get_product_for_user(user, product.id)
    assert updated_product.title == "Updated product"
    assert updated_product.brand == "Nike"
    assert updated_product.status == "review"
    assert updated_product.product_tab_id == product_tab.id
    assert updated_product.tags == ["running", "retro"]
    assert Decimal.equal?(updated_product.price, Decimal.new("125.00"))
    assert Decimal.equal?(updated_product.cost, Decimal.new("85.00"))

    view
    |> element(~s(button[phx-click="mark_sold"]))
    |> render_click()

    sold_product = Catalog.get_product_for_user(user, product.id)
    assert sold_product.status == "sold"

    view
    |> element(~s(button[phx-click="archive_product"]))
    |> render_click()

    archived_product = Catalog.get_product_for_user(user, product.id)
    assert archived_product.status == "archived"

    view
    |> element(~s(button[phx-click="restore_product"]))
    |> render_click()

    restored_product = Catalog.get_product_for_user(user, product.id)
    assert restored_product.status == "sold"
  end

  test "review page retries failed AI processing", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = retryable_failed_product_fixture(user)
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    assert has_element?(view, "#retry-processing-button")
    assert has_element?(view, "#product-processing-runs", "Gemini quota is exhausted right now.")

    view
    |> element("#retry-processing-button")
    |> render_click()

    assert has_element?(view, "#flash-info", "AI processing restarted with run #")

    refreshed_product = Catalog.get_product_for_user(user, product.id)
    assert List.first(refreshed_product.processing_runs).status == "completed"
  end

  test "review page seeds ai tags and renders copy controls for editable text fields", %{
    conn: conn
  } do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = variant_failure_product_fixture(user)
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    assert has_element?(view, "#product_tags")
    assert render(view) =~ "nike, sneakers, retro, runners, streetwear"
    assert has_element?(view, "#product_title-copy")
    assert has_element?(view, "#product_tags-copy")
    assert has_element?(view, "#product_notes-copy")
  end

  test "review page shows a visual pipeline tracker while processing", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = processing_product_fixture(user)
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    assert has_element?(view, "#product-pipeline-progress")
    assert has_element?(view, "#pipeline-progressbar[role=\"progressbar\"]")
    assert has_element?(view, "#pipeline-step-uploads-state", "Done")
    assert has_element?(view, "#pipeline-step-ai_extraction-state", "In progress")
    assert has_element?(view, "#pipeline-step-price_search-state", "Pending")
    assert has_element?(view, "#pipeline-step-lifestyle_previews-state", "Pending")
    assert render(view) =~ "reseller-progress-bar-active"
  end

  test "review page shows variant generation errors from processing runs", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = variant_failure_product_fixture(user)
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    assert has_element?(view, "#product-processing-runs")
    assert has_element?(view, "#product-pipeline-progress")
    assert has_element?(view, "#pipeline-step-marketplace_texts-state", "Done")
    assert has_element?(view, "#pipeline-step-image_processing-state", "Warning")
    assert has_element?(view, "#pipeline-step-review-state", "Done")
    assert has_element?(view, "#pipeline-step-lifestyle_previews-state", "Optional")
    assert has_element?(view, "#product-lifestyle-preview-empty")
    assert render(view) =~ "variants_failed"
  end

  test "review page renders marketplace listings as stacked cards with copy actions", %{
    conn: conn
  } do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = variant_failure_product_fixture(user)
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    [listing | _rest] = product.marketplace_listings

    assert has_element?(view, "#copy-marketplace-title-#{listing.id}", "Copy title")

    assert has_element?(
             view,
             "#copy-marketplace-description-#{listing.id}",
             "Copy description"
           )

    assert has_element?(view, "#marketplace-title-#{listing.id}", listing.generated_title)

    assert has_element?(
             view,
             "#marketplace-description-#{listing.id}",
             listing.generated_description
           )

    assert render(view) =~ "#nike"
    refute render(view) =~ "Hashtags"
  end

  test "review page saves storefront publishing and marketplace external URLs", %{conn: conn} do
    user = user_fixture(%{"email" => "storefront-review@example.com"})
    _storefront = storefront_fixture(user, %{"slug" => "seller-store", "title" => "Seller Store"})
    product = variant_failure_product_fixture(user)
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    assert has_element?(view, "#storefront-publication-enabled")
    refute has_element?(view, "#product-storefront-form")

    view |> element("#storefront-publication-enabled") |> render_click()

    assert has_element?(view, "#product-storefront-preview-url", "/store/seller-store/products/")
    assert has_element?(view, "#product-storefront-form")

    view
    |> form("#product-storefront-form", %{
      "storefront_publication" => %{
        "marketplace_urls" => %{
          "ebay" => "https://example.com/ebay/#{product.id}",
          "depop" => "https://example.com/depop/#{product.id}",
          "poshmark" => ""
        }
      }
    })
    |> render_submit()

    refreshed_product = Catalog.get_product_for_user(user, product.id)
    ebay_listing = Enum.find(refreshed_product.marketplace_listings, &(&1.marketplace == "ebay"))

    depop_listing =
      Enum.find(refreshed_product.marketplace_listings, &(&1.marketplace == "depop"))

    poshmark_listing =
      Enum.find(refreshed_product.marketplace_listings, &(&1.marketplace == "poshmark"))

    assert refreshed_product.storefront_enabled == true
    assert refreshed_product.storefront_published_at
    assert ebay_listing.external_url == "https://example.com/ebay/#{product.id}"
    assert depop_listing.external_url == "https://example.com/depop/#{product.id}"
    assert poshmark_listing.external_url == nil
    assert has_element?(view, "#flash-info", "Storefront publishing settings updated.")
    assert has_element?(view, "#product-storefront-badge", "Storefront enabled")
  end

  test "review page lets sellers delete old images and upload replacements", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = finalized_review_product_fixture(user)
    [original_image] = product.images

    assert {:ok, [_background_removed]} =
             Reseller.Media.generate_product_variants(product,
               public_base_url: "https://cdn.example.com/catalog",
               media_processor: Reseller.Support.Fakes.MediaProcessor,
               storage: Reseller.Support.Fakes.MediaStorage
             )

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    assert has_element?(view, "#product-image-group-#{original_image.id}")
    assert has_element?(view, "#delete-product-image-#{original_image.id}", "Delete")

    view
    |> element("#delete-product-image-#{original_image.id}")
    |> render_click()

    assert has_element?(view, "#product-image-gallery-empty")

    deleted_product = Catalog.get_product_for_user(user, product.id)
    assert deleted_product.status == "draft"
    assert deleted_product.images == []

    upload =
      file_input(view, "#product-image-upload-form", :product_images, [
        %{name: "replacement.jpg", content: "replacement-image-binary", type: "image/jpeg"}
      ])

    assert render_upload(upload, "replacement.jpg") =~ "replacement.jpg"

    view
    |> form("#product-image-upload-form")
    |> render_submit()

    assert has_element?(view, "#product-processing-banner")
    assert has_element?(view, "#flash-info", "Images uploaded. AI processing restarted.")

    uploaded_product = Catalog.get_product_for_user(user, product.id)

    assert uploaded_product.status == "processing"
    assert Enum.map(uploaded_product.images, & &1.kind) == ["original"]
    assert Enum.map(uploaded_product.images, & &1.original_filename) == ["replacement.jpg"]
  end

  test "review page shows lifestyle generation runs and generated image labels", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = lifestyle_generation_product_fixture(user)
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    assert has_element?(view, "#product-lifestyle-generation-runs")
    assert has_element?(view, "#pipeline-step-lifestyle_previews-state", "Done")
    assert has_element?(view, "#product-image-gallery", "Original")

    assert has_element?(
             view,
             "#product-lifestyle-preview-gallery",
             "AI-generated real-life preview"
           )

    assert render(view) =~ "Step 8 · Real-life previews"
    assert render(view) =~ "Lifestyle image runs"
  end

  test "review page can generate, approve, and delete lifestyle previews", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = finalized_review_product_fixture(user)
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products/#{product.id}")

    assert has_element?(view, "#generate-lifestyle-images-button", "Generate previews")

    view
    |> element("#generate-lifestyle-images-button")
    |> render_click()

    assert has_element?(view, "#product-lifestyle-preview-gallery")
    assert has_element?(view, "#product-lifestyle-generation-runs")

    refreshed_product = Catalog.get_product_for_user(user, product.id)
    generated_image = Enum.find(refreshed_product.images, &(&1.kind == "lifestyle_generated"))

    view
    |> element("#approve-lifestyle-image-#{generated_image.id}")
    |> render_click()

    assert has_element?(view, "#lifestyle-preview-image-#{generated_image.id}", "Approved")

    view
    |> element("#delete-lifestyle-image-#{generated_image.id}")
    |> render_click()

    refute has_element?(view, "#lifestyle-preview-image-#{generated_image.id}")
  end

  defp assert_in_order(html, first, second) do
    {first_index, _first_length} = :binary.match(html, first)
    {second_index, _second_length} = :binary.match(html, second)

    assert first_index < second_index
  end

  defp set_product_updated_at!(product, datetime) do
    from(p in Reseller.Catalog.Product, where: p.id == ^product.id)
    |> Repo.update_all(set: [updated_at: datetime])

    Repo.get!(Reseller.Catalog.Product, product.id)
  end

  defp retryable_failed_product_fixture(user) do
    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Quota limited jacket"},
        [%{"filename" => "item-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    {:ok, _failed_run} =
      Reseller.Workers.start_product_processing(finalized_product,
        processor: Reseller.Support.Fakes.ProductProcessor,
        processor_result:
          {:error,
           %{
             code: "ai_quota_exhausted",
             message: "Gemini quota is exhausted right now.",
             payload: %{"retryable" => true, "provider" => "gemini"}
           }}
      )

    Catalog.get_product_for_user(user, product.id)
  end

  defp processing_product_fixture(user) do
    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Processing product"},
        [%{"filename" => "item-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    from(p in Reseller.Catalog.Product, where: p.id == ^product.id)
    |> Repo.update_all(set: [status: "processing"])

    from(i in Reseller.Media.ProductImage, where: i.id == ^image.id)
    |> Repo.update_all(set: [processing_status: "processing"])

    Catalog.get_product_for_user(user, product.id)
  end

  defp variant_failure_product_fixture(user) do
    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Variant failure item"},
        [%{"filename" => "item-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    {:ok, _run} =
      Reseller.Workers.start_product_processing(finalized_product,
        processor: Reseller.Workers.AIProductProcessor,
        public_base_url: "https://cdn.example.com/catalog",
        ai_provider: Reseller.Support.Fakes.AIProvider,
        search_provider: Reseller.Support.Fakes.SearchProvider,
        media_processor: Reseller.Support.Fakes.MediaProcessor,
        storage: Reseller.Support.Fakes.MediaStorage,
        recognize_result:
          {:ok,
           %{
             provider: :gemini,
             output: %{
               "brand" => "Nike",
               "category" => "Sneakers",
               "possible_model" => "Air Max 90",
               "confidence_score" => 0.91,
               "needs_review" => false
             }
           }},
        description_result:
          {:ok,
           %{
             provider: :gemini,
             model: "gemini-description",
             output: %{
               "suggested_title" => "Nike Air Max 90",
               "short_description" => "Retro runners streetwear"
             }
           }},
        shopping_result: {:ok, %{provider: :serp_api, matches: []}},
        price_result:
          {:ok,
           %{
             provider: :gemini,
             model: "gemini-pricing",
             output: %{
               "currency" => "USD",
               "suggested_target_price" => 125,
               "pricing_confidence" => 0.8
             }
           }},
        marketplace_listing_results: %{
          "ebay" =>
            {:ok,
             %{
               provider: :gemini,
               model: "gemini-marketplace",
               output: %{
                 "generated_title" => "eBay title",
                 "generated_description" => "desc",
                 "generated_tags" => ["nike", "sneakers", "streetwear"],
                 "generated_price_suggestion" => 125
               }
             }},
          "depop" =>
            {:ok,
             %{
               provider: :gemini,
               model: "gemini-marketplace",
               output: %{
                 "generated_title" => "Depop title",
                 "generated_description" => "desc",
                 "generated_tags" => ["nike", "runners", "y2k"],
                 "generated_price_suggestion" => 124
               }
             }},
          "poshmark" =>
            {:ok,
             %{
               provider: :gemini,
               model: "gemini-marketplace",
               output: %{
                 "generated_title" => "Poshmark title",
                 "generated_description" => "desc",
                 "generated_tags" => ["nike", "chunky", "athleisure"],
                 "generated_price_suggestion" => 126
               }
             }}
        },
        variant_result: {:error, {:missing_api_key, :photoroom}}
      )

    Catalog.get_product_for_user(user, product.id)
  end

  defp lifestyle_generation_product_fixture(user) do
    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Lifestyle sample"},
        [%{"filename" => "item-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    {:ok, run} =
      Reseller.AI.create_product_lifestyle_generation_run(finalized_product, %{
        "status" => "completed",
        "step" => "lifestyle_generated",
        "scene_family" => "apparel",
        "model" => "gemini-2.5-flash-image",
        "prompt_version" => "v1",
        "requested_count" => 1,
        "completed_count" => 1,
        "payload" => %{"summary" => "Generated one lifestyle preview."}
      })

    {:ok, _generated_image} =
      Reseller.Media.create_lifestyle_generated_image(finalized_product, %{
        "storage_key" =>
          "users/#{user.id}/products/#{finalized_product.id}/generated/preview-1.png",
        "content_type" => "image/png",
        "byte_size" => 321_000,
        "checksum" => "preview123",
        "width" => 1024,
        "height" => 1280,
        "original_filename" => "preview-1.png",
        "lifestyle_generation_run_id" => run.id,
        "scene_key" => "model_studio",
        "variant_index" => 1,
        "source_image_ids" => [image.id]
      })

    Catalog.get_product_for_user(user, finalized_product.id)
  end

  defp finalized_review_product_fixture(user) do
    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Manual lifestyle review"},
        [%{"filename" => "item-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    from(p in Reseller.Catalog.Product, where: p.id == ^finalized_product.id)
    |> Repo.update_all(set: [status: "ready"])

    from(i in Reseller.Media.ProductImage, where: i.product_id == ^finalized_product.id)
    |> Repo.update_all(set: [processing_status: "ready"])

    Catalog.get_product_for_user(user, finalized_product.id)
  end
end
