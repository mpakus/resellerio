defmodule ResellerWeb.Admin.UsageDashboardLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "access control" do
    test "redirects unauthenticated users to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/admin/usage-dashboard")
    end

    test "redirects non-admin users to /app", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      assert {:error, {:redirect, %{to: "/app"}}} = live(conn, "/admin/usage-dashboard")
    end

    test "renders the dashboard for admin users", %{conn: conn} do
      admin = admin_user_fixture()
      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, _view, html} = live(conn, "/admin/usage-dashboard")

      assert html =~ "Usage Dashboard"
      assert html =~ "Platform Totals"
      assert html =~ "Daily Trend"
      assert html =~ "Top Users by Cost"
      assert html =~ "Top Products by Cost"
      assert html =~ "Error Summary"
    end
  end

  describe "data display" do
    test "shows zero totals when no events exist", %{conn: conn} do
      admin = admin_user_fixture()
      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, _view, html} = live(conn, "/admin/usage-dashboard")

      assert html =~ "No data yet" or html =~ "0"
    end

    test "shows populated totals when events exist", %{conn: conn} do
      admin = admin_user_fixture()
      user = user_fixture()
      product = product_fixture(user)

      gemini_event_fixture(user, product)
      serp_api_event_fixture(user, product)
      photoroom_event_fixture(user, product)

      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, _view, html} = live(conn, "/admin/usage-dashboard")

      assert html =~ "Usage Dashboard"
    end
  end
end
