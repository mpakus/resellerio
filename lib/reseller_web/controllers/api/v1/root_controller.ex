defmodule ResellerWeb.API.V1.RootController do
  use ResellerWeb, :controller

  def show(conn, _params) do
    json(conn, %{
      data: %{
        name: "resellerio",
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
            method: "PATCH",
            path: "/api/v1/products/:id",
            description: "Updates editable fields for one product."
          },
          %{
            method: "DELETE",
            path: "/api/v1/products/:id",
            description: "Deletes one product and its related records."
          },
          %{
            method: "POST",
            path: "/api/v1/products/:id/finalize_uploads",
            description: "Marks uploaded product images as ready for processing."
          },
          %{
            method: "POST",
            path: "/api/v1/products/:id/mark_sold",
            description: "Marks one product as sold."
          },
          %{
            method: "POST",
            path: "/api/v1/products/:id/archive",
            description: "Archives one product."
          },
          %{
            method: "POST",
            path: "/api/v1/products/:id/unarchive",
            description: "Restores one archived product."
          },
          %{
            method: "POST",
            path: "/api/v1/exports",
            description: "Queues a ZIP export for the authenticated user."
          },
          %{
            method: "GET",
            path: "/api/v1/exports/:id",
            description: "Returns one export request for the authenticated user."
          },
          %{
            method: "POST",
            path: "/api/v1/imports",
            description: "Queues a ZIP import for the authenticated user."
          },
          %{
            method: "GET",
            path: "/api/v1/imports/:id",
            description: "Returns one import request for the authenticated user."
          }
        ]
      }
    })
  end

  defp api_version, do: "v1"
end
