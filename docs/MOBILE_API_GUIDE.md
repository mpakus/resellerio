# ResellerIO Mobile API Guide

> A practical guide for mobile app developers integrating with the ResellerIO backend.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Authentication](#authentication)
3. [User Profile & Marketplaces](#user-profile--marketplaces)
4. [Products](#products)
5. [Image Uploads & Processing](#image-uploads--processing)
6. [AI Processing Pipeline](#ai-processing-pipeline)
7. [Lifestyle Image Generation](#lifestyle-image-generation)
8. [Storefront Image Curation](#storefront-image-curation)
9. [Product Tabs](#product-tabs)
10. [Storefront](#storefront)
11. [Inquiries](#inquiries)
12. [Exports & Imports](#exports--imports)
13. [Error Handling](#error-handling)
14. [Quick Reference](#quick-reference)

---

## Getting Started

**Base URL:** `/api/v1`

**Content type:** All requests and responses use `application/json`.

**Discovery endpoint:** `GET /api/v1` returns the full list of available endpoints with descriptions.

**Health check:** `GET /api/v1/health` returns `{"data": {"status": "ok"}}` for uptime monitoring.

### Every Request Should Include

```
Content-Type: application/json
Accept: application/json
Authorization: Bearer <token>   ← on protected endpoints
```

---

## Authentication

ResellerIO uses bearer tokens. Register or log in to receive a token, then send it on every subsequent request.

### Register a New Account

```
POST /api/v1/auth/register
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `email` | string | ✅ | Must be a valid email address |
| `password` | string | ✅ | Minimum length enforced server-side |
| `device_name` | string | — | Recommended. Tags the token so you can identify which device it belongs to |
| `selected_marketplaces` | string[] | — | e.g. `["ebay", "depop"]`. Sets initial marketplace preferences |

**Example request:**

```json
{
  "email": "seller@example.com",
  "password": "very-secure-password",
  "device_name": "iPhone 15 Pro",
  "selected_marketplaces": ["ebay", "depop", "poshmark"]
}
```

**Example response:**

```json
{
  "data": {
    "token": "SFMyNTY...",
    "token_type": "Bearer",
    "expires_at": "2026-04-28T18:00:00Z",
    "user": {
      "id": 1,
      "email": "seller@example.com",
      "confirmed_at": null,
      "selected_marketplaces": ["ebay", "depop", "poshmark"]
    },
    "supported_marketplaces": [
      {"id": "ebay", "label": "eBay"},
      {"id": "depop", "label": "Depop"},
      {"id": "poshmark", "label": "Poshmark"},
      {"id": "mercari", "label": "Mercari"},
      {"id": "facebook_marketplace", "label": "Facebook Marketplace"},
      {"id": "offerup", "label": "OfferUp"},
      {"id": "whatnot", "label": "Whatnot"},
      {"id": "grailed", "label": "Grailed"},
      {"id": "therealreal", "label": "The RealReal"},
      {"id": "vestiaire_collective", "label": "Vestiaire Collective"},
      {"id": "thredup", "label": "thredUp"},
      {"id": "etsy", "label": "Etsy"}
    ]
  }
}
```

### Log In

```
POST /api/v1/auth/login
```

| Field | Type | Required |
|-------|------|----------|
| `email` | string | ✅ |
| `password` | string | ✅ |
| `device_name` | string | — |

Returns the same response shape as registration. Invalid credentials return `401`.

### Token Lifecycle

- Store the `token` securely (Keychain / EncryptedSharedPreferences).
- Tokens expire at `expires_at`. There is no refresh endpoint — prompt the user to sign in again on `401`.
- The scheme is case-insensitive: both `Bearer` and `bearer` work.

---

## User Profile & Marketplaces

### Get Current User

```
GET /api/v1/me
```

Returns `user` details and the full `supported_marketplaces` catalog. Use this on app launch to hydrate local state.

### Update Marketplace Preferences

```
PATCH /api/v1/me
```

```json
{
  "user": {
    "selected_marketplaces": ["ebay", "mercari", "etsy"]
  }
}
```

These preferences control which marketplace-specific listings the AI generates during product processing. An empty array skips marketplace copy generation entirely.

---

## Products

### List Products

```
GET /api/v1/products
```

| Query Param | Values | Default |
|-------------|--------|---------|
| `status` | `all`, `draft`, `uploading`, `processing`, `review`, `ready`, `sold`, `archived` | `all` |
| `query` | Free-text search | — |
| `product_tab_id` | Integer tab ID | — |
| `updated_from` | ISO date (`2026-03-01`) | — |
| `updated_to` | ISO date (`2026-03-31`) | — |
| `sort` | `title`, `status`, `price`, `updated_at`, `inserted_at` | `updated_at` |
| `dir` | `asc`, `desc` | `desc` |
| `page` | 1-based integer | `1` |
| `page_size` | 1–100 | `15` |

The response always includes a `pagination` object and a `filters` object reflecting the normalized values actually applied.

### Get One Product

```
GET /api/v1/products/:id
```

Returns the full product payload including `images`, `description_draft`, `price_research`, `marketplace_listings`, `latest_processing_run`, and `latest_lifestyle_generation_run`.

### Create a Product

```
POST /api/v1/products
```

```json
{
  "product": {
    "title": "Nike Air Max 90",
    "brand": "Nike",
    "category": "Sneakers",
    "product_tab_id": 4,
    "tags": ["running", "air-max"]
  },
  "uploads": [
    {
      "filename": "shoe-front.jpg",
      "content_type": "image/jpeg",
      "byte_size": 345678
    }
  ]
}
```

The `uploads` array is optional. When included, the response contains `upload_instructions` with pre-signed URLs. See [Image Uploads](#image-uploads--processing) below.

Returns `201 Created`.

### Update a Product

```
PATCH /api/v1/products/:id
```

**Editable fields:** `title`, `brand`, `category`, `product_tab_id`, `condition`, `color`, `size`, `material`, `price`, `cost`, `sku`, `tags`, `notes`, `status`

**Allowed manual status transitions:** `draft`, `review`, `ready`, `sold`, `archived`

System statuses (`uploading`, `processing`) and system fields (`source`) cannot be set manually.

### Delete a Product

```
DELETE /api/v1/products/:id
```

Cascading delete — removes all images, AI data, listings, and processing runs.

### Mark as Sold

```
POST /api/v1/products/:id/mark_sold
```

Sets `status` to `sold` and records `sold_at`.

### Archive / Unarchive

```
POST /api/v1/products/:id/archive
POST /api/v1/products/:id/unarchive
```

Unarchive restores to `sold` (if previously sold) or `ready`.

---

## Image Uploads & Processing

ResellerIO uses a three-step upload flow:

### Step 1 — Create product with upload metadata

Include `uploads` in `POST /api/v1/products`. Each entry needs `filename`, `content_type`, and `byte_size`.

### Step 2 — Upload files directly to storage

The response includes `upload_instructions`:

```json
{
  "upload_instructions": [
    {
      "image_id": 1,
      "storage_key": "users/1/products/1/originals/uuid.jpg",
      "method": "PUT",
      "upload_url": "https://bucket.example.tigris.dev/...",
      "headers": {"content-type": "image/jpeg"},
      "expires_at": "2026-03-29T18:40:00Z"
    }
  ]
}
```

Upload each file with a `PUT` request to `upload_url`, including the specified headers. The URL is pre-signed and expires at the given time.

### Step 3 — Finalize uploads

```
POST /api/v1/products/:id/finalize_uploads
```

```json
{
  "uploads": [
    {"id": 1, "checksum": "abc123", "width": 1200, "height": 1600}
  ]
}
```

This marks images as uploaded and automatically starts AI processing. The product moves to `processing` status.

### Delete an Image

```
DELETE /api/v1/products/:id/images/:image_id
```

Removes one original image and its processed variants (e.g. `background_removed`). Only works while the product is in `draft`, `review`, or `ready` status.

---

## AI Processing Pipeline

After upload finalization, the backend runs an AI pipeline that produces:

| Output | Description |
|--------|-------------|
| **Recognition** | Brand, category, model identification with confidence scores |
| **Description Draft** | AI-authored title, short/long descriptions, key features, SEO keywords |
| **Price Research** | Min/target/max/median price suggestions with confidence, rationale, and comparables |
| **Marketplace Listings** | Per-marketplace titles, descriptions, tags, and price suggestions |
| **Background Removal** | Transparent-background variant of each original image |

### Tracking Progress

Poll `GET /api/v1/products/:id` and inspect `latest_processing_run`:

| `status` | Meaning |
|-----------|---------|
| `queued` | Waiting in the job queue |
| `running` | Pipeline is active |
| `completed` | All steps finished successfully |
| `failed` | An error occurred (check `error_code` and `error_message`) |

The `step` field gives finer detail: `queued` → `prepare_images` → `recognition_completed` → `description_generated` → `price_researched` → `marketplace_listings_generated` → `variants_generated`.

### Reprocessing After Failure

```
POST /api/v1/products/:id/reprocess
```

Returns `202 Accepted`. Useful after transient AI failures like `ai_quota_exhausted` or `ai_rate_limited`.

### Retryable Error Codes

| Code | Meaning |
|------|---------|
| `ai_quota_exhausted` | Provider quota exceeded |
| `ai_rate_limited` | Too many requests to the AI provider |
| `ai_media_fetch_failed` | Could not download the image for processing |
| `ai_provider_timeout` | AI provider timed out |
| `ai_grounding_request_invalid` | Grounding search request was rejected |

---

## Lifestyle Image Generation

After AI processing completes, you can generate styled lifestyle previews.

### Generate Lifestyle Images

```
POST /api/v1/products/:id/generate_lifestyle_images
```

Optional body:

```json
{"scene_key": "casual_lifestyle"}
```

Omit `scene_key` for the default 2–3 scene set. Returns `202 Accepted`.

The product must be in `review`, `ready`, `sold`, or `archived` status.

### View Generation History

```
GET /api/v1/products/:id/lifestyle_generation_runs
```

Returns all generation runs with status, scene family, model, and counts.

### Approve a Generated Image

```
POST /api/v1/products/:id/generated_images/:image_id/approve
```

Marks the image as seller-approved (`seller_approved: true`, `approved_at` is set). Approved images get priority in the storefront gallery.

### Delete a Generated Image

```
DELETE /api/v1/products/:id/generated_images/:image_id
```

Removes one generated lifestyle preview.

---

## Storefront Image Curation

Control which images appear in your public storefront and in what order.

### Update One Image's Storefront Settings

```
PATCH /api/v1/products/:id/images/:image_id/storefront
```

```json
{
  "storefront_visible": true,
  "storefront_position": 2
}
```

### Reorder All Storefront Images

```
PUT /api/v1/products/:id/images/storefront_order
```

```json
{
  "image_ids": [42, 17, 99]
}
```

Positions are assigned 1-to-N in the supplied order.

### Storefront Gallery Fallback Logic

If no images are explicitly marked `storefront_visible`, the public gallery auto-selects in this order:

1. Approved lifestyle images (`seller_approved: true`)
2. Background-removed images
3. Original images (last resort)

Only images with `processing_status: "ready"` are shown publicly.

---

## Product Tabs

Tabs let sellers organize products into custom groups like "Outerwear" or "Sneakers".

### List Tabs

```
GET /api/v1/product_tabs
```

### Create a Tab

```
POST /api/v1/product_tabs
```

```json
{"product_tab": {"name": "Shoes"}}
```

Returns `201 Created`.

### Rename a Tab

```
PATCH /api/v1/product_tabs/:id
```

```json
{"product_tab": {"name": "Sneakers"}}
```

### Delete a Tab

```
DELETE /api/v1/product_tabs/:id
```

Products in the deleted tab keep their data — their `product_tab_id` is set to `null`.

---

## Storefront

Each user has one storefront — a public-facing mini-site for their inventory.

### Get Storefront

```
GET /api/v1/storefront
```

Returns the storefront config with `assets` (logo, header images) and `pages`. Returns `id: null` if no storefront has been saved yet.

### Create or Update Storefront

```
PUT /api/v1/storefront
```

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

Safe to call repeatedly — upserts on the user's single record.

### Storefront Pages

| Action | Method | Path |
|--------|--------|------|
| List pages | `GET` | `/api/v1/storefront/pages` |
| Create page | `POST` | `/api/v1/storefront/pages` |
| Update page | `PATCH` | `/api/v1/storefront/pages/:page_id` |
| Delete page | `DELETE` | `/api/v1/storefront/pages/:page_id` |

**Create/update body:**

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

A storefront must be saved before you can create pages.

### Delete Branding Assets

```
DELETE /api/v1/storefront/assets/:kind
```

Valid `kind` values: `logo`, `header`.

---

## Inquiries

Inquiries are messages submitted by visitors through the public storefront.

### List Inquiries

```
GET /api/v1/inquiries
```

| Query Param | Type | Default |
|-------------|------|---------|
| `q` | search string | — |
| `page` | integer | `1` |
| `page_size` | 1–100 | `20` |

### Delete an Inquiry

```
DELETE /api/v1/inquiries/:id
```

---

## Exports & Imports

### Create an Export

```
POST /api/v1/exports
```

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

The `export` payload is optional — omit it to export your full catalog.

Returns `202 Accepted`. The ZIP is built in the background and includes `Products.xls`, `manifest.json`, and images.

### Check Export Status

```
GET /api/v1/exports/:id
```

| `status` | Meaning |
|-----------|---------|
| `queued` | Waiting to start |
| `running` | Building the ZIP |
| `completed` | Ready — `download_url` is populated |
| `failed` | Error — check `error_message` |
| `stalled` | Background job stopped responding |

### Create an Import

```
POST /api/v1/imports
```

```json
{
  "import": {
    "filename": "catalog.zip",
    "archive_base64": "<base64-encoded ZIP>"
  }
}
```

Returns `202 Accepted`. The archive is processed in the background.

### Check Import Status

```
GET /api/v1/imports/:id
```

Completed imports report `total_products`, `imported_products`, `failed_products`, and per-item `failure_details`.

---

## Error Handling

### Standard Error Shape

Every error response uses this consistent structure:

```json
{
  "error": {
    "code": "not_found",
    "detail": "Product not found",
    "status": 404
  }
}
```

### Validation Errors (422)

Include field-level details:

```json
{
  "error": {
    "code": "validation_failed",
    "detail": "Validation failed",
    "status": 422,
    "fields": {
      "email": ["has already been taken"],
      "password": ["should be at least 8 character(s)"]
    }
  }
}
```

### Common HTTP Status Codes

| Code | When |
|------|------|
| `200` | Successful read or update |
| `201` | Resource created |
| `202` | Accepted for background processing (exports, imports, reprocess) |
| `400` | Malformed request (e.g. missing required payload key) |
| `401` | Missing, expired, or invalid bearer token |
| `404` | Resource not found or belongs to another user |
| `422` | Validation failed or invalid state transition |
| `502` | Upstream service unavailable (e.g. storage signing failed) |

### Common Error Codes

| Code | Description |
|------|-------------|
| `unauthorized` | Authentication failed |
| `not_found` | Resource does not exist or is not owned by you |
| `validation_failed` | Input validation errors (check `fields`) |
| `invalid_product_state` | The product is in a status that doesn't allow this action |
| `invalid_uploads` | Upload IDs don't belong to the product |
| `storage_unavailable` | Object storage is not configured |
| `upload_signing_failed` | Could not generate pre-signed upload URL |

---

## Quick Reference

### Public Endpoints (no auth required)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1` | API metadata and endpoint list |
| `GET` | `/api/v1/health` | Health check |
| `POST` | `/api/v1/auth/register` | Create account and get token |
| `POST` | `/api/v1/auth/login` | Log in and get token |

### User & Settings

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/me` | Get current user |
| `PATCH` | `/api/v1/me` | Update marketplace preferences |

### Products

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/products` | List with filters and pagination |
| `POST` | `/api/v1/products` | Create (with optional uploads) |
| `GET` | `/api/v1/products/:id` | Get one product |
| `PATCH` | `/api/v1/products/:id` | Update product fields |
| `DELETE` | `/api/v1/products/:id` | Delete product |
| `POST` | `/api/v1/products/:id/finalize_uploads` | Finalize uploaded images → start AI |
| `POST` | `/api/v1/products/:id/reprocess` | Retry AI processing |
| `POST` | `/api/v1/products/:id/mark_sold` | Mark as sold |
| `POST` | `/api/v1/products/:id/archive` | Archive |
| `POST` | `/api/v1/products/:id/unarchive` | Unarchive |

### Product Images

| Method | Path | Description |
|--------|------|-------------|
| `DELETE` | `/api/v1/products/:id/images/:image_id` | Delete an image |
| `PATCH` | `/api/v1/products/:id/images/:image_id/storefront` | Set storefront visibility/position |
| `PUT` | `/api/v1/products/:id/images/storefront_order` | Reorder storefront images |

### Lifestyle Images

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/products/:id/generate_lifestyle_images` | Generate lifestyle previews |
| `GET` | `/api/v1/products/:id/lifestyle_generation_runs` | Generation history |
| `POST` | `/api/v1/products/:id/generated_images/:image_id/approve` | Approve a preview |
| `DELETE` | `/api/v1/products/:id/generated_images/:image_id` | Delete a preview |

### Product Tabs

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/product_tabs` | List tabs |
| `POST` | `/api/v1/product_tabs` | Create tab |
| `PATCH` | `/api/v1/product_tabs/:id` | Rename tab |
| `DELETE` | `/api/v1/product_tabs/:id` | Delete tab |

### Storefront

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/storefront` | Get storefront config |
| `PUT` | `/api/v1/storefront` | Create or update storefront |
| `GET` | `/api/v1/storefront/pages` | List pages |
| `POST` | `/api/v1/storefront/pages` | Create page |
| `PATCH` | `/api/v1/storefront/pages/:page_id` | Update page |
| `DELETE` | `/api/v1/storefront/pages/:page_id` | Delete page |
| `DELETE` | `/api/v1/storefront/assets/:kind` | Delete logo or header |

### Inquiries

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/inquiries` | List inquiries |
| `DELETE` | `/api/v1/inquiries/:id` | Delete inquiry |

### Exports & Imports

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/exports` | Create export |
| `GET` | `/api/v1/exports/:id` | Check export status |
| `POST` | `/api/v1/imports` | Create import |
| `GET` | `/api/v1/imports/:id` | Check import status |
