defmodule ResellerWeb.Auth.SignUpLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Reseller.Accounts

  test "renders the sign up page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sign-up")

    assert has_element?(view, "#sign-up-form")
    assert has_element?(view, "#sign-up-submit")
    assert render(view) =~ "Create your account"
  end

  test "redirects authenticated users to the app shell", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "email" => "seller@example.com",
        "password" => "very-secure-password"
      })

    conn = init_test_session(conn, %{user_id: user.id})

    assert {:error, {:redirect, %{to: "/app"}}} = live(conn, "/sign-up")
  end
end
