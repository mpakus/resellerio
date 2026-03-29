defmodule ResellerWeb.Admin.RedirectControllerTest do
  use ResellerWeb.ConnCase, async: true

  test "redirects admins to the users resource", %{conn: conn} do
    admin_user = admin_user_fixture()

    conn =
      conn
      |> init_test_session(%{user_id: admin_user.id})
      |> get("/admin")

    assert redirected_to(conn) == "/admin/users/"
  end

  test "redirects unauthenticated users to sign in", %{conn: conn} do
    conn = get(conn, "/admin")

    assert redirected_to(conn) == "/sign-in"
  end

  test "redirects non-admin users back to the app shell", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> get("/admin")

    assert redirected_to(conn) == "/app"
  end
end
