defmodule ResellerWeb.WorkspaceLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Reseller.Accounts

  test "redirects unauthenticated users to sign in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/app")
  end

  test "renders the authenticated workspace shell", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "email" => "seller@example.com",
        "password" => "very-secure-password"
      })

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/app")

    assert has_element?(view, "#workspace-heading")
    assert has_element?(view, "#workspace-user-email")
    assert render(view) =~ "seller@example.com"
  end
end
