# ResellerIO API Reference

## Overview

This backend is API-first and intended primarily for a mobile client.

Current public API base:

- `/api/v1`
- Machine-readable OpenAPI document: `/api/v1/openapi.json`
- Interactive docs UI: `/docs/api`

## Response Shape

Successful responses use:

```json
{
  "data": {}
}
```

Error responses use:

```json
{
  "error": {
    "code": "not_found",
    "detail": "Not Found",
    "status": 404
  }
}
```

## Authentication and Authorization

Protected routes require an API bearer token created by `POST /api/v1/auth/register` or `POST /api/v1/auth/login`.

Authentication rules:

- Send `Authorization: Bearer <token>` on every protected request.
- The auth scheme is accepted case-insensitively, so `Bearer` and `bearer` both work.
- Mobile bearer tokens currently expire 365 days after issuance, at the `expires_at` value returned by the auth endpoints.
- Tokens are stored server-side with `context: "mobile"` and the optional `device_name` supplied by the client.
- Successful protected requests update `api_tokens.last_used_at`.

Authorization rules:

- Missing, malformed, blank, or expired bearer tokens return `401`.
- Ownership-scoped resources return `404` when they belong to a different user.
- There is no refresh-token or logout API yet. Mobile clients should prompt for sign-in again after a `401`.

Mobile request example:

```text
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json
Accept: application/json
```

## Current Endpoints

### `GET /api/v1`

Returns API metadata and the currently available endpoints.

Example response:

```json
{
  "data": {
    "name": "resellerio",
    "version": "v1",
    "docs_path": "/docs/API.md",
    "docs_ui_path": "/docs/api",
    "openapi_path": "/api/v1/openapi.json",
    "endpoints": [
      {
        "method": "GET",
        "path": "/api/v1",
        "description": "Returns API metadata and the list of currently available endpoints."
      },
      {
        "method": "GET",
        "path": "/api/v1/health",
        "description": "Returns service health and application version information."
      },
      {
        "method": "POST",
        "path": "/api/v1/auth/register",
        "description": "Creates a user account and returns a bearer token."
      },
      {
        "method": "POST",
        "path": "/api/v1/auth/login",
        "description": "Authenticates a user and returns a bearer token."
      },
      {
        "method": "GET",
        "path": "/api/v1/me",
        "description": "Returns the authenticated user and marketplace settings."
      },
      {
        "method": "PATCH",
        "path": "/api/v1/me",
        "description": "Updates the authenticated user's marketplace settings."
      },
      {
        "method": "GET",
        "path": "/api/v1/product_tabs",
        "description": "Lists seller-defined product tabs for the authenticated user."
      },
      {
        "method": "POST",
        "path": "/api/v1/product_tabs",
        "description": "Creates one seller-defined product tab."
      },
      {
        "method": "PATCH",
        "path": "/api/v1/product_tabs/:id",
        "description": "Updates one seller-defined product tab."
      },
      {
        "method": "GET",
        "path": "/api/v1/storefront",
        "description": "Returns the authenticated user's storefront configuration."
      },
      {
        "method": "PUT",
        "path": "/api/v1/storefront",
        "description": "Creates or updates the authenticated user's storefront."
      },
      {
        "method": "GET",
        "path": "/api/v1/storefront/pages",
        "description": "Lists the authenticated user's storefront pages in display order."
      },
      {
        "method": "POST",
        "path": "/api/v1/storefront/pages",
        "description": "Creates one storefront page."
      },
      {
        "method": "PATCH",
        "path": "/api/v1/storefront/pages/:page_id",
        "description": "Updates one storefront page."
      },
      {
        "method": "DELETE",
        "path": "/api/v1/storefront/pages/:page_id",
        "description": "Deletes one storefront page."
      },
      {
        "method": "PUT",
        "path": "/api/v1/storefront/pages/order",
        "description": "Sets display positions for storefront pages using an ordered list of page IDs."
      },
      {
        "method": "POST",
        "path": "/api/v1/storefront/assets/:kind/prepare_upload",
        "description": "Creates or replaces a storefront logo or header asset record and returns a signed upload instruction."
      },
      {
        "method": "DELETE",
        "path": "/api/v1/storefront/assets/:kind",
        "description": "Deletes one storefront branding asset by kind."
      },
      {
        "method": "GET",
        "path": "/api/v1/products",
        "description": "Lists products for the authenticated user with filtering, sorting, and pagination."
      },
      {
        "method": "POST",
        "path": "/api/v1/products",
        "description": "Creates a product and optionally returns signed upload instructions."
      },
      {
        "method": "GET",
        "path": "/api/v1/products/:id",
        "description": "Returns one product for the authenticated user."
      },
      {
        "method": "PATCH",
        "path": "/api/v1/products/:id",
        "description": "Updates seller-managed product fields, storefront publication flags, and marketplace external URLs."
      },
      {
        "method": "DELETE",
        "path": "/api/v1/products/:id",
        "description": "Deletes one product and its related records."
      },
      {
        "method": "POST",
        "path": "/api/v1/products/:id/prepare_uploads",
        "description": "Creates upload placeholders for an existing product and returns signed upload instructions."
      },
      {
        "method": "POST",
        "path": "/api/v1/products/:id/finalize_uploads",
        "description": "Marks uploaded product images as ready for processing."
      },
      {
        "method": "POST",
        "path": "/api/v1/products/:id/reprocess",
        "description": "Restarts the core AI pipeline for one product."
      },
      {
        "method": "POST",
        "path": "/api/v1/products/:id/generate_lifestyle_images",
        "description": "Starts manual lifestyle-image generation for a review-ready product."
      },
      {
        "method": "GET",
        "path": "/api/v1/products/:id/lifestyle_generation_runs",
        "description": "Lists dedicated lifestyle-image generation runs for one product."
      },
      {
        "method": "POST",
        "path": "/api/v1/products/:id/generated_images/:image_id/approve",
        "description": "Marks one generated lifestyle preview as seller-approved."
      },
      {
        "method": "DELETE",
        "path": "/api/v1/products/:id/generated_images/:image_id",
        "description": "Deletes one generated lifestyle preview."
      },
      {
        "method": "DELETE",
        "path": "/api/v1/products/:id/images/:image_id",
        "description": "Deletes one uploaded product image and its processed variants."
      },
      {
        "method": "PATCH",
        "path": "/api/v1/products/:id/images/:image_id/storefront",
        "description": "Updates storefront visibility and display order for one product image."
      },
      {
        "method": "PUT",
        "path": "/api/v1/products/:id/images/storefront_order",
        "description": "Sets storefront_position for an ordered list of image IDs."
      },
      {
        "method": "POST",
        "path": "/api/v1/products/:id/mark_sold",
        "description": "Marks one product as sold."
      },
      {
        "method": "POST",
        "path": "/api/v1/products/:id/archive",
        "description": "Archives one product."
      },
      {
        "method": "POST",
        "path": "/api/v1/products/:id/unarchive",
        "description": "Restores one archived product."
      },
      {
        "method": "POST",
        "path": "/api/v1/exports",
        "description": "Queues a filtered ZIP export for the authenticated user with optional saved name and filter params."
      },
      {
        "method": "GET",
        "path": "/api/v1/exports/:id",
        "description": "Returns one export request for the authenticated user."
      },
      {
        "method": "POST",
        "path": "/api/v1/imports",
        "description": "Queues a ResellerIO ZIP import for the authenticated user using Products.xls, manifest.json, and images."
      },
      {
        "method": "GET",
        "path": "/api/v1/imports/:id",
        "description": "Returns one import request for the authenticated user."
      }
    ]
  }
}
```

