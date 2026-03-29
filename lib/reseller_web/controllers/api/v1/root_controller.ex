defmodule ResellerWeb.API.V1.RootController do
  use ResellerWeb, :controller

  def show(conn, _params) do
    json(conn, %{
      data: %{
        name: "reseller",
        version: api_version(),
        docs_path: "/docs/API.md",
        endpoints: [
          %{
            method: "GET",
            path: "/api/v1",
            description: "Returns API metadata and the list of currently available endpoints."
          },
          %{
            method: "GET",
            path: "/api/v1/health",
            description: "Returns service health and application version information."
          },
          %{
            method: "GET",
            path: "/api/v1/products",
            description: "Lists products for the authenticated user."
          },
          %{
            method: "POST",
            path: "/api/v1/products",
            description: "Creates a product and optionally returns signed upload instructions."
          },
          %{
            method: "GET",
            path: "/api/v1/products/:id",
            description: "Returns one product for the authenticated user."
          },
          %{
            method: "POST",
            path: "/api/v1/products/:id/finalize_uploads",
            description: "Marks uploaded product images as ready for processing."
          }
        ]
      }
    })
  end

  defp api_version, do: "v1"
end
