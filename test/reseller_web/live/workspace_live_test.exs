defmodule ResellerWeb.WorkspaceLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "redirects unauthenticated users to sign in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/app")
  end

  test "renders the authenticated workspace shell", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app")

    assert has_element?(view, "#workspace-heading")
    assert has_element?(view, "#workspace-dashboard")
    assert has_element?(view, "#workspace-user-email")
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
end
