defmodule ResellerWeb.Admin.UserLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "redirects unauthenticated users to sign in", %{conn: conn} do
    conn = get(conn, "/admin/users/")

    assert redirected_to(conn) == ~p"/sign-in"
  end

  test "redirects non-admin users to the app shell", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})

    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> get("/admin/users/")

    assert redirected_to(conn) == ~p"/app"
  end

  test "renders the users admin resource for admin users", %{conn: conn} do
    user = admin_user_fixture(%{"email" => "admin@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/admin/users/")

    assert has_element?(view, "main")
    assert has_element?(view, "a[href='/admin/users/#{user.id}/show']")
    assert has_element?(view, "main", "admin@example.com")
  end

  test "renders the user show page for admins", %{conn: conn} do
    admin_user = admin_user_fixture(%{"email" => "admin@example.com"})
    managed_user = user_fixture(%{"email" => "managed@example.com"})
    conn = init_test_session(conn, %{user_id: admin_user.id})

    {:ok, view, _html} = live(conn, "/admin/users/#{managed_user.id}/show")

    assert has_element?(view, "main")
    assert has_element?(view, "main", "managed@example.com")
  end

  test "renders the user edit page for admins", %{conn: conn} do
    admin_user = admin_user_fixture(%{"email" => "admin@example.com"})
    managed_user = user_fixture(%{"email" => "managed@example.com"})
    conn = init_test_session(conn, %{user_id: admin_user.id})

    {:ok, view, _html} = live(conn, "/admin/users/#{managed_user.id}/edit")

    assert has_element?(view, "form")
    assert has_element?(view, "button[type='submit']")
  end
end
