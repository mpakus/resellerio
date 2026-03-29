defmodule ResellerWeb.SessionControllerTest do
  use ResellerWeb.ConnCase, async: true

  alias Reseller.Accounts
  alias Phoenix.Flash

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        "email" => "seller@example.com",
        "password" => "very-secure-password"
      })

    %{user: user}
  end

  test "POST /sign-in creates a browser session", %{conn: conn} do
    conn =
      post(conn, ~p"/sign-in", %{
        "session" => %{
          "email" => "seller@example.com",
          "password" => "very-secure-password"
        }
      })

    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, :user_id)
    assert Flash.get(conn.assigns.flash, :info) == "Welcome back."
  end

  test "POST /sign-in redirects back on invalid credentials", %{conn: conn} do
    conn =
      post(conn, ~p"/sign-in", %{
        "session" => %{
          "email" => "seller@example.com",
          "password" => "wrong-password"
        }
      })

    assert redirected_to(conn) == ~p"/sign-in"
    assert Flash.get(conn.assigns.flash, :error) == "Invalid email or password."
  end

  test "DELETE /sign-out clears the browser session", %{conn: conn, user: user} do
    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> delete(~p"/sign-out")

    assert redirected_to(conn) == ~p"/"
    assert conn.private[:plug_session_info] == :drop
    assert Flash.get(conn.assigns.flash, :info) == "Signed out."
  end
end