### `GET /api/v1/health`

Returns a simple health payload for uptime checks and local verification.

Example response:

```json
{
  "data": {
    "name": "resellerio",
    "status": "ok",
    "version": "0.1.0"
  }
}
```

### `POST /api/v1/auth/register`

Creates a user account and returns a bearer token for the mobile client.

`device_name` and `selected_marketplaces` are optional. `device_name` is recommended so issued tokens are traceable to a specific client installation.

Request body:

```json
{
  "email": "seller@example.com",
  "password": "very-secure-password",
  "device_name": "iPhone",
  "selected_marketplaces": ["ebay", "depop", "poshmark"]
}
```

Response:

```json
{
  "data": {
    "token": "token-value",
    "token_type": "Bearer",
    "expires_at": "2026-04-28T18:00:00Z",
    "supported_marketplaces": [
      { "id": "ebay", "label": "eBay" },
      { "id": "depop", "label": "Depop" },
      { "id": "poshmark", "label": "Poshmark" },
      { "id": "mercari", "label": "Mercari" },
      { "id": "facebook_marketplace", "label": "Facebook Marketplace" },
      { "id": "offerup", "label": "OfferUp" },
      { "id": "whatnot", "label": "Whatnot" },
      { "id": "grailed", "label": "Grailed" },
      { "id": "therealreal", "label": "The RealReal" },
      { "id": "vestiaire_collective", "label": "Vestiaire Collective" },
      { "id": "thredup", "label": "thredUp" },
      { "id": "etsy", "label": "Etsy" }
    ],
    "user": {
      "id": 1,
      "email": "seller@example.com",
      "confirmed_at": null,
      "selected_marketplaces": ["ebay", "depop", "poshmark"]
    }
  }
}
```

Validation failures return `422` with field-level details.

### `POST /api/v1/auth/login`

Authenticates a user with email and password and returns a new bearer token.

`device_name` is optional but recommended for mobile installs.

Request body:

```json
{
  "email": "seller@example.com",
  "password": "very-secure-password",
  "device_name": "Pixel"
}
```

Successful responses use the same payload shape as `POST /api/v1/auth/register`, including `user.selected_marketplaces` and `supported_marketplaces`.

Invalid credentials return:

```json
{
  "error": {
    "code": "unauthorized",
    "detail": "Invalid email or password",
    "status": 401
  }
}
```

### `GET /api/v1/me`

Returns the authenticated user for the current bearer token.

Required header:

```text
Authorization: Bearer <token>
```

`bearer <token>` is also accepted.

Response:

```json
{
  "data": {
    "supported_marketplaces": [
      { "id": "ebay", "label": "eBay" },
      { "id": "depop", "label": "Depop" },
      { "id": "poshmark", "label": "Poshmark" },
      { "id": "mercari", "label": "Mercari" },
      { "id": "facebook_marketplace", "label": "Facebook Marketplace" },
      { "id": "offerup", "label": "OfferUp" },
      { "id": "whatnot", "label": "Whatnot" },
      { "id": "grailed", "label": "Grailed" },
      { "id": "therealreal", "label": "The RealReal" },
      { "id": "vestiaire_collective", "label": "Vestiaire Collective" },
      { "id": "thredup", "label": "thredUp" },
      { "id": "etsy", "label": "Etsy" }
    ],
    "user": {
      "id": 1,
      "email": "seller@example.com",
      "confirmed_at": null,
      "selected_marketplaces": ["ebay", "depop", "poshmark"]
    }
  }
}
```

### `PATCH /api/v1/me`

