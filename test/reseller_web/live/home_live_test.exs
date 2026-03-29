defmodule ResellerWeb.HomeLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the reseller landing page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#home-hero")
    assert has_element?(view, "#hero-primary-cta")
    assert has_element?(view, "#workflow")
    assert has_element?(view, "#home-final-cta")
    assert render(view) =~ "Turn a pile of photos into clean listings ready for every market."
  end
end
