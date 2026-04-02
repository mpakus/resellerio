defmodule ResellerWeb.APIDocsLive do
  use ResellerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: ResellerWeb.PageTitle.build("API Documentation", "Developers"),
       open_endpoints: MapSet.new(),
       openapi_path: ResellerWeb.API.V1.APISpec.openapi_path()
     )}
  end

  @impl true
  def handle_event("toggle_endpoint", %{"id" => id}, socket) do
    open = socket.assigns.open_endpoints

    open =
      if MapSet.member?(open, id),
        do: MapSet.delete(open, id),
        else: MapSet.put(open, id)

    {:noreply, assign(socket, open_endpoints: open)}
  end

  defp open?(open_endpoints, id), do: MapSet.member?(open_endpoints, id)
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-4xl px-4 py-16 sm:px-6 lg:px-8">
        <%!-- Header --%>
        <div class="text-center">
          <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
            For developers
          </p>
          <h1 class="reseller-display mt-4 text-5xl font-semibold tracking-[-0.04em]">
            API Documentation
          </h1>
          <p class="mx-auto mt-4 max-w-2xl text-lg leading-7 text-base-content/65">
            Build with the ResellerIO API. Everything you need to integrate product intake,
            AI processing, and marketplace listing generation into your mobile or web app.
          </p>
          <div class="mt-8 flex flex-wrap items-center justify-center gap-3">
            <span class="inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-2 text-sm font-medium text-base-content/70">
              REST / JSON
            </span>
            <span class="inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-2 text-sm font-medium text-base-content/70">
              Bearer token auth
            </span>
            <span class="inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-2 text-sm font-medium text-base-content/70">
              Versioned at /api/v1
            </span>
            <a
              href={@openapi_path}
              class="inline-flex items-center rounded-full border border-primary/20 bg-primary/8 px-4 py-2 text-sm font-medium text-primary transition-colors hover:bg-primary/12"
            >
              OpenAPI JSON
            </a>
          </div>
        </div>

        <%!-- Quick start --%>
        <div class="mt-16">
          <.surface tag="div" variant="ghost" padding="lg" class="rounded-[2rem]">
            <h2 class="text-xl font-semibold">Quick Start</h2>
            <p class="mt-2 text-sm text-base-content/65">
              Three steps to your first API call.
            </p>
            <div class="mt-6 grid gap-4 sm:grid-cols-3">
              <div class="rounded-2xl border border-base-300/60 bg-base-100 p-5">
                <div class="flex size-9 items-center justify-center rounded-xl bg-primary/12 text-sm font-bold text-primary">
                  1
                </div>
                <p class="mt-3 text-sm font-semibold">Register</p>
                <p class="mt-1 text-xs text-base-content/60">
                  POST /api/v1/auth/register with email &amp; password to get a bearer token.
                </p>
              </div>
              <div class="rounded-2xl border border-base-300/60 bg-base-100 p-5">
                <div class="flex size-9 items-center justify-center rounded-xl bg-secondary/12 text-sm font-bold text-secondary">
                  2
                </div>
                <p class="mt-3 text-sm font-semibold">Authenticate</p>
                <p class="mt-1 text-xs text-base-content/60">
                  Add Authorization: Bearer &lt;token&gt; to every subsequent request.
                </p>
              </div>
              <div class="rounded-2xl border border-base-300/60 bg-base-100 p-5">
                <div class="flex size-9 items-center justify-center rounded-xl bg-accent/12 text-sm font-bold text-accent">
                  3
                </div>
                <p class="mt-3 text-sm font-semibold">Create a Product</p>
                <p class="mt-1 text-xs text-base-content/60">
                  POST /api/v1/products with title, brand, and optional image uploads.
                </p>
              </div>
            </div>
          </.surface>
        </div>

        <%!-- Base URL & conventions --%>
        <div class="mt-12">
          <h2 class="text-2xl font-semibold tracking-tight">Base URL &amp; Conventions</h2>
          <div class="mt-4 overflow-hidden rounded-2xl border border-base-300">
            <table class="w-full text-sm">
              <tbody class="divide-y divide-base-300">
                <tr>
                  <td class="whitespace-nowrap px-4 py-3 font-medium">Base URL</td>
                  <td class="px-4 py-3"><code class="text-primary">/api/v1</code></td>
                </tr>
                <tr>
                  <td class="whitespace-nowrap px-4 py-3 font-medium">Content-Type</td>
                  <td class="px-4 py-3"><code>application/json</code></td>
                </tr>
                <tr>
                  <td class="whitespace-nowrap px-4 py-3 font-medium">Auth</td>
                  <td class="px-4 py-3">
                    <code>Authorization: Bearer &lt;token&gt;</code>&nbsp;(case-insensitive)
                  </td>
                </tr>
                <tr>
                  <td class="whitespace-nowrap px-4 py-3 font-medium">Success shape</td>
                  <td class="px-4 py-3"><code>&#123;"data": &#123; ... &#125;&#125;</code></td>
                </tr>
                <tr>
                  <td class="whitespace-nowrap px-4 py-3 font-medium">Error shape</td>
                  <td class="px-4 py-3">
                    <code>
                      &#123;"error": &#123;"code": "...", "detail": "...", "status": 404&#125;&#125;
                    </code>
                  </td>
                </tr>
                <tr>
                  <td class="whitespace-nowrap px-4 py-3 font-medium">OpenAPI</td>
                  <td class="px-4 py-3">
                    <a href={@openapi_path} class="font-medium text-primary hover:underline">
                      {@openapi_path}
                    </a>
                  </td>
                </tr>
                <tr>
                  <td class="whitespace-nowrap px-4 py-3 font-medium">Discovery</td>
                  <td class="px-4 py-3">
                    <code class="text-primary">GET /api/v1</code> returns all endpoints
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Endpoints --%>
        <div class="mt-12">
          <h2 class="text-2xl font-semibold tracking-tight">Endpoints</h2>
          <p class="mt-2 text-sm text-base-content/60">
            All endpoints grouped by feature area. Click any row to see parameters and examples. Protected endpoints require a bearer token.
          </p>
          <%!-- Auth --%>
          <.endpoint_group title="Authentication" icon="hero-key">
            <.endpoint
              id="auth-register"
              method="POST"
              path="/api/v1/auth/register"
              desc="Create an account and receive a bearer token"
              open={open?(@open_endpoints, "auth-register")}
              args={[
                %{name: "email", type: "string", required: true, desc: "Account email address"},
                %{name: "password", type: "string", required: true, desc: "Minimum 8 characters"},
                %{
                  name: "device_name",
                  type: "string",
                  required: false,
                  desc: "Human-readable device label for the issued token"
                },
                %{
                  name: "selected_marketplaces",
                  type: "array<string>",
                  required: false,
                  desc: "Marketplace IDs to enable for AI copy generation"
                }
              ]}
              request_example={
                ~s({\n  "email": "seller@example.com",\n  "password": "very-secure-password",\n  "device_name": "iPhone",\n  "selected_marketplaces": ["ebay", "depop", "poshmark"]\n})
              }
              response_example={
                ~s({\n  "data": {\n    "token": "eyJhbGciOi...",\n    "token_type": "Bearer",\n    "expires_at": "2026-04-28T18:00:00Z",\n    "user": {\n      "id": 1,\n      "email": "seller@example.com",\n      "confirmed_at": null,\n      "selected_marketplaces": ["ebay", "depop", "poshmark"]\n    },\n    "supported_marketplaces": [\n      {"id": "ebay", "label": "eBay"},\n      {"id": "depop", "label": "Depop"}\n    ]\n  }\n})
              }
            />
            <.endpoint
              id="auth-login"
              method="POST"
              path="/api/v1/auth/login"
              desc="Log in with email and password"
              open={open?(@open_endpoints, "auth-login")}
              args={[
                %{name: "email", type: "string", required: true, desc: "Account email"},
                %{name: "password", type: "string", required: true, desc: "Account password"},
                %{
                  name: "device_name",
                  type: "string",
                  required: false,
                  desc: "Device label for the issued token"
                }
              ]}
              request_example={
                ~s({\n  "email": "seller@example.com",\n  "password": "very-secure-password",\n  "device_name": "Pixel"\n})
              }
              response_example={
                ~s({\n  "data": {\n    "token": "eyJhbGciOi...",\n    "token_type": "Bearer",\n    "expires_at": "2026-04-28T18:00:00Z",\n    "user": {\n      "id": 1,\n      "email": "seller@example.com",\n      "selected_marketplaces": ["ebay", "depop"]\n    }\n  }\n})
              }
            />
          </.endpoint_group>
          <%!-- User --%>
          <.endpoint_group title="User & Settings" icon="hero-user" badge="auth">
            <.endpoint
              id="me-get"
              method="GET"
              path="/api/v1/me"
              desc="Get current user profile and marketplace preferences"
              open={open?(@open_endpoints, "me-get")}
              args={[]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "user": {\n      "id": 1,\n      "email": "seller@example.com",\n      "confirmed_at": null,\n      "selected_marketplaces": ["ebay", "depop", "poshmark"]\n    },\n    "supported_marketplaces": [\n      {"id": "ebay", "label": "eBay"},\n      {"id": "depop", "label": "Depop"},\n      {"id": "poshmark", "label": "Poshmark"}\n    ]\n  }\n})
              }
            />
            <.endpoint
              id="me-patch"
              method="PATCH"
              path="/api/v1/me"
              desc="Update marketplace preferences"
              open={open?(@open_endpoints, "me-patch")}
              args={[
                %{
                  name: "user.selected_marketplaces",
                  type: "array<string>",
                  required: true,
                  desc:
                    "Marketplace IDs to use for AI copy generation. Pass [] to disable generation."
                }
              ]}
              request_example={
                ~s({\n  "user": {\n    "selected_marketplaces": ["ebay", "mercari", "etsy"]\n  }\n})
              }
              response_example={
                ~s({\n  "data": {\n    "user": {\n      "id": 1,\n      "email": "seller@example.com",\n      "selected_marketplaces": ["ebay", "mercari", "etsy"]\n    }\n  }\n})
              }
            />
            <.endpoint
              id="me-usage"
              method="GET"
              path="/api/v1/me/usage"
              desc="Get current monthly usage, limits, and addon credits"
              open={open?(@open_endpoints, "me-usage")}
              args={[]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "usage": {\n      "ai_drafts": 0,\n      "background_removals": 0,\n      "lifestyle": 0,\n      "price_research": 0\n    },\n    "limits": {\n      "ai_drafts": 25,\n      "background_removals": 25,\n      "lifestyle": 10,\n      "price_research": 25\n    },\n    "addon_credits": {}\n  }\n})
              }
            />
          </.endpoint_group>
          <%!-- Products --%>
          <.endpoint_group title="Products" icon="hero-squares-2x2" badge="auth">
            <.endpoint
              id="products-list"
              method="GET"
              path="/api/v1/products"
              desc="List products with filters, sorting, and pagination"
              open={open?(@open_endpoints, "products-list")}
              args={[
                %{
                  name: "status",
                  type: "string",
                  required: false,
                  desc: "all · draft · uploading · processing · review · ready · sold · archived"
                },
                %{
                  name: "query",
                  type: "string",
                  required: false,
                  desc: "Full-text search across title, brand, category"
                },
                %{
                  name: "product_tab_id",
                  type: "integer",
                  required: false,
                  desc: "Filter by seller-owned product tab"
                },
                %{
                  name: "updated_from",
                  type: "date",
                  required: false,
                  desc: "ISO date lower bound (inclusive)"
                },
                %{
                  name: "updated_to",
                  type: "date",
                  required: false,
                  desc: "ISO date upper bound (inclusive)"
                },
                %{
                  name: "sort",
                  type: "string",
                  required: false,
                  desc: "title · status · price · updated_at · inserted_at"
                },
                %{name: "dir", type: "string", required: false, desc: "asc or desc (default: desc)"},
                %{name: "page", type: "integer", required: false, desc: "1-based page number"},
                %{
                  name: "page_size",
                  type: "integer",
                  required: false,
                  desc: "Items per page, max 100 (default 15)"
                }
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "products": [\n      {\n        "id": 1,\n        "status": "ready",\n        "title": "Vintage blazer",\n        "brand": "Ralph Lauren",\n        "category": "Blazers",\n        "price": "89.00",\n        "tags": ["vintage", "wool"],\n        "images": [],\n        "latest_processing_run": null\n      }\n    ],\n    "pagination": {"page": 1, "page_size": 15, "total_count": 1, "total_pages": 1},\n    "filters": {"status": "all", "query": null, "sort": "updated_at", "dir": "desc"}\n  }\n})
              }
            />
            <.endpoint
              id="products-create"
              method="POST"
              path="/api/v1/products"
              desc="Create a product with optional image uploads"
              open={open?(@open_endpoints, "products-create")}
              args={[
                %{name: "product.title", type: "string", required: false, desc: "Product title"},
                %{name: "product.brand", type: "string", required: false, desc: "Brand name"},
                %{name: "product.category", type: "string", required: false, desc: "Category"},
                %{
                  name: "product.product_tab_id",
                  type: "integer",
                  required: false,
                  desc: "Seller-owned tab assignment"
                },
                %{
                  name: "product.tags",
                  type: "array<string>",
                  required: false,
                  desc: "Freeform tag list"
                },
                %{
                  name: "uploads",
                  type: "array<object>",
                  required: false,
                  desc:
                    "Upload intents: {filename, content_type, byte_size}. Returns signed upload_instructions."
                }
              ]}
              request_example={
                ~s({\n  "product": {\n    "title": "Nike Air Max",\n    "brand": "Nike",\n    "category": "Sneakers",\n    "tags": ["running", "air-max"]\n  },\n  "uploads": [\n    {"filename": "shoe-1.jpg", "content_type": "image/jpeg", "byte_size": 345678}\n  ]\n})
              }
              response_example={
                ~s({\n  "data": {\n    "product": {\n      "id": 1,\n      "status": "uploading",\n      "title": "Nike Air Max",\n      "images": [{"id": 1, "kind": "original", "processing_status": "pending_upload"}]\n    },\n    "upload_instructions": [\n      {\n        "image_id": 1,\n        "method": "PUT",\n        "upload_url": "https://bucket.tigris.dev/...",\n        "headers": {"content-type": "image/jpeg"},\n        "expires_at": "2026-03-29T18:40:00Z"\n      }\n    ]\n  }\n})
              }
            />
            <.endpoint
              id="products-get"
              method="GET"
              path="/api/v1/products/:id"
              desc="Get one product with all AI data"
              open={open?(@open_endpoints, "products-get")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"}
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "product": {\n      "id": 12,\n      "status": "ready",\n      "title": "Nike Air Max 90",\n      "brand": "Nike",\n      "price": "125.00",\n      "tags": ["running", "air-max"],\n      "storefront_enabled": true,\n      "storefront_published_at": "2026-03-29T12:00:00Z",\n      "description_draft": {\n        "suggested_title": "Nike Air Max 90",\n        "short_description": "Classic Nike Air Max 90 sneakers in white mesh."\n      },\n      "price_research": {\n        "suggested_target_price": "125.00",\n        "pricing_confidence": 0.82\n      },\n      "marketplace_listings": [\n        {"marketplace": "ebay", "status": "generated", "generated_title": "Nike Air Max 90 Sneakers White Mesh", "external_url": "https://www.ebay.com/itm/1234567890"}\n      ],\n      "images": [\n        {"id": 31, "kind": "original", "processing_status": "ready", "storefront_visible": true, "storefront_position": 1},\n        {"id": 32, "kind": "background_removed", "processing_status": "ready", "storefront_visible": false, "storefront_position": null}\n      ]\n    }\n  }\n})
              }
            />
            <.endpoint
              id="products-update"
              method="PATCH"
              path="/api/v1/products/:id"
              desc="Update product fields, tags, or status"
              open={open?(@open_endpoints, "products-update")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"},
                %{name: "product.title", type: "string", required: false, desc: "Product title"},
                %{name: "product.brand", type: "string", required: false, desc: "Brand name"},
                %{name: "product.category", type: "string", required: false, desc: "Category"},
                %{name: "product.condition", type: "string", required: false, desc: "Item condition"},
                %{name: "product.color", type: "string", required: false, desc: "Color"},
                %{name: "product.size", type: "string", required: false, desc: "Size"},
                %{name: "product.material", type: "string", required: false, desc: "Material"},
                %{
                  name: "product.price",
                  type: "decimal string",
                  required: false,
                  desc: "Sale price (e.g. \"99.00\")"
                },
                %{
                  name: "product.cost",
                  type: "decimal string",
                  required: false,
                  desc: "Purchase cost"
                },
                %{name: "product.sku", type: "string", required: false, desc: "Custom SKU"},
                %{name: "product.notes", type: "string", required: false, desc: "Internal notes"},
                %{
                  name: "product.product_tab_id",
                  type: "integer|null",
                  required: false,
                  desc: "Tab assignment; null to unassign"
                },
                %{
                  name: "product.tags",
                  type: "array<string>",
                  required: false,
                  desc: "Replaces the existing tag list"
                },
                %{
                  name: "product.status",
                  type: "string",
                  required: false,
                  desc: "draft · review · ready · sold · archived (system statuses not editable)"
                },
                %{
                  name: "product.storefront_enabled",
                  type: "boolean",
                  required: false,
                  desc: "Publish or unpublish the product on the seller storefront"
                },
                %{
                  name: "marketplace_external_urls",
                  type: "object",
                  required: false,
                  desc: "Marketplace-to-URL map for seller-managed live listing URLs"
                }
              ]}
              request_example={
                ~s({\n  "product": {\n    "title": "Nike Air Max 90 White",\n    "price": "119.00",\n    "condition": "used_good",\n    "notes": "Measured and cleaned",\n    "tags": ["nike", "air-max", "sneakers"],\n    "storefront_enabled": true\n  },\n  "marketplace_external_urls": {\n    "ebay": "https://www.ebay.com/itm/1234567890"\n  }\n})
              }
              response_example={
                ~s({\n  "data": {\n    "product": {\n      "id": 12,\n      "status": "ready",\n      "title": "Nike Air Max 90 White",\n      "price": "119.00",\n      "tags": ["nike", "air-max", "sneakers"],\n      "storefront_enabled": true,\n      "marketplace_listings": [\n        {"marketplace": "ebay", "external_url": "https://www.ebay.com/itm/1234567890"}\n      ]\n    }\n  }\n})
              }
            />
            <.endpoint
              id="products-delete"
              method="DELETE"
              path="/api/v1/products/:id"
              desc="Delete a product and all related data"
              open={open?(@open_endpoints, "products-delete")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"}
              ]}
              request_example={nil}
              response_example={~s({\n  "data": {"deleted": true}\n})}
            />
            <.endpoint
              id="products-prepare"
              method="POST"
              path="/api/v1/products/:id/prepare_uploads"
              desc="Prepare new uploads for an existing product"
              open={open?(@open_endpoints, "products-prepare")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"},
                %{
                  name: "uploads",
                  type: "array<object>",
                  required: true,
                  desc: "Upload intents: {filename, content_type, byte_size}"
                }
              ]}
              request_example={
                ~s({\n  "uploads": [\n    {"filename": "shoe-2.jpg", "content_type": "image/jpeg", "byte_size": 345678}\n  ]\n})
              }
              response_example={
                ~s({\n  "data": {\n    "product": {\n      "id": 1,\n      "status": "draft",\n      "images": [{"id": 2, "kind": "original", "processing_status": "pending_upload"}]\n    },\n    "upload_instructions": [\n      {\n        "image_id": 2,\n        "method": "PUT",\n        "upload_url": "https://bucket.tigris.dev/...",\n        "headers": {"content-type": "image/jpeg"},\n        "expires_at": "2026-03-29T18:40:00Z"\n      }\n    ]\n  }\n})
              }
            />
            <.endpoint
              id="products-finalize"
              method="POST"
              path="/api/v1/products/:id/finalize_uploads"
              desc="Finalize uploaded images and start AI processing"
              open={open?(@open_endpoints, "products-finalize")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"},
                %{
                  name: "uploads",
                  type: "array<object>",
                  required: true,
                  desc: "List of finalized uploads: {id (image_id), checksum, width, height}"
                }
              ]}
              request_example={
                ~s({\n  "uploads": [\n    {"id": 1, "checksum": "abc123", "width": 1200, "height": 1600}\n  ]\n})
              }
              response_example={
                ~s({\n  "data": {\n    "product": {"id": 1, "status": "processing"},\n    "processing_run": {"id": 12, "status": "queued", "step": "queued"}\n  }\n})
              }
            />
            <.endpoint
              id="products-reprocess"
              method="POST"
              path="/api/v1/products/:id/reprocess"
              desc="Retry AI processing after a failure"
              open={open?(@open_endpoints, "products-reprocess")}
              args={[
                %{
                  name: "id",
                  type: "integer",
                  required: true,
                  desc: "Product ID (path param). Must have finalized images."
                }
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "product": {"id": 12, "status": "processing"},\n    "processing_run": {"id": 18, "status": "queued", "step": "queued", "error_code": null}\n  }\n})
              }
            />
            <.endpoint
              id="products-mark-sold"
              method="POST"
              path="/api/v1/products/:id/mark_sold"
              desc="Mark as sold"
              open={open?(@open_endpoints, "products-mark-sold")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"}
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {"product": {"id": 12, "status": "sold", "sold_at": "2026-04-01T10:00:00Z"}}\n})
              }
            />
            <.endpoint
              id="products-archive"
              method="POST"
              path="/api/v1/products/:id/archive"
              desc="Archive a product"
              open={open?(@open_endpoints, "products-archive")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"}
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {"product": {"id": 12, "status": "archived", "archived_at": "2026-04-01T10:00:00Z"}}\n})
              }
            />
            <.endpoint
              id="products-unarchive"
              method="POST"
              path="/api/v1/products/:id/unarchive"
              desc="Restore an archived product"
              open={open?(@open_endpoints, "products-unarchive")}
              args={[
                %{
                  name: "id",
                  type: "integer",
                  required: true,
                  desc: "Product ID (path param). Returns to sold if sold_at is set, otherwise ready."
                }
              ]}
              request_example={nil}
              response_example={~s({\n  "data": {"product": {"id": 12, "status": "ready"}}\n})}
            />
          </.endpoint_group>
          <%!-- Images --%>
          <.endpoint_group title="Product Images" icon="hero-photo" badge="auth">
            <.endpoint
              id="images-delete"
              method="DELETE"
              path="/api/v1/products/:id/images/:image_id"
              desc="Delete an uploaded image and its variants"
              open={open?(@open_endpoints, "images-delete")}
              args={[
                %{
                  name: "id",
                  type: "integer",
                  required: true,
                  desc: "Product ID (path param). Must be in draft, review, or ready status."
                },
                %{name: "image_id", type: "integer", required: true, desc: "Image ID (path param)"}
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "deleted": true,\n    "product": {"id": 12, "status": "ready", "images": []}\n  }\n})
              }
            />
            <.endpoint
              id="images-storefront"
              method="PATCH"
              path="/api/v1/products/:id/images/:image_id/storefront"
              desc="Set storefront visibility and position"
              open={open?(@open_endpoints, "images-storefront")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"},
                %{name: "image_id", type: "integer", required: true, desc: "Image ID (path param)"},
                %{
                  name: "storefront_visible",
                  type: "boolean",
                  required: false,
                  desc: "Show image in the public storefront gallery"
                },
                %{
                  name: "storefront_position",
                  type: "integer|null",
                  required: false,
                  desc: "Explicit display order (1-based); null falls back to upload position"
                }
              ]}
              request_example={~s({\n  "storefront_visible": true,\n  "storefront_position": 1\n})}
              response_example={
                ~s({\n  "data": {\n    "product": {"id": 12, "status": "ready", "images": [...]}\n  }\n})
              }
            />
            <.endpoint
              id="images-storefront-order"
              method="PUT"
              path="/api/v1/products/:id/images/storefront_order"
              desc="Reorder storefront gallery images"
              open={open?(@open_endpoints, "images-storefront-order")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"},
                %{
                  name: "image_ids",
                  type: "array<integer>",
                  required: true,
                  desc: "Ordered list of image IDs — positions 1-to-N assigned in order"
                }
              ]}
              request_example={~s({\n  "image_ids": [42, 17, 99]\n})}
              response_example={
                ~s({\n  "data": {\n    "product": {"id": 12, "status": "ready", "images": [...]}\n  }\n})
              }
            />
          </.endpoint_group>
          <%!-- Lifestyle --%>
          <.endpoint_group title="Lifestyle Images" icon="hero-sparkles" badge="auth">
            <.endpoint
              id="lifestyle-generate"
              method="POST"
              path="/api/v1/products/:id/generate_lifestyle_images"
              desc="Generate AI lifestyle previews"
              open={open?(@open_endpoints, "lifestyle-generate")}
              args={[
                %{
                  name: "id",
                  type: "integer",
                  required: true,
                  desc: "Product ID (path param). Must be in review, ready, sold, or archived status."
                },
                %{
                  name: "scene_key",
                  type: "string",
                  required: false,
                  desc:
                    "Specific scene to regenerate (e.g. casual_lifestyle). Omit to generate the full default scene set."
                }
              ]}
              request_example={~s({\n  "scene_key": "casual_lifestyle"\n})}
              response_example={
                ~s({\n  "data": {\n    "lifestyle_generation_run": {\n      "id": 19,\n      "status": "completed",\n      "step": "lifestyle_generated",\n      "requested_count": 3,\n      "completed_count": 3\n    }\n  }\n})
              }
            />
            <.endpoint
              id="lifestyle-runs"
              method="GET"
              path="/api/v1/products/:id/lifestyle_generation_runs"
              desc="View generation run history"
              open={open?(@open_endpoints, "lifestyle-runs")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"}
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "runs": [\n      {\n        "id": 19,\n        "status": "completed",\n        "step": "lifestyle_generated",\n        "scene_family": "apparel",\n        "requested_count": 3,\n        "completed_count": 3\n      }\n    ]\n  }\n})
              }
            />
            <.endpoint
              id="lifestyle-approve"
              method="POST"
              path="/api/v1/products/:id/generated_images/:image_id/approve"
              desc="Approve a generated image"
              open={open?(@open_endpoints, "lifestyle-approve")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"},
                %{
                  name: "image_id",
                  type: "integer",
                  required: true,
                  desc: "Generated image ID (path param)"
                }
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "product": {\n      "id": 12,\n      "images": [\n        {"id": 44, "kind": "lifestyle_generated", "seller_approved": true, "approved_at": "2026-04-01T11:00:00Z"}\n      ]\n    }\n  }\n})
              }
            />
            <.endpoint
              id="lifestyle-delete"
              method="DELETE"
              path="/api/v1/products/:id/generated_images/:image_id"
              desc="Delete a generated image"
              open={open?(@open_endpoints, "lifestyle-delete")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Product ID (path param)"},
                %{
                  name: "image_id",
                  type: "integer",
                  required: true,
                  desc: "Generated image ID (path param)"
                }
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {"deleted": true, "product": {"id": 12, "status": "ready", "images": [...]}}\n})
              }
            />
          </.endpoint_group>
          <%!-- Product Tabs --%>
          <.endpoint_group title="Product Tabs" icon="hero-tag" badge="auth">
            <.endpoint
              id="tabs-list"
              method="GET"
              path="/api/v1/product_tabs"
              desc="List tabs"
              open={open?(@open_endpoints, "tabs-list")}
              args={[]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "product_tabs": [\n      {"id": 4, "name": "Outerwear", "position": 1, "inserted_at": "2026-03-31T12:00:00Z"}\n    ]\n  }\n})
              }
            />
            <.endpoint
              id="tabs-create"
              method="POST"
              path="/api/v1/product_tabs"
              desc="Create a tab"
              open={open?(@open_endpoints, "tabs-create")}
              args={[
                %{
                  name: "product_tab.name",
                  type: "string",
                  required: true,
                  desc: "Display name of the tab"
                }
              ]}
              request_example={~s({\n  "product_tab": {"name": "Shoes"}\n})}
              response_example={
                ~s({\n  "data": {\n    "product_tab": {"id": 5, "name": "Shoes", "position": 2}\n  }\n})
              }
            />
            <.endpoint
              id="tabs-update"
              method="PATCH"
              path="/api/v1/product_tabs/:id"
              desc="Rename a tab"
              open={open?(@open_endpoints, "tabs-update")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Tab ID (path param)"},
                %{name: "product_tab.name", type: "string", required: true, desc: "New display name"}
              ]}
              request_example={~s({\n  "product_tab": {"name": "Sneakers"}\n})}
              response_example={
                ~s({\n  "data": {"product_tab": {"id": 5, "name": "Sneakers", "position": 2}}\n})
              }
            />
            <.endpoint
              id="tabs-delete"
              method="DELETE"
              path="/api/v1/product_tabs/:id"
              desc="Delete a tab"
              open={open?(@open_endpoints, "tabs-delete")}
              args={[
                %{
                  name: "id",
                  type: "integer",
                  required: true,
                  desc:
                    "Tab ID (path param). Products assigned to this tab have their product_tab_id set to null."
                }
              ]}
              request_example={nil}
              response_example={~s({\n  "data": {"deleted": true}\n})}
            />
          </.endpoint_group>
          <%!-- Storefront --%>
          <.endpoint_group title="Storefront" icon="hero-building-storefront" badge="auth">
            <.endpoint
              id="storefront-get"
              method="GET"
              path="/api/v1/storefront"
              desc="Get storefront config with assets and pages"
              open={open?(@open_endpoints, "storefront-get")}
              args={[]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "storefront": {\n      "id": 3,\n      "slug": "my-store",\n      "title": "My Store",\n      "tagline": "Curated resale.",\n      "theme_id": "neutral-warm",\n      "enabled": true,\n      "assets": [{"id": 1, "kind": "logo", "width": 400, "height": 400}],\n      "pages": [{"id": 2, "title": "About", "slug": "about", "published": true}]\n    }\n  }\n})
              }
            />
            <.endpoint
              id="storefront-put"
              method="PUT"
              path="/api/v1/storefront"
              desc="Create or update storefront"
              open={open?(@open_endpoints, "storefront-put")}
              args={[
                %{
                  name: "storefront.slug",
                  type: "string",
                  required: true,
                  desc: "URL slug for the public store (lowercase, hyphens allowed)"
                },
                %{
                  name: "storefront.title",
                  type: "string",
                  required: false,
                  desc: "Store display name"
                },
                %{
                  name: "storefront.tagline",
                  type: "string",
                  required: false,
                  desc: "Short tagline shown in the header"
                },
                %{
                  name: "storefront.description",
                  type: "string",
                  required: false,
                  desc: "Longer store description"
                },
                %{
                  name: "storefront.theme_id",
                  type: "string",
                  required: false,
                  desc: "Theme preset ID"
                },
                %{
                  name: "storefront.enabled",
                  type: "boolean",
                  required: false,
                  desc: "Whether the store is publicly visible"
                }
              ]}
              request_example={
                ~s({\n  "storefront": {\n    "slug": "my-store",\n    "title": "My Store",\n    "tagline": "Curated resale.",\n    "theme_id": "neutral-warm",\n    "enabled": true\n  }\n})
              }
              response_example={
                ~s({\n  "data": {\n    "storefront": {"id": 3, "slug": "my-store", "title": "My Store", "enabled": true}\n  }\n})
              }
            />
            <.endpoint
              id="storefront-pages-list"
              method="GET"
              path="/api/v1/storefront/pages"
              desc="List storefront pages"
              open={open?(@open_endpoints, "storefront-pages-list")}
              args={[]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "pages": [\n      {"id": 2, "title": "About", "slug": "about", "menu_label": "About", "published": true, "position": 1}\n    ]\n  }\n})
              }
            />
            <.endpoint
              id="storefront-pages-create"
              method="POST"
              path="/api/v1/storefront/pages"
              desc="Create a page"
              open={open?(@open_endpoints, "storefront-pages-create")}
              args={[
                %{name: "page.title", type: "string", required: true, desc: "Page heading"},
                %{
                  name: "page.slug",
                  type: "string",
                  required: true,
                  desc: "URL slug (lowercase, hyphens)"
                },
                %{
                  name: "page.menu_label",
                  type: "string",
                  required: false,
                  desc: "Navigation label (defaults to title)"
                },
                %{name: "page.body", type: "string", required: false, desc: "Page content"},
                %{
                  name: "page.published",
                  type: "boolean",
                  required: false,
                  desc: "Whether page is publicly visible"
                }
              ]}
              request_example={
                ~s({\n  "page": {\n    "title": "Returns",\n    "slug": "returns",\n    "body": "Full refunds within 30 days.",\n    "published": true\n  }\n})
              }
              response_example={
                ~s({\n  "data": {\n    "page": {"id": 3, "title": "Returns", "slug": "returns", "published": true, "position": 2}\n  }\n})
              }
            />
            <.endpoint
              id="storefront-pages-update"
              method="PATCH"
              path="/api/v1/storefront/pages/:page_id"
              desc="Update a page"
              open={open?(@open_endpoints, "storefront-pages-update")}
              args={[
                %{name: "page_id", type: "integer", required: true, desc: "Page ID (path param)"},
                %{name: "page.title", type: "string", required: false, desc: "Page heading"},
                %{name: "page.body", type: "string", required: false, desc: "Page content"},
                %{name: "page.menu_label", type: "string", required: false, desc: "Navigation label"},
                %{name: "page.published", type: "boolean", required: false, desc: "Visibility toggle"}
              ]}
              request_example={
                ~s({\n  "page": {"title": "Shipping Policy", "body": "Ships in 1-2 business days.", "published": true}\n})
              }
              response_example={
                ~s({\n  "data": {"page": {"id": 3, "title": "Shipping Policy", "published": true}}\n})
              }
            />
            <.endpoint
              id="storefront-pages-delete"
              method="DELETE"
              path="/api/v1/storefront/pages/:page_id"
              desc="Delete a page"
              open={open?(@open_endpoints, "storefront-pages-delete")}
              args={[
                %{name: "page_id", type: "integer", required: true, desc: "Page ID (path param)"}
              ]}
              request_example={nil}
              response_example={~s({\n  "data": {"deleted": true}\n})}
            />
            <.endpoint
              id="storefront-pages-reorder"
              method="PUT"
              path="/api/v1/storefront/pages/order"
              desc="Reorder storefront pages"
              open={open?(@open_endpoints, "storefront-pages-reorder")}
              args={[
                %{
                  name: "page_ids",
                  type: "array<integer>",
                  required: true,
                  desc: "Ordered list of storefront page IDs"
                }
              ]}
              request_example={~s({\n  "page_ids": [7, 5, 6]\n})}
              response_example={
                ~s({\n  "data": {\n    "pages": [\n      {"id": 7, "title": "Shipping", "position": 1},\n      {"id": 5, "title": "About", "position": 2}\n    ]\n  }\n})
              }
            />
            <.endpoint
              id="storefront-assets-prepare"
              method="POST"
              path="/api/v1/storefront/assets/:kind/prepare_upload"
              desc="Prepare a signed upload for logo or header assets"
              open={open?(@open_endpoints, "storefront-assets-prepare")}
              args={[
                %{name: "kind", type: "string", required: true, desc: "logo or header (path param)"},
                %{name: "asset.filename", type: "string", required: true, desc: "Original filename"},
                %{
                  name: "asset.content_type",
                  type: "string",
                  required: true,
                  desc: "Image MIME type"
                },
                %{
                  name: "asset.byte_size",
                  type: "integer",
                  required: false,
                  desc: "File size in bytes"
                },
                %{
                  name: "asset.width",
                  type: "integer",
                  required: false,
                  desc: "Image width in pixels"
                },
                %{
                  name: "asset.height",
                  type: "integer",
                  required: false,
                  desc: "Image height in pixels"
                }
              ]}
              request_example={
                ~s({\n  "asset": {\n    "filename": "logo.png",\n    "content_type": "image/png",\n    "byte_size": 48000,\n    "width": 400,\n    "height": 400\n  }\n})
              }
              response_example={
                ~s({\n  "data": {\n    "asset": {"id": 9, "kind": "logo", "content_type": "image/png", "original_filename": "logo.png"},\n    "upload_instruction": {\n      "method": "PUT",\n      "upload_url": "https://bucket.tigris.dev/...",\n      "headers": {"content-type": "image/png"},\n      "expires_at": "2026-03-29T18:40:00Z"\n    }\n  }\n})
              }
            />
            <.endpoint
              id="storefront-assets-delete"
              method="DELETE"
              path="/api/v1/storefront/assets/:kind"
              desc="Delete a branding asset (logo or header)"
              open={open?(@open_endpoints, "storefront-assets-delete")}
              args={[
                %{name: "kind", type: "string", required: true, desc: "logo or header (path param)"}
              ]}
              request_example={nil}
              response_example={~s({\n  "data": {"deleted": true}\n})}
            />
          </.endpoint_group>
          <%!-- Inquiries --%>
          <.endpoint_group title="Inquiries" icon="hero-chat-bubble-left-right" badge="auth">
            <.endpoint
              id="inquiries-list"
              method="GET"
              path="/api/v1/inquiries"
              desc="List storefront inquiries with search and pagination"
              open={open?(@open_endpoints, "inquiries-list")}
              args={[
                %{
                  name: "q",
                  type: "string",
                  required: false,
                  desc: "Full-text search across full_name, contact, and message"
                },
                %{name: "page", type: "integer", required: false, desc: "1-based page number"},
                %{
                  name: "page_size",
                  type: "integer",
                  required: false,
                  desc: "Items per page, max 100 (default 20)"
                }
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "inquiries": [\n      {\n        "id": 7,\n        "full_name": "Jane Buyer",\n        "contact": "jane@example.com",\n        "message": "Is this still available?",\n        "product_id": 12,\n        "inserted_at": "2026-03-30T15:22:00Z"\n      }\n    ],\n    "pagination": {"page": 1, "page_size": 20, "total_count": 1, "total_pages": 1}\n  }\n})
              }
            />
            <.endpoint
              id="inquiries-delete"
              method="DELETE"
              path="/api/v1/inquiries/:id"
              desc="Delete an inquiry"
              open={open?(@open_endpoints, "inquiries-delete")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Inquiry ID (path param)"}
              ]}
              request_example={nil}
              response_example={~s({\n  "data": {"deleted": true}\n})}
            />
          </.endpoint_group>

          <%!-- Exports & Imports --%>
          <.endpoint_group title="Exports & Imports" icon="hero-arrow-down-tray" badge="auth">
            <.endpoint
              id="exports-create"
              method="POST"
              path="/api/v1/exports"
              desc="Queue a filtered ZIP export"
              open={open?(@open_endpoints, "exports-create")}
              args={[
                %{
                  name: "export.name",
                  type: "string",
                  required: false,
                  desc: "Human-readable label for the export"
                },
                %{
                  name: "export.filters.query",
                  type: "string",
                  required: false,
                  desc: "Text search filter"
                },
                %{
                  name: "export.filters.product_tab_id",
                  type: "integer",
                  required: false,
                  desc: "Tab filter"
                },
                %{
                  name: "export.filters.status",
                  type: "string",
                  required: false,
                  desc: "Status filter (e.g. ready)"
                },
                %{
                  name: "export.filters.updated_from",
                  type: "date",
                  required: false,
                  desc: "ISO date lower bound"
                },
                %{
                  name: "export.filters.updated_to",
                  type: "date",
                  required: false,
                  desc: "ISO date upper bound"
                }
              ]}
              request_example={
                ~s({\n  "export": {\n    "name": "Ready inventory",\n    "filters": {\n      "status": "ready",\n      "updated_from": "2026-03-01",\n      "updated_to": "2026-03-31"\n    }\n  }\n})
              }
              response_example={
                ~s({\n  "data": {\n    "export": {\n      "id": 1,\n      "name": "Ready inventory",\n      "status": "queued",\n      "product_count": 4,\n      "download_url": null,\n      "requested_at": "2026-03-30T01:10:00Z",\n      "completed_at": null,\n      "expires_at": null\n    }\n  }\n})
              }
            />
            <.endpoint
              id="exports-get"
              method="GET"
              path="/api/v1/exports/:id"
              desc="Check export status and download URL"
              open={open?(@open_endpoints, "exports-get")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Export ID (path param)"}
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "export": {\n      "id": 1,\n      "status": "completed",\n      "product_count": 4,\n      "download_url": "https://bucket.tigris.dev/exports/...",\n      "expires_at": "2026-04-07T01:10:00Z",\n      "completed_at": "2026-03-30T01:15:00Z"\n    }\n  }\n})
              }
            />
            <.endpoint
              id="imports-create"
              method="POST"
              path="/api/v1/imports"
              desc="Queue a ZIP import (base64-encoded)"
              open={open?(@open_endpoints, "imports-create")}
              args={[
                %{
                  name: "import.filename",
                  type: "string",
                  required: true,
                  desc: "Original filename of the ZIP archive"
                },
                %{
                  name: "import.archive_base64",
                  type: "string",
                  required: true,
                  desc: "Base64-encoded ZIP. Should contain Products.xls, manifest.json, and images/"
                }
              ]}
              request_example={
                ~s({\n  "import": {\n    "filename": "catalog.zip",\n    "archive_base64": "<base64 encoded zip>"\n  }\n})
              }
              response_example={
                ~s({\n  "data": {\n    "import": {\n      "id": 1,\n      "status": "queued",\n      "source_filename": "catalog.zip",\n      "total_products": 0,\n      "imported_products": 0,\n      "failed_products": 0,\n      "requested_at": "2026-03-30T02:10:00Z"\n    }\n  }\n})
              }
            />
            <.endpoint
              id="imports-get"
              method="GET"
              path="/api/v1/imports/:id"
              desc="Check import status and results"
              open={open?(@open_endpoints, "imports-get")}
              args={[
                %{name: "id", type: "integer", required: true, desc: "Import ID (path param)"}
              ]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "import": {\n      "id": 1,\n      "status": "completed",\n      "total_products": 12,\n      "imported_products": 11,\n      "failed_products": 1,\n      "finished_at": "2026-03-30T02:13:00Z",\n      "failure_details": {"items": [{"row": 3, "error": "Missing title"}]}\n    }\n  }\n})
              }
            />
          </.endpoint_group>

          <%!-- System --%>
          <.endpoint_group title="System" icon="hero-server-stack">
            <.endpoint
              id="system-root"
              method="GET"
              path="/api/v1"
              desc="API metadata and full endpoint list"
              open={open?(@open_endpoints, "system-root")}
              args={[]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {\n    "name": "resellerio",\n    "version": "v1",\n    "endpoints": [\n      {"method": "GET", "path": "/api/v1", "description": "Returns API metadata..."}\n    ]\n  }\n})
              }
            />
            <.endpoint
              id="system-health"
              method="GET"
              path="/api/v1/health"
              desc="Health check"
              open={open?(@open_endpoints, "system-health")}
              args={[]}
              request_example={nil}
              response_example={
                ~s({\n  "data": {"name": "resellerio", "status": "ok", "version": "0.1.0"}\n})
              }
            />
          </.endpoint_group>
        </div>
        <%!-- Error codes --%>
        <div class="mt-12">
          <h2 class="text-2xl font-semibold tracking-tight">Error Codes</h2>
          <p class="mt-2 text-sm text-base-content/60">
            All errors follow the same shape. Validation errors (422) include a <code>fields</code>
            map with per-field messages.
          </p>
          <div class="mt-4 overflow-hidden rounded-2xl border border-base-300">
            <table class="w-full text-sm">
              <thead class="bg-base-200/60">
                <tr>
                  <th class="px-4 py-3 text-left font-semibold">HTTP</th>
                  <th class="px-4 py-3 text-left font-semibold">Code</th>
                  <th class="px-4 py-3 text-left font-semibold">Meaning</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-300">
                <tr>
                  <td class="px-4 py-3">401</td>
                  <td class="px-4 py-3"><code>unauthorized</code></td>
                  <td class="px-4 py-3">Missing or invalid bearer token</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">404</td>
                  <td class="px-4 py-3"><code>not_found</code></td>
                  <td class="px-4 py-3">Resource not found or not owned by you</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">402</td>
                  <td class="px-4 py-3"><code>limit_exceeded</code></td>
                  <td class="px-4 py-3">
                    Monthly plan limit reached; response includes an absolute <code>upgrade_url</code>
                  </td>
                </tr>
                <tr>
                  <td class="px-4 py-3">422</td>
                  <td class="px-4 py-3"><code>validation_failed</code></td>
                  <td class="px-4 py-3">Input validation errors — check <code>fields</code></td>
                </tr>
                <tr>
                  <td class="px-4 py-3">422</td>
                  <td class="px-4 py-3"><code>invalid_product_state</code></td>
                  <td class="px-4 py-3">Product status doesn't allow this action</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">422</td>
                  <td class="px-4 py-3"><code>invalid_uploads</code></td>
                  <td class="px-4 py-3">Upload IDs don't belong to the product</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">502</td>
                  <td class="px-4 py-3"><code>storage_unavailable</code></td>
                  <td class="px-4 py-3">Object storage is not configured</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- AI error codes --%>
        <div class="mt-8">
          <h3 class="text-lg font-semibold">Retryable AI Error Codes</h3>
          <p class="mt-2 text-sm text-base-content/60">
            These appear in <code>latest_processing_run.error_code</code>. Use
            <code>POST /products/:id/reprocess</code>
            to retry.
          </p>
          <div class="mt-4 flex flex-wrap gap-2">
            <code class="rounded-full border border-warning/30 bg-warning/10 px-3 py-1 text-xs text-warning">
              ai_quota_exhausted
            </code>
            <code class="rounded-full border border-warning/30 bg-warning/10 px-3 py-1 text-xs text-warning">
              ai_rate_limited
            </code>
            <code class="rounded-full border border-warning/30 bg-warning/10 px-3 py-1 text-xs text-warning">
              ai_media_fetch_failed
            </code>
            <code class="rounded-full border border-warning/30 bg-warning/10 px-3 py-1 text-xs text-warning">
              ai_provider_timeout
            </code>
            <code class="rounded-full border border-warning/30 bg-warning/10 px-3 py-1 text-xs text-warning">
              ai_grounding_request_invalid
            </code>
          </div>
        </div>

        <%!-- Resources --%>
        <div class="mt-16">
          <.surface tag="div" variant="ghost" padding="lg" class="rounded-[2rem]">
            <h2 class="text-xl font-semibold">Resources</h2>
            <div class="mt-4 grid gap-4 sm:grid-cols-2">
              <a
                href="/api/v1"
                class="group rounded-2xl border border-base-300/60 bg-base-100 p-5 transition hover:border-primary/30"
              >
                <p class="font-semibold group-hover:text-primary">Live Endpoint Directory</p>
                <p class="mt-1 text-xs text-base-content/60">
                  GET /api/v1 — returns all endpoints with descriptions, always up to date.
                </p>
              </a>
              <a
                href="https://github.com"
                target="_blank"
                rel="noopener noreferrer"
                class="group rounded-2xl border border-base-300/60 bg-base-100 p-5 transition hover:border-primary/30"
              >
                <p class="font-semibold group-hover:text-primary">Mobile API Guide &#8599;</p>
                <p class="mt-1 text-xs text-base-content/60">
                  Human-readable guide with examples, upload flow walkthrough, and status reference.
                </p>
              </a>
            </div>
          </.surface>
        </div>

        <%!-- Back nav --%>
        <div class="mt-12 flex gap-4">
          <.link navigate={~p"/"} class="btn btn-ghost rounded-full">&#8592; Back to home</.link>
          <.link navigate={~p"/privacy"} class="btn btn-outline rounded-full">Privacy Policy</.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # -- Component helpers --

  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :badge, :string, default: nil
  slot :inner_block, required: true

  defp endpoint_group(assigns) do
    ~H"""
    <div class="mt-8">
      <div class="flex items-center gap-3">
        <div class="flex size-8 items-center justify-center rounded-xl bg-primary/10">
          <.icon name={@icon} class="size-4 text-primary" />
        </div>
        <h3 class="text-lg font-semibold">{@title}</h3>
        <span
          :if={@badge}
          class="rounded-full bg-base-200 px-2 py-0.5 text-[10px] font-medium uppercase tracking-widest text-base-content/50"
        >
          {@badge}
        </span>
      </div>
      <div class="mt-3 divide-y divide-base-300 overflow-hidden rounded-2xl border border-base-300">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :method, :string, required: true
  attr :path, :string, required: true
  attr :desc, :string, required: true
  attr :open, :boolean, default: false
  attr :args, :list, default: []
  attr :request_example, :any, default: nil
  attr :response_example, :any, default: nil

  defp endpoint(assigns) do
    color =
      case assigns.method do
        "GET" -> "text-emerald-600 bg-emerald-500/10"
        "POST" -> "text-blue-600 bg-blue-500/10"
        "PATCH" -> "text-amber-600 bg-amber-500/10"
        "PUT" -> "text-violet-600 bg-violet-500/10"
        "DELETE" -> "text-red-600 bg-red-500/10"
        _ -> "text-base-content/70 bg-base-200"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <div>
      <button
        type="button"
        phx-click="toggle_endpoint"
        phx-value-id={@id}
        class="flex w-full flex-wrap items-start gap-3 px-4 py-3 text-left text-sm transition-colors hover:bg-base-200/40"
      >
        <span class={[
          "inline-flex w-16 shrink-0 items-center justify-center rounded-lg px-2 py-1 text-xs font-bold",
          @color
        ]}>
          {@method}
        </span>
        <code class="min-w-0 break-all font-medium">{@path}</code>
        <span class="ml-auto flex items-center gap-2 text-xs text-base-content/55">
          {@desc}
          <.icon
            name={if @open, do: "hero-chevron-up", else: "hero-chevron-down"}
            class="size-3.5 shrink-0 text-base-content/40"
          />
        </span>
      </button>
      <div :if={@open} class="space-y-5 border-t border-base-300 bg-base-200/30 px-4 py-4">
        <%!-- Arguments table --%>
        <div :if={@args != []}>
          <p class="mb-2 text-xs font-semibold uppercase tracking-widest text-base-content/50">
            Parameters
          </p>
          <div class="overflow-hidden rounded-xl border border-base-300">
            <table class="w-full text-xs">
              <thead class="bg-base-200/60">
                <tr>
                  <th class="px-3 py-2 text-left font-semibold text-base-content/70">Name</th>
                  <th class="px-3 py-2 text-left font-semibold text-base-content/70">Type</th>
                  <th class="px-3 py-2 text-left font-semibold text-base-content/70">Required</th>
                  <th class="px-3 py-2 text-left font-semibold text-base-content/70">Description</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-300">
                <tr :for={arg <- @args}>
                  <td class="whitespace-nowrap px-3 py-2 font-mono font-medium text-primary">
                    {arg.name}
                  </td>
                  <td class="whitespace-nowrap px-3 py-2 text-base-content/60">{arg.type}</td>
                  <td class="px-3 py-2">
                    <span
                      :if={arg.required}
                      class="rounded-full bg-error/10 px-2 py-0.5 text-[10px] font-semibold text-error"
                    >
                      required
                    </span>
                    <span
                      :if={!arg.required}
                      class="rounded-full bg-base-300/60 px-2 py-0.5 text-[10px] text-base-content/40"
                    >
                      optional
                    </span>
                  </td>
                  <td class="px-3 py-2 text-base-content/65">{arg.desc}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <p :if={@args == []} class="text-xs italic text-base-content/40">No parameters.</p>
        <%!-- Request example --%>
        <div :if={@request_example}>
          <p class="mb-2 text-xs font-semibold uppercase tracking-widest text-base-content/50">
            Request Body
          </p>
          <pre class="overflow-x-auto rounded-xl border border-base-300 bg-base-900/5 px-4 py-3 text-xs leading-relaxed text-base-content/80">{@request_example}</pre>
        </div>
        <%!-- Response example --%>
        <div :if={@response_example}>
          <p class="mb-2 text-xs font-semibold uppercase tracking-widest text-base-content/50">
            Response
          </p>
          <pre class="overflow-x-auto rounded-xl border border-base-300 bg-base-900/5 px-4 py-3 text-xs leading-relaxed text-base-content/80">{@response_example}</pre>
        </div>
      </div>
    </div>
    """
  end
end