Updates the authenticated user’s marketplace-generation defaults.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "user": {
    "selected_marketplaces": ["ebay", "mercari", "etsy"]
  }
}
```

Response:

```json
{
  "data": {
    "supported_marketplaces": [
      { "id": "ebay", "label": "eBay" },
      { "id": "depop", "label": "Depop" },
      { "id": "poshmark", "label": "Poshmark" },
      { "id": "mercari", "label": "Mercari" },
      { "id": "facebook_marketplace", "label": "Facebook Marketplace" },
      { "id": "offerup", "label": "OfferUp" },
      { "id": "whatnot", "label": "Whatnot" },
      { "id": "grailed", "label": "Grailed" },
      { "id": "therealreal", "label": "The RealReal" },
      { "id": "vestiaire_collective", "label": "Vestiaire Collective" },
      { "id": "thredup", "label": "thredUp" },
      { "id": "etsy", "label": "Etsy" }
    ],
    "user": {
      "id": 1,
      "email": "seller@example.com",
      "confirmed_at": null,
      "selected_marketplaces": ["ebay", "mercari", "etsy"]
    }
  }
}
```

Notes:

- `selected_marketplaces` may be an empty array if the user wants to skip marketplace-copy generation for future runs.
- future processing and reprocessing runs generate `marketplace_listings` only for the selected marketplaces on the owning user account.

### `GET /api/v1/me/usage`

Returns current monthly usage counters, plan limits, and addon credits for the authenticated user.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "usage": {
      "ai_drafts": 0,
      "background_removals": 0,
      "lifestyle": 0,
      "price_research": 0
    },
    "limits": {
      "ai_drafts": 25,
      "background_removals": 25,
      "lifestyle": 10,
      "price_research": 25
    },
    "addon_credits": {}
  }
}
```

### `GET /api/v1/product_tabs`

Lists the authenticated user's seller-defined product tabs in display order.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "product_tabs": [
      {
        "id": 4,
        "name": "Outerwear",
        "position": 1,
        "inserted_at": "2026-03-31T12:00:00Z",
        "updated_at": "2026-03-31T12:00:00Z"
      }
    ]
  }
}
```

### `POST /api/v1/product_tabs`

Creates one seller-defined product tab.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "product_tab": {
    "name": "Shoes"
  }
}
```

Response status: `201 Created`

```json
{
  "data": {
    "product_tab": {
      "id": 5,
      "name": "Shoes",
      "position": 2,
      "inserted_at": "2026-03-31T12:05:00Z",
      "updated_at": "2026-03-31T12:05:00Z"
    }
  }
}
```

### `PATCH /api/v1/product_tabs/:id`

Renames one seller-defined product tab.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "product_tab": {
    "name": "Sneakers"
  }
}
```

Unknown or unauthorized tab IDs return:

```json
{
  "error": {
    "code": "not_found",
    "detail": "Product tab not found",
    "status": 404
  }
}
```

### `DELETE /api/v1/product_tabs/:id`

Deletes one seller-defined product tab. Products assigned to the deleted tab are not deleted; their `product_tab_id` is set to `null` by the database cascade.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "deleted": true
  }
}
```

Unknown or unauthorized tab IDs return `404`.

### `GET /api/v1/storefront`

Returns the authenticated user's storefront configuration. If no storefront has been saved yet, returns an unsaved record with `id: null`.

Storefront responses include `image_urls`, an ordered list of storefront asset URLs, and each entry in `assets` also includes its own `url`.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "storefront": {
      "id": 3,
      "slug": "my-store",
      "title": "My Store",
      "tagline": "Curated resale.",
      "description": "Secondhand fashion with fast shipping.",
      "theme_id": "neutral-warm",
      "enabled": true,
      "image_urls": [
        "https://cdn.example.test/users/1/storefronts/3/logo/logo.png"
      ],
      "assets": [
        {
          "id": 1,
          "kind": "logo",
          "storage_key": "users/1/storefronts/3/logo/logo.png",
          "url": "https://cdn.example.test/users/1/storefronts/3/logo/logo.png",
          "content_type": "image/png",
          "original_filename": "logo.png",
          "width": 400,
          "height": 400,
          "byte_size": 45000
        }
      ],
      "pages": [
        {
          "id": 2,
          "title": "About",
          "slug": "about",
          "menu_label": "About",
          "body": "Welcome to my store.",
          "position": 1,
          "published": true
        }
      ],
      "inserted_at": "2026-03-29T12:00:00Z",
      "updated_at": "2026-03-29T12:00:00Z"
    }
  }
}
```

### `PUT /api/v1/storefront`

Creates or updates the authenticated user's storefront. Safe to call multiple times — upserts on the user's single storefront record.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "storefront": {
    "slug": "my-store",
    "title": "My Store",
    "tagline": "Curated resale.",
    "description": "Secondhand fashion with fast shipping.",
    "theme_id": "neutral-warm",
    "enabled": true
  }
}
```

Response uses the same shape as `GET /api/v1/storefront`.

Validation failures return `422`.

### `GET /api/v1/storefront/pages`

Lists the authenticated user's storefront pages in display order.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "pages": [
      {
        "id": 2,
        "title": "About",
        "slug": "about",
        "menu_label": "About",
        "body": "Welcome to my store.",
        "position": 1,
        "published": true,
        "inserted_at": "2026-03-29T12:00:00Z",
        "updated_at": "2026-03-29T12:00:00Z"
      }
    ]
  }
}
```

### `POST /api/v1/storefront/pages`

Creates one storefront page. Requires a saved storefront.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "page": {
    "title": "Returns",
    "slug": "returns",
    "menu_label": "Returns",
    "body": "Full refunds within 30 days.",
    "published": true
  }
}
```

Response status: `201 Created`. Returns the new page using the shape from `GET /api/v1/storefront/pages`.

Returns `422 storefront_not_found` when no storefront profile has been saved yet.

### `PATCH /api/v1/storefront/pages/:page_id`

Updates one storefront page.

Required header:

```text
Authorization: Bearer <token>
```

Request body (all fields optional):

```json
{
  "page": {
    "title": "Shipping Policy",
    "body": "Ships in 1-2 business days.",
    "published": true
  }
}
```

Unknown or unauthorized page IDs return `404`.

### `DELETE /api/v1/storefront/pages/:page_id`

Deletes one storefront page.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "deleted": true
  }
}
```

Unknown or unauthorized page IDs return `404`.

### `PUT /api/v1/storefront/pages/order`

Reorders storefront pages by assigning positions from an ordered list of page IDs.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "page_ids": [7, 5, 6]
}
```

Response:

```json
{
  "data": {
    "pages": [
      {
        "id": 7,
        "title": "Shipping",
        "position": 1
      },
      {
        "id": 5,
        "title": "About",
        "position": 2
      }
    ]
  }
}
```

Unknown page IDs return `404`. Duplicate page IDs return `422`.

