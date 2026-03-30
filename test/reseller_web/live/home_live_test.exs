defmodule ResellerWeb.HomeLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the Resellerio landing page", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")

    assert has_element?(view, "#home-hero")
    assert has_element?(view, "#hero-primary-cta")
    assert has_element?(view, ~s(a[href="/sign-up"]#hero-primary-cta))
    assert has_element?(view, "#workflow")
    assert has_element?(view, "#home-final-cta")
    assert has_element?(view, "#home-slogan")
    assert render(view) =~ "Turn a pile of photos into clean listings ready for every market."
    assert html =~ "Home - Marketing - Resellio - AI Inventory for Resellers"
  end

  test "renders workspace CTA for authenticated users", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, ~s(a[href="/app"]#hero-primary-cta))
    refute has_element?(view, ~s(a[href="/sign-up"]#hero-primary-cta))
  end
end
