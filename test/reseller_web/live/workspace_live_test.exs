defmodule ResellerWeb.WorkspaceLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Reseller.Catalog
  alias Reseller.Exports
  alias Reseller.Imports

  test "redirects unauthenticated users to sign in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/app")
  end

  test "renders the authenticated workspace shell and sidebar destinations", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app")

    assert has_element?(view, "#workspace-heading")
    assert has_element?(view, "#workspace-user-email")
    assert has_element?(view, "#workspace-dashboard")
    assert has_element?(view, ~s(a[href="/app/products"]))
    assert has_element?(view, ~s(a[href="/app/listings"]))
    assert has_element?(view, ~s(a[href="/app/exports"]))
    assert has_element?(view, ~s(a[href="/app/settings"]))
    assert render(view) =~ "seller@example.com"
  end

  test "sidebar menu patches between workspace sections", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app")

    assert has_element?(view, "#workspace-dashboard")

    view
    |> element(~s(aside a[href="/app/products"]))
    |> render_click()

    assert_patch(view, "/app/products")
    assert has_element?(view, "#workspace-products")
    assert has_element?(view, "#new-product-form")
    assert has_element?(view, "#product-images-upload-panel")

    view
    |> element(~s(aside a[href="/app/listings"]))
    |> render_click()

    assert_patch(view, "/app/listings")
    assert has_element?(view, "#workspace-listings")

    view
    |> element(~s(aside a[href="/app/exports"]))
    |> render_click()

    assert_patch(view, "/app/exports")
    assert has_element?(view, "#workspace-exports")
    assert has_element?(view, "#request-export-button")
    assert has_element?(view, "#import-archive-upload-panel")

    view
    |> element(~s(aside a[href="/app/settings"]))
    |> render_click()

    assert_patch(view, "/app/settings")
    assert has_element?(view, "#workspace-settings")

    view
    |> element(~s(aside a[href="/app"]))
    |> render_click()

    assert_patch(view, "/app")
    assert has_element?(view, "#workspace-dashboard")
  end

  test "creates a product with uploaded photos from the web UI", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products")

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
    |> form("#new-product-form",
      product: %{
        title: "Web Jacket",
        brand: "Levi's",
        category: "Outerwear",
        price: "79.00",
        notes: "Created from LiveView"
      }
    )
    |> render_submit()

    [product] = Catalog.list_products_for_user(user)

    assert_patch(view, "/app/products?product_id=#{product.id}")
    assert product.title == "Web Jacket"
    assert length(product.images) == 1
    assert has_element?(view, "#selected-product-card")
    assert has_element?(view, "#product-images-upload-panel")
    assert render(view) =~ "Web Jacket"
    assert hd(product.images).original_filename == "jacket.jpg"
  end

  test "edits and updates product lifecycle from the web UI", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = product_fixture(user, %{"title" => "Original product"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products?product_id=#{product.id}")

    view
    |> form("#product-edit-form",
      product_update: %{
        title: "Updated product",
        brand: "Nike",
        category: "Sneakers",
        notes: "Updated in browser"
      }
    )
    |> render_submit()

    updated_product = Catalog.get_product_for_user(user, product.id)
    assert updated_product.title == "Updated product"
    assert updated_product.brand == "Nike"

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

  test "filters products by status and ignores another user's product selection", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    ready_product = product_fixture(user, %{"title" => "Ready coat", "status" => "ready"})
    _sold_product = product_fixture(user, %{"title" => "Sold shoes", "status" => "sold"})
    other_user = user_fixture(%{"email" => "other@example.com"})

    other_product =
      product_fixture(other_user, %{"title" => "Other user item", "status" => "ready"})

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products?status=ready&product_id=#{other_product.id}")

    assert has_element?(view, "#workspace-products-table", "Ready coat")
    refute has_element?(view, "#workspace-products-table", "Sold shoes")
    refute render(view) =~ "Other user item"
    assert render(view) =~ "Ready coat"

    view
    |> element("#product-filters a", "Sold")
    |> render_click()

    assert_patch(view, "/app/products?product_id=#{ready_product.id}&status=sold")
    assert has_element?(view, "#workspace-products-table", "Sold shoes")
    refute has_element?(view, "#workspace-products-table", "Ready coat")
    refute render(view) =~ "Other user item"
    assert ready_product.id != other_product.id
  end

  test "deletes the selected product from the web UI", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product = product_fixture(user, %{"title" => "Delete me"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/products?product_id=#{product.id}")

    assert has_element?(view, "#selected-product-card", "Delete me")

    view
    |> element(~s(button[phx-click="delete_product"]))
    |> render_click()

    assert Catalog.get_product_for_user(user, product.id) == nil
    refute has_element?(view, "#workspace-products-table", "Delete me")
    assert has_element?(view, "#selected-product-card", "Pick a product from the list")
  end

  test "requests exports and uploads imports from the web UI", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product_fixture(user, %{"title" => "Export candidate"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/exports")

    assert has_element?(view, "#import-archive-upload-panel")

    view
    |> element("#request-export-button")
    |> render_click()

    [export] = Exports.list_exports_for_user(user)
    assert export.status == "completed"
    assert render(view) =~ "Export ##{export.id}"

    upload =
      file_input(view, "#import-archive-form", :import_archive, [
        %{
          name: "catalog-import.zip",
          content: import_zip_binary(),
          type: "application/zip"
        }
      ])

    assert render_upload(upload, "catalog-import.zip") =~ "catalog-import.zip"

    view
    |> form("#import-archive-form")
    |> render_submit()

    [import_record] = Imports.list_imports_for_user(user)

    assert import_record.status == "completed"
    assert import_record.source_filename == "catalog-import.zip"
    assert Enum.any?(Catalog.list_products_for_user(user), &(&1.title == "Imported trench coat"))
    assert render(view) =~ "catalog-import.zip"
  end

  test "shows an error when import is submitted without an archive", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/exports")

    view
    |> form("#import-archive-form")
    |> render_submit()

    assert has_element?(view, "#flash-error", "Choose a ZIP archive before starting an import.")
  end

  test "direct workspace routes render their matching sections", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    assert_route_section(conn, "/app/products", "#workspace-products")
    assert_route_section(conn, "/app/listings", "#workspace-listings")
    assert_route_section(conn, "/app/exports", "#workspace-exports")
    assert_route_section(conn, "/app/settings", "#workspace-settings")
  end

  defp assert_route_section(conn, path, selector) do
    {:ok, view, _html} = live(conn, path)
    assert has_element?(view, selector)
  end

  defp import_zip_binary do
    index_json =
      Jason.encode!(%{
        "products" => [
          %{
            "title" => "Imported trench coat",
            "brand" => "Burberry",
            "category" => "Outerwear",
            "status" => "ready",
            "images" => []
          }
        ]
      })

    {:ok, {_name, zip_binary}} =
      :zip.create(~c"catalog-import.zip", [{~c"index.json", index_json}], [:memory])

    zip_binary
  end
end
