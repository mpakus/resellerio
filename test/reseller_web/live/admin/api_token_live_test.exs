defmodule ResellerWeb.Admin.ApiTokenLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the api tokens admin resource for admin users", %{conn: conn} do
    user = admin_user_fixture(%{"email" => "admin@example.com"})
    {_raw_token, api_token} = api_token_fixture(user, %{"device_name" => "MacBook"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/admin/api-tokens/")

    assert has_element?(view, "main")
    assert has_element?(view, "a[href='/admin/api-tokens/#{api_token.id}/show']")
    assert has_element?(view, "main", "MacBook")
  end

  test "redirects non-admin users away from api token admin pages", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> get("/admin/api-tokens/")

    assert redirected_to(conn) == "/app"
  end

  test "renders the api token show page for admins", %{conn: conn} do
    user = admin_user_fixture(%{"email" => "admin@example.com"})
    {_raw_token, api_token} = api_token_fixture(user, %{"device_name" => "MacBook"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/admin/api-tokens/#{api_token.id}/show")

    assert has_element?(view, "main")
    assert has_element?(view, "main", "MacBook")
    assert has_element?(view, "code")
  end
end
