defmodule ResellerWeb.DocsController do
  use ResellerWeb, :controller

  @mobile_api_guide_path Path.expand("../../../docs/MOBILE_API_GUIDE.md", __DIR__)
  @external_resource @mobile_api_guide_path
  @mobile_api_guide File.read!(@mobile_api_guide_path)

  def mobile_api(conn, _params) do
    conn
    |> put_resp_content_type("text/markdown", "utf-8")
    |> send_resp(200, @mobile_api_guide)
  end
end
