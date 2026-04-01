defmodule ResellerWeb.Admin.ApiUsageEventLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "access control" do
    test "redirects unauthenticated users to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/admin/api-usage-events")
    end

    test "redirects non-admin users to /app", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      assert {:error, {:redirect, %{to: "/app"}}} = live(conn, "/admin/api-usage-events")
    end

    test "renders the event list for admin users", %{conn: conn} do
      admin = admin_user_fixture()
      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, _view, html} = live(conn, "/admin/api-usage-events")

      assert html =~ "API Usage Events"
    end
  end

  describe "event listing" do
    test "shows events in the index", %{conn: conn} do
      admin = admin_user_fixture()
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product)
      serp_api_event_fixture(user, product)

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, _view, html} = live(conn, "/admin/api-usage-events")

      assert html =~ "API Usage Events"
    end

    test "shows event detail on show page", %{conn: conn} do
      admin = admin_user_fixture()
      user = user_fixture()
      product = product_fixture(user)

      event = gemini_event_fixture(user, product)

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, _view, html} = live(conn, "/admin/api-usage-events/#{event.id}/show")

      assert html =~ "gemini"
    end
  end
end
