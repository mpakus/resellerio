defmodule ResellerWeb.ErrorJSONTest do
  use ResellerWeb.ConnCase, async: true

  test "renders 404" do
    assert ResellerWeb.ErrorJSON.render("404.json", %{}) == %{
             error: %{
               code: "not_found",
               detail: "Not Found",
               status: 404
             }
           }
  end

  test "renders 500" do
    assert ResellerWeb.ErrorJSON.render("500.json", %{}) ==
             %{
               error: %{
                 code: "internal_server_error",
                 detail: "Internal Server Error",
                 status: 500
               }
             }
  end
end