### `POST /api/v1/storefront/assets/:kind/prepare_upload`

Creates or replaces a storefront branding asset record and returns a signed upload instruction. Valid `kind` values are `logo` and `header`.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "asset": {
    "filename": "logo.png",
    "content_type": "image/png",
    "byte_size": 48000,
    "width": 400,
    "height": 400
  }
}
```

Response:

```json
{
  "data": {
    "asset": {
      "id": 9,
      "kind": "logo",
      "storage_key": "users/1/storefronts/3/logo/uuid.png",
      "content_type": "image/png",
      "original_filename": "logo.png",
      "width": 400,
      "height": 400,
      "byte_size": 48000
    },
    "upload_instruction": {
      "method": "PUT",
      "upload_url": "https://bucket.example.tigris.dev/...",
      "headers": {
        "content-type": "image/png"
      },
      "expires_at": "2026-03-29T18:40:00Z"
    }
  }
}
```

Returns `422 storefront_not_found` when no storefront profile has been saved yet.

### `DELETE /api/v1/storefront/assets/:kind`

Deletes one storefront branding asset. Valid `kind` values are `logo` and `header`.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "deleted": true
  }
}
```

Returns `404` when no asset of that kind exists.

### `GET /api/v1/inquiries`

Lists storefront inquiries for the authenticated user with search and pagination.

Required header:

```text
Authorization: Bearer <token>
```

Supported query params:

- `q`: full-text search across `full_name`, `contact`, and `message`
- `page`: 1-based page number
- `page_size`: optional positive integer, capped at 100 (default 20)

Response:

```json
{
  "data": {
    "inquiries": [
      {
        "id": 7,
        "full_name": "Jane Buyer",
        "contact": "jane@example.com",
        "message": "Is this still available?",
        "source_path": "/store/my-store/products/1-vintage-jacket",
        "product_id": 12,
        "inserted_at": "2026-03-30T15:22:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total_count": 1,
      "total_pages": 1
    }
  }
}
```

### `DELETE /api/v1/inquiries/:id`

