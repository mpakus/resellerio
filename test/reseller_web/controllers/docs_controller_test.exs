defmodule ResellerWeb.DocsControllerTest do
  use ResellerWeb.ConnCase, async: true

  test "serves the mobile API guide", %{conn: conn} do
    conn = get(conn, "/docs/mobile-api")

    assert response_content_type(conn, :markdown) =~ "text/markdown"
    assert response(conn, 200) =~ "# ResellerIO Mobile API Guide"
    assert response(conn, 200) =~ "POST /api/v1/auth/login"
  end
end
