defmodule ResellerWeb.InquiriesLiveTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "redirects unauthenticated users to sign in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/app/inquiries")
  end

  test "renders the inquiries page with nav link and empty state", %{conn: conn} do
    user = user_fixture(%{"email" => "inq-empty@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, view, html} = live(conn, "/app/inquiries")

    assert html =~ "Inquiries from visitors."
    assert has_element?(view, "#inquiries-heading")
    assert has_element?(view, "#inquiries-total-count", "0 total")
    assert has_element?(view, ~s(a[href="/app/inquiries"]))
    assert render(view) =~ "No inquiries yet"
  end

  test "renders inquiries list with name, contact, message, and source path", %{conn: conn} do
    user = user_fixture(%{"email" => "inq-list@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})
    _storefront = storefront_fixture(user, %{"slug" => "inq-list-store", "enabled" => true})

    inquiry_fixture(user, %{
      "full_name" => "Jane Buyer",
      "contact" => "jane@example.com",
      "message" => "Is the jacket available?",
      "source_path" => "/store/inq-list-store/products/1-jacket"
    })

    {:ok, view, _html} = live(conn, "/app/inquiries")

    assert has_element?(view, "#inquiries-total-count", "1 total")
    assert render(view) =~ "Jane Buyer"
    assert render(view) =~ "jane@example.com"
    assert render(view) =~ "Is the jacket available?"
    assert render(view) =~ "/store/inq-list-store/products/1-jacket"
    assert has_element?(view, ~s(a[href="/store/inq-list-store/products/1-jacket"][target="_blank"]))
  end

  test "does not show other users' inquiries", %{conn: conn} do
    user = user_fixture(%{"email" => "inq-owner@example.com"})
    other_user = user_fixture(%{"email" => "inq-other@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    _my_storefront = storefront_fixture(user, %{"slug" => "inq-owner-store", "enabled" => true})
    _other_storefront = storefront_fixture(other_user, %{"slug" => "inq-other-store", "enabled" => true})

    inquiry_fixture(user, %{"full_name" => "My Buyer", "message" => "Mine"})
    inquiry_fixture(other_user, %{"full_name" => "Stranger Buyer", "message" => "Not mine"})

    {:ok, view, _html} = live(conn, "/app/inquiries")

    assert has_element?(view, "#inquiries-total-count", "1 total")
    assert render(view) =~ "My Buyer"
    refute render(view) =~ "Stranger Buyer"
  end

  test "search filters inquiries by name, contact, or message", %{conn: conn} do
    user = user_fixture(%{"email" => "inq-search@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})
    _storefront = storefront_fixture(user, %{"slug" => "inq-search-store", "enabled" => true})

    inquiry_fixture(user, %{"full_name" => "Alice", "contact" => "alice@example.com", "message" => "About coat"})
    inquiry_fixture(user, %{"full_name" => "Bob", "contact" => "bob@example.com", "message" => "Jacket size?"})

    {:ok, view, _html} = live(conn, "/app/inquiries?q=jacket")

    assert has_element?(view, "#inquiries-total-count", "1 total")
    assert render(view) =~ "Bob"
    refute render(view) =~ "Alice"
    assert has_element?(view, "button", "Clear")
  end

  test "search with no results shows empty state message", %{conn: conn} do
    user = user_fixture(%{"email" => "inq-noresult@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})
    _storefront = storefront_fixture(user, %{"slug" => "inq-noresult-store", "enabled" => true})

    inquiry_fixture(user, %{"full_name" => "Alice"})

    {:ok, view, _html} = live(conn, "/app/inquiries?q=nomatch_xyz")

    assert render(view) =~ ~s(No inquiries match)
    assert render(view) =~ "nomatch_xyz"
  end

  test "clear search navigates back to unfiltered list", %{conn: conn} do
    user = user_fixture(%{"email" => "inq-clear@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})
    _storefront = storefront_fixture(user, %{"slug" => "inq-clear-store", "enabled" => true})

    inquiry_fixture(user, %{"full_name" => "Alice"})

    {:ok, view, _html} = live(conn, "/app/inquiries?q=alice")

    view |> element("button", "Clear") |> render_click()

    assert_patch(view, "/app/inquiries")
    assert has_element?(view, "#inquiries-total-count", "1 total")
  end

  test "delete removes the inquiry and refreshes the list", %{conn: conn} do
    user = user_fixture(%{"email" => "inq-delete@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})
    _storefront = storefront_fixture(user, %{"slug" => "inq-delete-store", "enabled" => true})

    inquiry = inquiry_fixture(user, %{"full_name" => "To Delete"})

    {:ok, view, _html} = live(conn, "/app/inquiries")

    assert has_element?(view, "#inquiry-#{inquiry.id}")

    view
    |> element("#inquiry-#{inquiry.id} button", "Delete")
    |> render_click()

    refute has_element?(view, "#inquiry-#{inquiry.id}")
    assert has_element?(view, "#inquiries-total-count", "0 total")
    assert render(view) =~ "Inquiry deleted."
  end

  test "pagination renders prev/next links and correct page info", %{conn: conn} do
    user = user_fixture(%{"email" => "inq-pages@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})
    _storefront = storefront_fixture(user, %{"slug" => "inq-pages-store", "enabled" => true})

    for n <- 1..25 do
      inquiry_fixture(user, %{"full_name" => "Buyer #{n}", "message" => "Message #{n}"})
    end

    {:ok, view, _html} = live(conn, "/app/inquiries?page=1")

    assert render(view) =~ "Page 1 of 2"
    assert has_element?(view, ~s(a[href*="page=2"]), "Next")
    refute has_element?(view, "a", "Previous")

    {:ok, view2, _html} = live(conn, "/app/inquiries?page=2")

    assert render(view2) =~ "Page 2 of 2"
    assert has_element?(view2, ~s(a[href*="page=1"]), "Previous")
    refute has_element?(view2, "a", "Next")
  end

  test "Inquiries nav link is present in sidebar on all workspace pages", %{conn: conn} do
    user = user_fixture(%{"email" => "inq-nav@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    for path <- ["/app", "/app/inquiries", "/app/exports", "/app/settings"] do
      {:ok, view, _html} = live(conn, path)
      assert has_element?(view, ~s(a[href="/app/inquiries"]), "Inquiries"),
             "Expected Inquiries nav link on #{path}"
    end
  end
end
