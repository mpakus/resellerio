defmodule ResellerWeb.API.V1.RootControllerTest do
  use ResellerWeb.ConnCase, async: true

  test "returns api metadata and endpoint index", %{conn: conn} do
    conn = get(conn, "/api/v1")

    assert json_response(conn, 200) == %{
             "data" => %{
               "docs_path" => "/docs/API.md",
               "endpoints" => [
                 %{
                   "description" =>
                     "Returns API metadata and the list of currently available endpoints.",
                   "method" => "GET",
                   "path" => "/api/v1"
                 },
                 %{
                   "description" => "Returns service health and application version information.",
                   "method" => "GET",
                   "path" => "/api/v1/health"
                 },
                 %{
                   "description" => "Creates a user account and returns a bearer token.",
                   "method" => "POST",
                   "path" => "/api/v1/auth/register"
                 },
                 %{
                   "description" => "Authenticates a user and returns a bearer token.",
                   "method" => "POST",
                   "path" => "/api/v1/auth/login"
                 },
                 %{
                   "description" => "Returns the authenticated user and marketplace settings.",
                   "method" => "GET",
                   "path" => "/api/v1/me"
                 },
                 %{
                   "description" => "Updates the authenticated user's marketplace settings.",
                   "method" => "PATCH",
                   "path" => "/api/v1/me"
                 },
                 %{
                   "description" => "Lists products for the authenticated user.",
                   "method" => "GET",
                   "path" => "/api/v1/products"
                 },
                 %{
                   "description" =>
                     "Creates a product and optionally returns signed upload instructions.",
                   "method" => "POST",
                   "path" => "/api/v1/products"
                 },
                 %{
                   "description" => "Returns one product for the authenticated user.",
                   "method" => "GET",
                   "path" => "/api/v1/products/:id"
                 },
                 %{
                   "description" =>
                     "Updates seller-managed product fields, including tags and manual statuses.",
                   "method" => "PATCH",
                   "path" => "/api/v1/products/:id"
                 },
                 %{
                   "description" => "Deletes one product and its related records.",
                   "method" => "DELETE",
                   "path" => "/api/v1/products/:id"
                 },
                 %{
                   "description" => "Marks uploaded product images as ready for processing.",
                   "method" => "POST",
                   "path" => "/api/v1/products/:id/finalize_uploads"
                 },
                 %{
                   "description" => "Restarts the core AI pipeline for one product.",
                   "method" => "POST",
                   "path" => "/api/v1/products/:id/reprocess"
                 },
                 %{
                   "description" =>
                     "Starts manual lifestyle-image generation for a review-ready product.",
                   "method" => "POST",
                   "path" => "/api/v1/products/:id/generate_lifestyle_images"
                 },
                 %{
                   "description" =>
                     "Lists dedicated lifestyle-image generation runs for one product.",
                   "method" => "GET",
                   "path" => "/api/v1/products/:id/lifestyle_generation_runs"
                 },
                 %{
                   "description" => "Marks one generated lifestyle preview as seller-approved.",
                   "method" => "POST",
                   "path" => "/api/v1/products/:id/generated_images/:image_id/approve"
                 },
                 %{
                   "description" => "Deletes one generated lifestyle preview.",
                   "method" => "DELETE",
                   "path" => "/api/v1/products/:id/generated_images/:image_id"
                 },
                 %{
                   "description" => "Marks one product as sold.",
                   "method" => "POST",
                   "path" => "/api/v1/products/:id/mark_sold"
                 },
                 %{
                   "description" => "Archives one product.",
                   "method" => "POST",
                   "path" => "/api/v1/products/:id/archive"
                 },
                 %{
                   "description" => "Restores one archived product.",
                   "method" => "POST",
                   "path" => "/api/v1/products/:id/unarchive"
                 },
                 %{
                   "description" =>
                     "Queues a filtered ZIP export for the authenticated user with optional saved name and filter params.",
                   "method" => "POST",
                   "path" => "/api/v1/exports"
                 },
                 %{
                   "description" => "Returns one export request for the authenticated user.",
                   "method" => "GET",
                   "path" => "/api/v1/exports/:id"
                 },
                 %{
                   "description" =>
                     "Queues a Resellerio ZIP import for the authenticated user using Products.xls, manifest.json, and images.",
                   "method" => "POST",
                   "path" => "/api/v1/imports"
                 },
                 %{
                   "description" => "Returns one import request for the authenticated user.",
                   "method" => "GET",
                   "path" => "/api/v1/imports/:id"
                 }
               ],
               "name" => "resellerio",
               "version" => "v1"
             }
           }
  end
end