Deletes one storefront inquiry for the authenticated user. Returns `404` for unknown or foreign-owned inquiries.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "deleted": true
  }
}
```

### `GET /api/v1/products`

Lists products for the authenticated user using the same filter model as the web workspace.

Required header:

```text
Authorization: Bearer <token>
```

Supported query params:

- `status`: `all`, `draft`, `uploading`, `processing`, `review`, `ready`, `sold`, `archived`
- `query`: full-text search across indexed product fields
- `product_tab_id`: optional seller-owned product tab filter
- `updated_from`: ISO date
- `updated_to`: ISO date
- `sort`: `title`, `status`, `price`, `updated_at`, `inserted_at`
- `dir`: `asc` or `desc`
- `page`: 1-based page number
- `page_size`: optional positive integer, capped at 100

Response:

```json
{
  "data": {
    "products": [
      {
        "id": 1,
        "status": "draft",
        "source": "manual",
        "title": "Vintage blazer",
        "brand": "Ralph Lauren",
        "category": "Blazers",
        "product_tab_id": 4,
        "product_tab": {
          "id": 4,
          "name": "Outerwear",
          "position": 1
        },
        "tags": ["vintage", "wool"],
        "latest_processing_run": null,
        "description_draft": null,
        "price_research": null,
        "marketplace_listings": [],
        "images": []
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 15,
      "total_count": 1,
      "total_pages": 1
    },
    "filters": {
      "status": "all",
      "query": null,
      "product_tab_id": null,
      "updated_from": null,
      "updated_to": null,
      "sort": "updated_at",
      "dir": "desc"
    }
  }
}
```

Notes:

- invalid or unknown filter values are normalized to the default filter set shown in `filters`
- the response always reflects the applied pagination and normalized filter state

### `POST /api/v1/products`

Creates a product. If `uploads` are included, the backend also creates `product_images`
placeholders and returns signed upload instructions.

Required header:

```text
Authorization: Bearer <token>
```

Request body without uploads:

```json
{
  "product": {
    "title": "Vintage blazer",
    "brand": "Ralph Lauren",
    "category": "Blazers",
    "product_tab_id": 4,
    "tags": ["vintage", "wool"]
  }
}
```

Request body with uploads:

```json
{
  "product": {
    "title": "Nike Air Max",
    "brand": "Nike",
    "category": "Sneakers",
    "tags": ["running", "air-max"]
  },
  "uploads": [
    {
      "filename": "shoe-1.jpg",
      "content_type": "image/jpeg",
      "byte_size": 345678
    }
  ]
}
```

Response:

```json
{
  "data": {
    "product": {
      "id": 1,
      "status": "uploading",
      "source": "manual",
      "title": "Nike Air Max",
      "brand": "Nike",
      "category": "Sneakers",
      "product_tab_id": 4,
      "product_tab": {
        "id": 4,
        "name": "Outerwear",
        "position": 1
      },
      "tags": ["running", "air-max"],
      "storefront_enabled": false,
      "storefront_published_at": null,
      "latest_processing_run": null,
      "description_draft": null,
      "price_research": null,
      "marketplace_listings": [],
      "image_urls": [
        "https://cdn.example.test/users/1/products/1/originals/uuid.jpg"
      ],
      "images": [
        {
          "id": 1,
          "kind": "original",
          "position": 1,
          "storage_key": "users/1/products/1/originals/uuid.jpg",
          "url": "https://cdn.example.test/users/1/products/1/originals/uuid.jpg",
          "content_type": "image/jpeg",
          "processing_status": "pending_upload",
          "original_filename": "shoe-1.jpg",
          "storefront_visible": false,
          "storefront_position": null
        }
      ]
    },
    "upload_instructions": [
      {
        "image_id": 1,
        "storage_key": "users/1/products/1/originals/uuid.jpg",
        "method": "PUT",
        "upload_url": "https://bucket.example.tigris.dev/...",
        "headers": {
          "content-type": "image/jpeg"
        },
        "expires_at": "2026-03-29T18:40:00Z"
      }
    ]
  }
}
```

Upload validation failures return `422`.

### `GET /api/v1/products/:id`

Returns one product for the authenticated user.

Required header:

```text
Authorization: Bearer <token>
```

Unknown or unauthorized product IDs return:

```json
{
  "error": {
    "code": "not_found",
    "detail": "Product not found",
    "status": 404
  }
}
```

Product payload notes:

- `product_tab_id` is optional and links a product to a seller-defined workspace tab.
- `product_tab` returns the current tab summary when one is assigned.
- `storefront_enabled` and `storefront_published_at` reflect whether the product is currently published on the seller's storefront.
- `latest_processing_run` returns the newest core AI-processing run, if one exists.
- `latest_lifestyle_generation_run` returns the newest dedicated lifestyle-image generation run, if one exists.
- `marketplace_listings[*].external_url` stores the seller-managed live listing URL for each marketplace when available.
- `image_urls` returns the ordered list of product image URLs for the current payload.
- `images[*].url` returns the CDN/public URL for that specific image record.
- `images[*].storefront_visible` and `images[*].storefront_position` control storefront gallery selection and ordering.
- each image now reserves lifecycle metadata for AI-generated lifestyle previews:
  - `lifestyle_generation_run_id`
  - `scene_key`
  - `variant_index`
  - `source_image_ids`
  - `seller_approved`
  - `approved_at`

Example excerpt:

```json
{
  "data": {
    "product": {
      "id": 12,
      "status": "ready",
      "storefront_enabled": true,
      "storefront_published_at": "2026-03-29T12:00:00Z",
      "image_urls": [
        "https://cdn.example.test/users/1/products/12/originals/front.jpg",
        "https://cdn.example.test/users/1/products/12/generated/model-studio-1.png"
      ],
      "latest_lifestyle_generation_run": {
        "id": 4,
        "status": "completed",
        "step": "lifestyle_generated",
        "scene_family": "apparel",
        "model": "gemini-2.5-flash-image",
        "prompt_version": "v1",
        "requested_count": 1,
        "completed_count": 1
      },
      "images": [
        {
          "id": 31,
          "kind": "original",
          "url": "https://cdn.example.test/users/1/products/12/originals/front.jpg",
          "storefront_visible": true,
          "storefront_position": 1
        },
        {
          "id": 44,
          "kind": "lifestyle_generated",
          "url": "https://cdn.example.test/users/1/products/12/generated/model-studio-1.png",
          "scene_key": "model_studio",
          "variant_index": 1,
          "lifestyle_generation_run_id": 4,
          "source_image_ids": [31],
          "seller_approved": false,
          "approved_at": null
        }
      ]
    }
  }
}
```

### `PATCH /api/v1/products/:id`

Updates seller-managed product fields for the authenticated user.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "product": {
    "title": "Updated title",
    "brand": "Patagonia",
    "product_tab_id": 4,
    "price": "99.00",
    "notes": "Measured and cleaned",
    "tags": ["outerwear", "denim"],
    "status": "review",
    "storefront_enabled": true
  },
  "marketplace_external_urls": {
    "ebay": "https://www.ebay.com/itm/1234567890"
  }
}
```

Editable fields currently include:

- `title`
- `brand`
- `category`
- `product_tab_id`
- `condition`
- `color`
- `size`
- `material`
- `price`
- `cost`
- `sku`
- `tags`
- `notes`
- `status`
- `storefront_enabled`

Seller-managed marketplace URLs can be updated with the top-level `marketplace_external_urls` object. Each key must be a supported marketplace ID and each value must be a valid `http` or `https` URL (or `null` / blank to clear a saved URL).

Manual status values accepted by this endpoint are:

- `draft`
- `review`
- `ready`
- `sold`
- `archived`

System-managed statuses like `uploading` and `processing`, and system fields like `source`, are still not seller-editable through this endpoint.

### `DELETE /api/v1/products/:id`

Deletes one product for the authenticated user. Related images, AI metadata, listings, processing runs, and lifestyle-generation runs are removed through cascading deletes.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "deleted": true
  }
}
```

### `POST /api/v1/products/:id/prepare_uploads`

Creates upload placeholders for an existing product and returns signed upload instructions so mobile can match the web review-screen upload flow.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "uploads": [
    {
      "filename": "detail-2.jpg",
      "content_type": "image/jpeg",
      "byte_size": 345678
    }
  ]
}
```

Response:

```json
{
  "data": {
    "product": {
      "id": 12,
      "status": "draft",
      "images": [
        {
          "id": 52,
          "kind": "original",
          "processing_status": "pending_upload",
          "original_filename": "detail-2.jpg"
        }
      ]
    },
    "upload_instructions": [
      {
        "image_id": 52,
        "storage_key": "users/1/products/12/originals/uuid.jpg",
        "method": "PUT",
        "upload_url": "https://bucket.example.tigris.dev/...",
        "headers": {
          "content-type": "image/jpeg"
        },
        "expires_at": "2026-03-29T18:40:00Z"
      }
    ]
  }
}
```

This endpoint returns `422 invalid_product_state` unless the product is still in `draft`, `review`, or `ready`.

### `POST /api/v1/products/:id/finalize_uploads`

