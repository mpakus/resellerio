defmodule ResellerWeb.APIDocsLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders homepage section links in the shared header", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/docs/api")

    assert has_element?(view, ~s(a[href="/#workflow"]), "Workflow")
    assert has_element?(view, ~s(a[href="/#features"]), "Features")
    assert has_element?(view, ~s(a[href="/#lifestyle"]), "Lifestyle AI")
    assert has_element?(view, ~s(a[href="/#marketplace-strip"]), "Markets")
    assert has_element?(view, ~s(a[href="/#storefront"]), "Storefront")
  end

  test "links to the mobile API guide resource", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/docs/api")

    assert has_element?(view, ~s(a[href="/docs/mobile-api"]), "Mobile API Guide")
  end
end
