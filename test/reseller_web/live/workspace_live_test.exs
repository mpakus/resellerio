defmodule ResellerWeb.WorkspaceLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Reseller.Catalog
  alias Reseller.Accounts
  alias Reseller.Exports
  alias Reseller.Imports

  test "redirects unauthenticated users to sign in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/app")
  end

  test "renders the authenticated workspace shell and sidebar destinations", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, html} = live(conn, "/app")

    assert has_element?(view, "#workspace-heading")
    assert has_element?(view, "#workspace-user-email")
    assert has_element?(view, "#workspace-dashboard")
    assert has_element?(view, ~s(a[href="/app/products"]))
    assert has_element?(view, ~s(a[href="/app/listings"]))
    assert has_element?(view, ~s(a[href="/app/exports"]))
    assert has_element?(view, ~s(a[href="/app/settings"]))
    assert render(view) =~ "seller@example.com"
    assert html =~ "Dashboard - Workspace - Resellio - AI Inventory for Resellers"
  end

  test "sidebar menu switches between workspace sections and products index", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app")

    assert has_element?(view, "#workspace-dashboard")

    view
    |> element(~s(aside a[href="/app/products"]))
    |> render_click()

    assert_redirect(view, "/app/products")

    {:ok, products_view, _html} = live(conn, "/app/products")

    assert has_element?(products_view, "#workspace-products")
    assert has_element?(products_view, "#workspace-products-table")
    assert has_element?(products_view, ~s(a[href="/app/products/new"]))

    products_view
    |> element(~s(aside a[href="/app/listings"]))
    |> render_click()

    assert_redirect(products_view, "/app/listings")

    {:ok, view, _html} = live(conn, "/app/listings")

    assert has_element?(view, "#workspace-listings")

    view
    |> element(~s(aside a[href="/app/exports"]))
    |> render_click()

    assert_patch(view, "/app/exports")
    assert has_element?(view, "#workspace-exports")
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

  test "shows export history and uploads imports from the web UI", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    product_fixture(user, %{"title" => "Export candidate"})

    {:ok, _export} =
      Exports.request_export_for_user(user,
        name: "Candidate export",
        filters: %{"query" => "candidate"}
      )

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, html} = live(conn, "/app/exports")

    assert has_element?(view, "#import-archive-upload-panel")
    assert html =~ ~s(id="import-archive-form")
    assert html =~ ~s(phx-change="sync_import_upload")
    assert render(view) =~ "Candidate export"
    assert render(view) =~ "Search: candidate"

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

    assert_route_section(conn, "/app/listings", "#workspace-listings")
    assert_route_section(conn, "/app/exports", "#workspace-exports")
    assert_route_section(conn, "/app/settings", "#workspace-settings")
  end

  test "updates marketplace defaults from the settings screen", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/settings")

    assert has_element?(view, "#marketplace-settings-form")
    assert has_element?(view, "#selected-marketplace-count", "3 selected")

    view
    |> form("#marketplace-settings-form", %{
      "settings" => %{
        "selected_marketplaces" => ["ebay", "mercari", "etsy"]
      }
    })
    |> render_submit()

    assert has_element?(
             view,
             "#flash-info",
             "Marketplace defaults updated for future processing runs."
           )

    assert has_element?(view, "#selected-marketplace-count", "3 selected")

    assert Accounts.get_user!(user.id).selected_marketplaces == ["ebay", "mercari", "etsy"]
  end

  defp assert_route_section(conn, path, selector) do
    {:ok, view, _html} = live(conn, path)
    assert has_element?(view, selector)
  end

  defp import_zip_binary do
    manifest_json =
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
      :zip.create(
        ~c"catalog-import.zip",
        [
          {~c"manifest.json", manifest_json},
          {~c"Products.xls", "<Workbook></Workbook>"}
        ],
        [:memory]
      )

    zip_binary
  end
end
