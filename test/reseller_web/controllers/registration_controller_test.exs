defmodule ResellerWeb.RegistrationControllerTest do
  use ResellerWeb.ConnCase, async: true

  alias Phoenix.Flash

  test "POST /sign-up creates a browser session", %{conn: conn} do
    conn =
      post(conn, ~p"/sign-up", %{
        "user" => %{
          "email" => "seller@example.com",
          "password" => "very-secure-password"
        }
      })

    assert redirected_to(conn) == ~p"/app"
    assert get_session(conn, :user_id)
    assert Flash.get(conn.assigns.flash, :info) == "Account created. Welcome to Reseller Web."
  end

  test "POST /sign-up ignores admin escalation params", %{conn: conn} do
    conn =
      post(conn, ~p"/sign-up", %{
        "user" => %{
          "email" => "seller@example.com",
          "password" => "very-secure-password",
          "is_admin" => true
        }
      })

    user_id = get_session(conn, :user_id)

    assert redirected_to(conn) == ~p"/app"
    refute Reseller.Accounts.get_user!(user_id).is_admin
  end

  test "POST /sign-up redirects back with an error when invalid", %{conn: conn} do
    conn =
      post(conn, ~p"/sign-up", %{
        "user" => %{
          "email" => "bad-email",
          "password" => "short"
        }
      })

    assert redirected_to(conn) == ~p"/sign-up"

    assert Flash.get(conn.assigns.flash, :error) ==
             "Could not create your account. Check your email and password."
  end
end
