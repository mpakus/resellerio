defmodule ResellerWeb.Auth.SignInLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the sign in page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sign-in")

    assert has_element?(view, "#sign-in-form")
    assert has_element?(view, "#sign-in-submit")
    assert render(view) =~ "Return to your reseller workspace"
  end
end
