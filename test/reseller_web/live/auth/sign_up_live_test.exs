defmodule ResellerWeb.Auth.SignUpLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the sign up page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sign-up")

    assert has_element?(view, "#sign-up-form")
    assert has_element?(view, "#sign-up-submit")
    assert render(view) =~ "Create your account"
  end
end
