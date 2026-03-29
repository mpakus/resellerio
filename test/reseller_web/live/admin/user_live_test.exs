defmodule ResellerWeb.Admin.UserLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Reseller.Accounts

  test "redirects unauthenticated users to sign in", %{conn: conn} do
    conn = get(conn, "/admin/users/")

    assert redirected_to(conn) == ~p"/sign-in"
  end

  test "redirects non-admin users to the app shell", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "email" => "seller@example.com",
        "password" => "very-secure-password"
      })

    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> get("/admin/users/")

    assert redirected_to(conn) == ~p"/app"
  end

  test "renders the users admin resource for admin users", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "email" => "admin@example.com",
        "password" => "very-secure-password"
      })

    {:ok, _admin_user} = Accounts.grant_admin(user)

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/admin/users/")

    assert render(view) =~ "Users"
    assert render(view) =~ "admin@example.com"
  end
end
