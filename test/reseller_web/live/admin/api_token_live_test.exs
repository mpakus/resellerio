defmodule ResellerWeb.Admin.ApiTokenLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Reseller.Accounts

  test "renders the api tokens admin resource for admin users", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "email" => "admin@example.com",
        "password" => "very-secure-password"
      })

    {:ok, _admin_user} = Accounts.grant_admin(user)
    {:ok, _raw_token, _api_token} = Accounts.issue_api_token(user, %{"device_name" => "MacBook"})

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(conn, "/admin/api-tokens/")

    assert render(view) =~ "API Tokens"
    assert render(view) =~ "MacBook"
  end
end