Marks one or more pending upload placeholders as uploaded and transitions the product
to `processing` once all expected original images are finalized.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "uploads": [
    {
      "id": 1,
      "checksum": "abc123",
      "width": 1200,
      "height": 1600
    }
  ]
}
```

Response:

```json
{
  "data": {
    "product": {
      "id": 1,
      "status": "processing",
      "latest_processing_run": {
        "id": 12,
        "status": "queued",
        "step": "queued"
      },
      "description_draft": null,
      "price_research": null,
      "marketplace_listings": [],
      "images": [
        {
          "id": 1,
          "processing_status": "processing",
          "checksum": "abc123",
          "width": 1200,
          "height": 1600
        }
      ]
    },
    "finalized_images": [
      {
        "id": 1,
        "processing_status": "uploaded"
      }
    ],
    "processing_run": {
      "id": 12,
      "status": "queued",
      "step": "queued",
      "payload": {}
    }
  }
}
```

Current behavior notes:

- the finalize endpoint immediately creates a `product_processing_run`
- in production-style async execution, the returned run is typically still `queued` or `running`
- the worker uses finalized original uploads as Gemini and SerpApi inputs; Gemini downloads image bytes from storage-backed URLs and sends them inline, while SerpApi Lens still uses an external image URL
- when recognition finishes, the product moves to `ready` or `review`
- when description generation finishes, the product may also include a `description_draft` object with AI-authored base copy
- when price research finishes, the product may also include a `price_research` object with grounded price ranges and comparables
- when marketplace generation finishes, the product may also include `marketplace_listings` for the authenticated user's selected marketplaces
- when image-variant generation finishes, the product may also include a processed `background_removed` image for each uploaded original
- on success, in-flight images move from `processing` to `ready`
- on worker failure, the product falls back to `review`
- non-retryable worker failures move in-flight images from `processing` to `failed`
- retryable AI capacity failures keep original uploads retryable by moving them back to `uploaded`

When a paid user has exhausted their plan limit, `prepare_uploads`, `finalize_uploads`, `reprocess`, and `generate_lifestyle_images` return `402` with an absolute upgrade URL:

```json
{
  "error": "limit_exceeded",
  "operation": "ai_drafts",
  "used": 51,
  "limit": 50,
  "upgrade_url": "https://resellerio.com/pricing"
}
```

## Restart Product Processing

`POST /api/v1/products/:id/reprocess`

Restarts AI processing for a product that already has uploaded images.

Response example:

```json
{
  "data": {
    "product": {
      "id": 12,
      "status": "processing"
    },
    "processing_run": {
      "id": 18,
      "status": "queued",
      "step": "queued",
      "error_code": null,
      "error_message": null,
      "payload": {}
    }
  }
}
```

Notes:

- this is useful after retryable Gemini failures such as `ai_quota_exhausted` or `ai_rate_limited`
- the endpoint returns `202 Accepted`
- original product images are moved back to a retryable state before the new run is queued

## Lifestyle Preview Review Controls

### `POST /api/v1/products/:id/generate_lifestyle_images`

Starts seller-triggered lifestyle preview generation for a product that already reached `review`, `ready`, `sold`, or `archived`.

Optional request body:

```json
{
  "scene_key": "casual_lifestyle"
}
```

When `scene_key` is omitted, the backend generates the default 2-3 scene set. When it is provided, the backend regenerates only that scene profile.

Response example:

```json
{
  "data": {
    "product": {
      "id": 12,
      "latest_lifestyle_generation_run": {
        "id": 19,
        "status": "completed",
        "step": "lifestyle_generated",
        "requested_count": 3,
        "completed_count": 3
      }
    },
    "lifestyle_generation_run": {
      "id": 19,
      "status": "completed",
      "step": "lifestyle_generated",
      "requested_count": 3,
      "completed_count": 3
    }
  }
}
```

Notes:

- the endpoint returns `202 Accepted`
- seller-triggered generation works even while the auto-run rollout flag remains disabled
- invalid product states return `422 invalid_product_state`

### `GET /api/v1/products/:id/lifestyle_generation_runs`

Returns the dedicated lifestyle-image generation history for one product.

Response example:

```json
{
  "data": {
    "runs": [
      {
        "id": 19,
        "status": "completed",
        "step": "lifestyle_generated",
        "scene_family": "apparel",
        "requested_count": 3,
        "completed_count": 3
      }
    ]
  }
}
```

### `POST /api/v1/products/:id/generated_images/:image_id/approve`

Marks one generated lifestyle preview as seller-approved.

Response shape:

- returns the refreshed `product` payload
- the selected generated image now includes `"seller_approved": true` and an `approved_at` timestamp

### `DELETE /api/v1/products/:id/generated_images/:image_id`

Deletes one generated lifestyle preview.

Response shape:

```json
{
  "data": {
    "deleted": true,
    "product": {
      "id": 12,
      "status": "ready",
      "images": [...]
    }
  }
}
```

### `DELETE /api/v1/products/:id/images/:image_id`

Deletes one uploaded product image and all its associated processed variants (e.g. `background_removed`). The product must be in `draft`, `review`, or `ready` status.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "deleted": true,
    "product": {
      "id": 12,
      "status": "ready",
      "images": [...]
    }
  }
}
```

Returns `404` when the image does not belong to the product or the product does not belong to the authenticated user.

Returns `422 invalid_product_state` when the product is in `uploading`, `processing`, `sold`, or `archived` status.

### `PATCH /api/v1/products/:id/images/:image_id/storefront`

Updates the storefront visibility and/or display order position of a single product image.

Required header:

```text
Authorization: Bearer <token>
```

Request body (any subset of fields):

```json
{
  "storefront_visible": true,
  "storefront_position": 2
}
```

- `storefront_visible` — when `true` the image appears in the public storefront gallery.
- `storefront_position` — explicit display order (1-based); `null` falls back to upload `position`.

**Storefront gallery selection logic:**

When at least one image has `storefront_visible: true`, the public gallery shows only those images
in `storefront_position` order (nulls last, then `position`, then `id`).

When no image is `storefront_visible`, the gallery falls back in this priority order:
1. Approved `lifestyle_generated` images (`seller_approved: true`), sorted by `position, id`.
2. `background_removed` images, sorted by `position, id`.
3. `original` images only when neither of the above exist, sorted by `position, id`.

Only images with `processing_status: "ready"` are shown publicly in all cases.

Response:

```json
{
  "data": {
    "product": {
      "id": 12,
      "status": "ready",
      "images": [...]
    }
  }
}
```

Returns `404` when the image or product is not found or does not belong to the authenticated user.

### `PUT /api/v1/products/:id/images/storefront_order`

