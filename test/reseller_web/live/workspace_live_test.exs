defmodule ResellerWeb.WorkspaceLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Reseller.Catalog
  alias Reseller.Accounts
  alias Reseller.Exports
  alias Reseller.Exports.Export
  alias Reseller.Imports
  alias Reseller.Repo
  alias Reseller.Storefronts

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
    |> element(~s(aside a[href="/app/exports"]))
    |> render_click()

    assert_redirect(products_view, "/app/exports")

    {:ok, view, _html} = live(conn, "/app/exports")

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

  test "reclassifies stale exports on the workspace exports screen", %{conn: conn} do
    user = user_fixture(%{"email" => "seller-stalled@example.com"})
    stale_time = ~U[2026-03-31 05:00:00Z]

    export =
      %Export{}
      |> Export.create_changeset(%{
        "name" => "Stale export",
        "file_name" => "stale-export.zip",
        "filter_params" => %{},
        "product_count" => 3,
        "status" => "running",
        "requested_at" => stale_time
      })
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Repo.insert!()

    from(record in Export, where: record.id == ^export.id)
    |> Repo.update_all(set: [updated_at: stale_time])

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/exports")

    assert has_element?(view, "#workspace-exports", "stalled")

    assert has_element?(
             view,
             "#workspace-exports",
             "Export has been running for more than 10 minutes without finishing. It was marked as stalled."
           )
  end

  test "re-runs stalled exports from the workspace exports screen", %{conn: conn} do
    user = user_fixture(%{"email" => "seller-rerun@example.com"})
    product_fixture(user, %{"title" => "Retryable export product", "status" => "ready"})
    stale_time = ~U[2026-03-31 05:00:00Z]

    export =
      %Export{}
      |> Export.create_changeset(%{
        "name" => "Retryable export",
        "file_name" => "retryable-export.zip",
        "filter_params" => %{"query" => "Retryable"},
        "product_count" => 1,
        "status" => "stalled",
        "requested_at" => stale_time,
        "error_message" =>
          "Export has been running for more than 10 minutes without finishing. It was marked as stalled."
      })
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Repo.insert!()

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/exports")

    assert has_element?(view, ~s(button[phx-click="rerun_export"][phx-value-id="#{export.id}"]))

    view
    |> element(~s(button[phx-click="rerun_export"][phx-value-id="#{export.id}"]))
    |> render_click()

    assert has_element?(view, "#flash-info", "Export restarted as job #")

    [latest_export, stale_export] = Exports.list_exports_for_user(user)
    assert latest_export.id != stale_export.id
    assert latest_export.name == "Retryable export"
    assert latest_export.filter_params == %{"query" => "Retryable"}
    assert latest_export.status == "completed"
    assert stale_export.id == export.id
    assert stale_export.status == "stalled"
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

    assert_route_section(conn, "/app/exports", "#workspace-exports")
    assert_route_section(conn, "/app/settings", "#workspace-settings")
  end

  test "legacy listings route redirects to products", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})

    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> get("/app/listings")

    assert redirected_to(conn) == "/app/products"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Listings moved to Products."
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

  test "saves storefront settings from the settings screen", %{conn: conn} do
    user = user_fixture(%{"email" => "storefront@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/settings")

    assert has_element?(view, "#storefront-settings-form")

    view
    |> form("#storefront-settings-form", %{
      "storefront" => %{
        "enabled" => "true",
        "title" => "Seller Archive",
        "slug" => "seller-archive",
        "tagline" => "Curated outerwear",
        "description" => "Vintage and modern pieces.",
        "theme_id" => "linen-ink"
      }
    })
    |> render_submit()

    storefront = Storefronts.get_storefront_for_user(user)

    assert storefront.enabled == true
    assert storefront.title == "Seller Archive"
    assert storefront.slug == "seller-archive"
    assert storefront.theme_id == "linen-ink"
    assert has_element?(view, "#flash-info", "Storefront settings saved.")
    assert has_element?(view, "#storefront-preview-url", "/store/seller-archive")
  end

  test "creates and reorders storefront pages from the settings screen", %{conn: conn} do
    user = user_fixture(%{"email" => "pages@example.com"})
    _storefront = storefront_fixture(user, %{"slug" => "pages-store"})
    first_page = storefront_page_fixture(user, %{"title" => "About", "body" => "About copy"})

    second_page =
      storefront_page_fixture(user, %{"title" => "Shipping", "body" => "Shipping copy"})

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app/settings")

    assert has_element?(view, "#storefront-page-#{first_page.id}", "About")
    assert has_element?(view, "#storefront-page-#{second_page.id}", "Shipping")

    view
    |> element("#open-storefront-page-modal-button")
    |> render_click()

    assert has_element?(view, "#storefront-page-form")

    view
    |> form("#storefront-page-form", %{
      "storefront_page" => %{
        "title" => "Returns",
        "slug" => "returns",
        "menu_label" => "Returns",
        "body" => "Return within 14 days.",
        "published" => "true"
      }
    })
    |> render_submit()

    assert has_element?(view, "#storefront-pages-list", "Returns")

    view
    |> element(
      ~s(button[phx-click="move_storefront_page"][phx-value-id="#{first_page.id}"][phx-value-direction="down"])
    )
    |> render_click()

    assert Enum.map(Storefronts.list_storefront_pages_for_user(user), & &1.title) == [
             "Shipping",
             "About",
             "Returns"
           ]
  end

  test "uploads storefront logo assets from the settings screen", %{conn: conn} do
    user = user_fixture(%{"email" => "branding@example.com"})
    _storefront = storefront_fixture(user, %{"slug" => "branding-store"})
    conn = init_test_session(conn, %{user_id: user.id})

    with_fake_media_storage(fn ->
      {:ok, view, _html} = live(conn, "/app/settings")

      upload =
        file_input(view, "#storefront-logo-form", :storefront_logo, [
          %{
            name: "logo.png",
            content: "fake-logo-binary",
            type: "image/png"
          }
        ])

      render_upload(upload, "logo.png")

      asset = Storefronts.get_storefront_asset_for_user(user, "logo")

      assert asset
      assert asset.content_type == "image/png"
      assert has_element?(view, "#flash-info", "Logo uploaded.")
    end)
  end

  defp assert_route_section(conn, path, selector) do
    {:ok, view, _html} = live(conn, path)
    assert has_element?(view, selector)
  end

  defp with_fake_media_storage(fun) do
    previous_media = Application.get_env(:reseller, Reseller.Media)

    Application.put_env(
      :reseller,
      Reseller.Media,
      Keyword.put(previous_media, :storage, Reseller.Support.Fakes.MediaStorage)
    )

    try do
      fun.()
    after
      Application.put_env(:reseller, Reseller.Media, previous_media)
    end
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
