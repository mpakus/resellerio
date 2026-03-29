defmodule ResellerWeb.Auth.SignInLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Reseller.Accounts

  test "renders the sign in page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sign-in")

    assert has_element?(view, "#sign-in-form")
    assert has_element?(view, "#sign-in-submit")
    assert render(view) =~ "Return to your reseller workspace"
  end

  test "redirects authenticated users to the app shell", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "email" => "seller@example.com",
        "password" => "very-secure-password"
      })

    conn = init_test_session(conn, %{user_id: user.id})

    assert {:error, {:redirect, %{to: "/app"}}} = live(conn, "/sign-in")
  end
end