Sets the `storefront_position` for an ordered list of image IDs. Positions are assigned
1-to-N in the supplied order. This is the canonical way to reorder the storefront gallery.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "image_ids": [42, 17, 99]
}
```

Response:

```json
{
  "data": {
    "product": {
      "id": 12,
      "status": "ready",
      "images": [...]
    }
  }
}
```

Returns `404` when the product is not found or does not belong to the authenticated user.
Returns `400 bad_request` when `image_ids` is not a list.

### Product Processing Status

Product payloads now expose `latest_processing_run` so clients can track background progress without a separate worker endpoint yet.

Example:

```json
{
  "latest_processing_run": {
    "id": 12,
    "status": "completed",
    "step": "variants_generated",
    "started_at": "2026-03-29T20:30:00Z",
    "finished_at": "2026-03-29T20:30:01Z",
    "error_code": null,
    "error_message": null,
    "payload": {
      "pipeline_status": "recognized",
      "review_required": false,
      "description_draft": {
        "id": 9,
        "status": "generated",
        "suggested_title": "Nike Air Max 90",
        "short_description": "Classic Nike Air Max 90 sneakers in white mesh."
      },
      "price_research": {
        "id": 4,
        "status": "generated",
        "currency": "USD",
        "suggested_target_price": "125.00",
        "suggested_median_price": "126.00",
        "pricing_confidence": 0.82
      },
      "marketplace_listings": [
        {
          "marketplace": "ebay",
          "status": "generated",
          "generated_title": "Nike Air Max 90 Sneakers White Mesh",
          "generated_price_suggestion": "129.00"
        }
      ],
      "variant_generation": {
        "status": "generated",
        "count": 1,
        "variants": [
          {
            "kind": "background_removed",
            "background_style": "transparent",
            "processing_status": "ready"
          }
        ]
      },
      "final": {
        "brand": "Nike",
        "category": "Sneakers",
        "possible_model": "Air Max 90",
        "confidence_score": 0.91,
        "needs_review": false
      }
    }
  }
}
```

Run status values currently used:

- `queued`
- `running`
- `completed`
- `failed`

The `step` field is used to show finer-grained progress such as `queued`, `prepare_images`, `recognition_completed`, `description_generated`, `price_researched`, `marketplace_listings_generated`, `variants_generated`, and `variants_failed`.

For retryable AI failures, `error_code` may now be:

- `ai_quota_exhausted`
- `ai_rate_limited`
- `ai_media_fetch_failed`
- `ai_provider_timeout`
- `ai_grounding_request_invalid`

### Description Drafts

Product payloads may include a `description_draft` object after AI processing completes:

```json
{
  "description_draft": {
    "id": 9,
    "status": "generated",
    "provider": "gemini",
    "model": "gemini-2.5-flash",
    "suggested_title": "Nike Air Max 90",
    "short_description": "Classic Nike Air Max 90 sneakers in white mesh.",
    "long_description": "White Nike Air Max 90 sneakers with breathable mesh and a visible air unit.",
    "key_features": ["Visible air unit", "Mesh upper"],
    "seo_keywords": ["nike air max 90", "white sneakers"],
    "missing_details_warning": null
  }
}
```

These drafts are AI-authored base copy and are stored separately from editable product fields.

### Price Research

Product payloads may include a `price_research` object after AI processing completes:

```json
{
  "price_research": {
    "id": 4,
    "status": "generated",
    "provider": "gemini",
    "model": "gemini-2.5-flash",
    "currency": "USD",
    "suggested_min_price": "110.00",
    "suggested_target_price": "125.00",
    "suggested_max_price": "145.00",
    "suggested_median_price": "126.00",
    "pricing_confidence": 0.82,
    "rationale_summary": "Recent comparable sales center around the mid-120s.",
    "market_signals": ["Strong sneaker demand"],
    "comparable_results": [
      {
        "title": "Nike Air Max 90",
        "price": 129.0,
        "source": "GOAT"
      }
    ]
  }
}
```

This record is advisory pricing data and is stored separately from any user-entered sale price on the product.

### Marketplace Listings

Product payloads may include a `marketplace_listings` array after AI processing completes:

```json
{
  "marketplace_listings": [
    {
      "id": 11,
      "marketplace": "ebay",
      "status": "generated",
      "generated_title": "Nike Air Max 90 Sneakers White Mesh",
      "generated_description": "eBay-ready sneaker listing copy.",
      "generated_tags": ["nike", "air max 90", "sneakers"],
      "generated_price_suggestion": "129.00",
      "generation_version": "gemini-marketplace-v1",
      "compliance_warnings": [],
      "external_url": "https://www.ebay.com/itm/1234567890"
    },
    {
      "id": 12,
      "marketplace": "depop",
      "status": "generated",
      "generated_title": "Nike Air Max 90 white mesh runners",
      "generated_description": "Depop-ready sneaker listing copy.",
      "generated_tags": ["nike", "runners", "streetwear"],
      "generated_price_suggestion": "127.00",
      "generation_version": "gemini-marketplace-v1",
      "compliance_warnings": [],
      "external_url": null
    }
  ]
}
```

These records are generated per marketplace and can be regenerated without overwriting core product fields. Supported marketplace IDs currently include `ebay`, `depop`, `poshmark`, `mercari`, `facebook_marketplace`, `offerup`, `whatnot`, `grailed`, `therealreal`, `vestiaire_collective`, `thredup`, and `etsy`. Generation uses the authenticated user's current `selected_marketplaces` list.

### Image Variants

The `images` array may include processed variants in addition to originals:

```json
{
  "images": [
    {
      "kind": "original",
      "position": 1,
      "processing_status": "ready"
    },
    {
      "kind": "background_removed",
      "position": 1,
      "background_style": "transparent",
      "processing_status": "ready"
    }
  ]
}
```

These processed variants are stored as additional `product_images`; the original upload is preserved.

If the provided image IDs do not belong to the selected product, the API returns:

```json
{
  "error": {
    "code": "invalid_uploads",
    "detail": "Uploads must belong to the selected product",
    "status": 422
  }
}
```

### `POST /api/v1/products/:id/mark_sold`

Marks one product as sold and sets `sold_at`.

Required header:

```text
Authorization: Bearer <token>
```

Response payloads reuse the standard product representation, with `status` set to `sold`.

### `POST /api/v1/products/:id/archive`

Archives one product and sets `archived_at`.

Required header:

```text
Authorization: Bearer <token>
```

Response payloads reuse the standard product representation, with `status` set to `archived`.

### `POST /api/v1/products/:id/unarchive`

Restores one archived product. If the product already has `sold_at`, it returns to `sold`; otherwise it returns to `ready`.

Required header:

```text
Authorization: Bearer <token>
```

### `POST /api/v1/exports`

Queues an export for the authenticated user. The export is built in the background, uploaded to storage, and emailed once ready.

Required header:

```text
Authorization: Bearer <token>
```

Request:

```json
{
  "export": {
    "name": "Fila ready inventory",
    "filters": {
      "query": "fila",
      "product_tab_id": 4,
      "status": "ready",
      "updated_from": "2026-03-01",
      "updated_to": "2026-03-31"
    }
  }
}
```

The `export` payload is optional. If omitted, the backend exports the full product catalog.

Response status: `202 Accepted`

The returned export record may be `queued`, `running`, `completed`, `failed`, or `stalled` depending on when the worker updates the record. `stalled` means a queued/running export sat unchanged past the worker timeout window and needs attention or a retry.

Example response:

```json
{
  "data": {
    "export": {
      "id": 1,
      "name": "Fila ready inventory",
      "file_name": "fila-ready-inventory-20260331-060045.zip",
      "filter_params": {
        "query": "fila",
        "product_tab_id": 4,
        "product_tab_name": "Outerwear",
        "status": "ready",
        "updated_from": "2026-03-01",
        "updated_to": "2026-03-31"
      },
      "product_count": 4,
      "status": "queued",
      "storage_key": null,
      "download_url": null,
      "requested_at": "2026-03-30T01:10:00Z",
      "completed_at": null,
      "expires_at": null,
      "error_message": null
    }
  }
}
```

### `GET /api/v1/exports/:id`

Returns one export record for the authenticated user.

Required header:

```text
Authorization: Bearer <token>
```

Completed exports include a `storage_key`, a `download_url`, and `expires_at`.
The generated ZIP contains `Products.xls`, `manifest.json`, and product image files under `images/<product_id>/...`.
Stale in-flight exports are returned as `stalled` with an `error_message` explaining that the background job stopped making progress.

Unknown or unauthorized export IDs return:

```json
{
  "error": {
    "code": "not_found",
    "detail": "Export not found",
    "status": 404
  }
}
```

### `POST /api/v1/imports`

Queues an import for the authenticated user. The current API accepts the ZIP archive as base64 in JSON, stores the source archive, and then recreates products in the background.
ResellerIO-generated archives should include `Products.xls`, `manifest.json`, and `images/*`.

Required header:

```text
Authorization: Bearer <token>
```

Request:

```json
{
  "import": {
    "filename": "catalog.zip",
    "archive_base64": "<base64 zip archive>"
  }
}
```

Response status: `202 Accepted`

Example response:

```json
{
  "data": {
    "import": {
      "id": 1,
      "status": "queued",
      "source_filename": "catalog.zip",
      "source_storage_key": "users/1/imports/1/source.zip",
      "requested_at": "2026-03-30T02:10:00Z",
      "started_at": null,
      "finished_at": null,
      "total_products": 0,
      "imported_products": 0,
      "failed_products": 0,
      "error_message": null,
      "failure_details": {},
      "payload": {}
    }
  }
}
```

Validation failures return:

```json
{
  "error": {
    "code": "validation_failed",
    "detail": "Validation failed",
    "status": 422,
    "fields": {
      "archive_base64": ["must be valid base64"]
    }
  }
}
```

### `GET /api/v1/imports/:id`

Returns one import record for the authenticated user.

Required header:

```text
Authorization: Bearer <token>
```

Completed imports report archive-level totals plus any per-product failures under `failure_details.items`.

Unknown or unauthorized import IDs return:

```json
{
  "error": {
    "code": "not_found",
    "detail": "Import not found",
    "status": 404
  }
}
```

## Conventions

- New endpoints should be added under the versioned `/api/v1` namespace.
- When new endpoints are introduced, update this file in the same feature commit.
- Keep error payloads stable for mobile clients.
- Prefer explicit, machine-readable statuses and error codes.
- Protected endpoints should use bearer-token authentication.

---

## Webhook Endpoint

### `POST /webhooks/lemonsqueezy`

Receives LemonSqueezy subscription and payment events.

**Authentication:** HMAC-SHA256 signature in `X-Signature` header (hex-encoded). Secret configured via `LEMONSQUEEZY_WEBHOOK_SECRET`.

**Pipeline:** Outside all auth pipelines. No CSRF. No session.

**Response:** `200` if signature valid (processing is async). `401` for bad signature. `400` for unparseable body.

**Handled events:**

| Event | Action |
|---|---|
| `subscription_created` | Assign plan to user, send welcome email |
| `subscription_updated` | Update plan tier/status/variant |
| `subscription_renewed` | Extend `plan_expires_at`, reset reminder flags, send renewal email |
| `subscription_cancelled` | Set `plan_status: "canceling"`, set `plan_expires_at` |
| `subscription_expired` | Revert user to free plan, send expiry email |
| `subscription_payment_failed` | Set `plan_status: "past_due"`, send payment failure email |
| `order_created` | Credit add-on pack to user's `addon_credits` |

**User attribution (priority order):**
1. `custom_data.user_id` embedded in checkout URL
2. `user_email` in payload matched against registered accounts
3. `ls_subscription_id` matched against existing subscription records

**Limit exceeded (402)** — returned by `prepare_uploads`, `finalize_uploads`, `reprocess`, and `generate_lifestyle_images` for paid users over their monthly limit:

```json
{
  "error": "limit_exceeded",
  "operation": "ai_drafts",
  "used": 52,
  "limit": 50,
  "upgrade_url": "https://resellerio.com/pricing"
}
```
