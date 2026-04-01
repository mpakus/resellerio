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
            method: "POST",
            path: "/api/v1/auth/register",
            description: "Creates a user account and returns a bearer token."
          },
          %{
            method: "POST",
            path: "/api/v1/auth/login",
            description: "Authenticates a user and returns a bearer token."
          },
          %{
            method: "GET",
            path: "/api/v1/me",
            description: "Returns the authenticated user and marketplace settings."
          },
          %{
            method: "PATCH",
            path: "/api/v1/me",
            description: "Updates the authenticated user's marketplace settings."
          },
          %{
            method: "GET",
            path: "/api/v1/product_tabs",
            description: "Lists seller-defined product tabs for the authenticated user."
          },
          %{
            method: "POST",
            path: "/api/v1/product_tabs",
            description: "Creates one seller-defined product tab."
          },
          %{
            method: "PATCH",
            path: "/api/v1/product_tabs/:id",
            description: "Updates one seller-defined product tab."
          },
          %{
            method: "GET",
            path: "/api/v1/products",
            description:
              "Lists products for the authenticated user with filtering, sorting, and pagination."
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
            description:
              "Updates seller-managed product fields, including tags and manual statuses."
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
            path: "/api/v1/products/:id/reprocess",
            description: "Restarts the core AI pipeline for one product."
          },
          %{
            method: "POST",
            path: "/api/v1/products/:id/generate_lifestyle_images",
            description: "Starts manual lifestyle-image generation for a review-ready product."
          },
          %{
            method: "GET",
            path: "/api/v1/products/:id/lifestyle_generation_runs",
            description: "Lists dedicated lifestyle-image generation runs for one product."
          },
          %{
            method: "POST",
            path: "/api/v1/products/:id/generated_images/:image_id/approve",
            description: "Marks one generated lifestyle preview as seller-approved."
          },
          %{
            method: "DELETE",
            path: "/api/v1/products/:id/generated_images/:image_id",
            description: "Deletes one generated lifestyle preview."
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
            description:
              "Queues a filtered ZIP export for the authenticated user with optional saved name and filter params."
          },
          %{
            method: "GET",
            path: "/api/v1/exports/:id",
            description: "Returns one export request for the authenticated user."
          },
          %{
            method: "POST",
            path: "/api/v1/imports",
            description:
              "Queues a ResellerIO ZIP import for the authenticated user using Products.xls, manifest.json, and images."
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
