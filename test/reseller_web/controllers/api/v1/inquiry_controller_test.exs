defmodule ResellerWeb.API.V1.InquiryControllerTest do
  use ResellerWeb.ConnCase, async: true

  import Reseller.StorefrontFixtures

  setup %{conn: conn} do
    user = user_fixture(%{"email" => "inquiries-api@example.com"})
    {raw_token, _api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

    authed_conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")

    %{conn: authed_conn, user: user}
  end

  describe "GET /api/v1/inquiries" do
    test "returns empty list when no inquiries exist", %{conn: conn} do
      conn = get(conn, "/api/v1/inquiries")
      body = json_response(conn, 200)

      assert body["data"]["inquiries"] == []
      assert body["data"]["pagination"]["total_count"] == 0
    end

    test "returns inquiries for the current user", %{conn: conn, user: user} do
      _inquiry = inquiry_fixture(user)

      conn = get(conn, "/api/v1/inquiries")
      body = json_response(conn, 200)

      assert length(body["data"]["inquiries"]) == 1
      assert body["data"]["pagination"]["total_count"] == 1
    end

    test "does not return another user's inquiries", %{conn: conn} do
      other_user = user_fixture(%{"email" => "other-inq@example.com"})
      _inquiry = inquiry_fixture(other_user)

      conn = get(conn, "/api/v1/inquiries")
      body = json_response(conn, 200)

      assert body["data"]["inquiries"] == []
    end

    test "returns 401 when unauthenticated" do
      conn = build_conn()
      conn = get(conn, "/api/v1/inquiries")
      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/v1/inquiries/:id" do
    test "deletes an owned inquiry", %{conn: conn, user: user} do
      inquiry = inquiry_fixture(user)

      conn = delete(conn, "/api/v1/inquiries/#{inquiry.id}")

      assert json_response(conn, 200) == %{"data" => %{"deleted" => true}}
    end

    test "returns 404 for another user's inquiry", %{conn: conn} do
      other_user = user_fixture(%{"email" => "other-del-inq@example.com"})
      inquiry = inquiry_fixture(other_user)

      conn = delete(conn, "/api/v1/inquiries/#{inquiry.id}")

      assert json_response(conn, 404)
    end

    test "returns 401 when unauthenticated" do
      conn = build_conn()
      conn = delete(conn, "/api/v1/inquiries/1")
      assert json_response(conn, 401)
    end
  end
end
