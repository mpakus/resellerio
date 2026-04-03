# ResellerIO API

The full machine-readable contract lives at `/api/v1/openapi.json`. This file is the compressed human guide.

Interactive docs: `/docs/api`

## Conventions

Base path:

- `/api/v1`

Content type:

- request: `application/json`
- response: `application/json`

Auth:

- protected routes require `Authorization: Bearer <token>`
- browser clients can send `OPTIONS` preflight requests to `/api/v1/*`; API responses include CORS headers

Response envelope:

```json
{"data": {...}}
```

Error envelope:

```json
{
  "error": {
    "code": "not_found",
    "detail": "Product not found",
    "status": 404
  }
}
```

Validation errors use `code: "validation_failed"` and a `fields` object.

Limit failures use `402` with:

- `error: "limit_exceeded"`
- `operation`
- `used`
- `limit`
- `upgrade_url`

## Public Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1` | API discovery payload |
| `GET` | `/api/v1/openapi.json` | OpenAPI document |
| `GET` | `/api/v1/health` | health/version info |
| `POST` | `/api/v1/auth/register` | register and issue bearer token |
| `POST` | `/api/v1/auth/login` | log in and issue bearer token |

## Authenticated Endpoints

### User

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/me` | current user and supported marketplaces |
| `PATCH` | `/api/v1/me` | update selected marketplaces |
| `GET` | `/api/v1/me/usage` | current monthly usage, plan limits, add-on credits |

`GET /api/v1/me` returns:

- `user.id`, `email`, `confirmed_at`
- `selected_marketplaces`
- `plan`, `plan_status`, `plan_period`
- `plan_expires_at`, `trial_ends_at`
- `addon_credits`
- `supported_marketplaces`

### Product Tabs

| Method | Path |
| --- | --- |
| `GET` | `/api/v1/product_tabs` |
| `POST` | `/api/v1/product_tabs` |
| `PATCH` | `/api/v1/product_tabs/:id` |
| `DELETE` | `/api/v1/product_tabs/:id` |

### Storefront

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/storefront` | storefront config |
| `PUT` | `/api/v1/storefront` | create/update storefront |
| `GET` | `/api/v1/storefront/pages` | list pages |
| `POST` | `/api/v1/storefront/pages` | create page |
| `PATCH` | `/api/v1/storefront/pages/:page_id` | update page |
| `DELETE` | `/api/v1/storefront/pages/:page_id` | delete page |
| `PUT` | `/api/v1/storefront/pages/order` | reorder pages |
| `POST` | `/api/v1/storefront/assets/:kind/prepare_upload` | create asset record + signed upload |
| `DELETE` | `/api/v1/storefront/assets/:kind` | delete asset |

Storefront payload notes:

- `assets` contains branding asset records
- `assets[*].url` is the public URL for that asset
- `image_urls` is the ordered list of storefront branding URLs
- `themes` lists all available storefront theme presets
- each `themes[*]` entry includes `id`, `label`, and `colors`
- set `storefront.theme_id` to one of `themes[*].id`
- `pages` contains seller-authored page records

### Inquiries

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/inquiries` | paginated inquiry list |
| `DELETE` | `/api/v1/inquiries/:id` | delete one inquiry |

Query params:

- `page`
- `page_size` (max 100)
- `q`

### Products

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/products` | list products |
| `POST` | `/api/v1/products` | create product |
| `GET` | `/api/v1/products/:id` | fetch one product |
| `PATCH` | `/api/v1/products/:id` | update seller-managed fields |
| `DELETE` | `/api/v1/products/:id` | delete product |
| `POST` | `/api/v1/products/:id/prepare_uploads` | add upload intents to an existing product |
| `POST` | `/api/v1/products/:id/finalize_uploads` | finalize uploaded originals |
| `POST` | `/api/v1/products/:id/reprocess` | rerun processing |
| `POST` | `/api/v1/products/:id/generate_lifestyle_images` | generate lifestyle images |
| `GET` | `/api/v1/products/:id/lifestyle_generation_runs` | list lifestyle runs |
| `POST` | `/api/v1/products/:id/generated_images/:image_id/approve` | approve lifestyle output |
| `DELETE` | `/api/v1/products/:id/generated_images/:image_id` | delete generated image |
| `DELETE` | `/api/v1/products/:id/images/:image_id` | delete uploaded image and variants |
| `PATCH` | `/api/v1/products/:id/images/:image_id/storefront` | set storefront visibility/order |
| `PUT` | `/api/v1/products/:id/images/storefront_order` | reorder storefront gallery |
| `POST` | `/api/v1/products/:id/mark_sold` | mark sold |
| `POST` | `/api/v1/products/:id/archive` | archive |
| `POST` | `/api/v1/products/:id/unarchive` | restore |

List-product query params:

- `page`, `page_size`
- `status`
- `query`
- `product_tab_id`
- `updated_from`, `updated_to`
- `sort`, `dir`

Product payload notes:

- seller-owned fields live on the `product` record
- AI artifacts are nested as `description_draft`, `price_research`, and `marketplace_listings`
- `latest_processing_run` is the newest core pipeline run
- `latest_lifestyle_generation_run` is the newest lifestyle run
- `images[*].url` is the public URL for that image record
- `image_urls` is the ordered list of image URLs returned in the payload
- `images[*].storefront_visible` and `storefront_position` drive public gallery selection
- `marketplace_listings[*].external_url` is seller-managed

Create/update notes:

- `POST /products` accepts optional `uploads`
- upload endpoints return `upload_instructions` for direct-to-storage `PUT`
- `PATCH /products/:id` accepts seller-managed fields plus top-level `marketplace_external_urls`

### Exports

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/v1/exports` | request a ZIP export |
| `GET` | `/api/v1/exports/:id` | check export status |

Export payload fields:

- `name`, `file_name`
- `filter_params`
- `product_count`
- `status`
- `storage_key`
- `download_url`
- `expires_at`
- `requested_at`, `completed_at`
- `error_message`

### Imports

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/v1/imports` | request a ZIP import |
| `GET` | `/api/v1/imports/:id` | check import status |

Import payload fields:

- `status`
- `source_filename`
- `source_storage_key`
- `requested_at`, `started_at`, `finished_at`
- `total_products`, `imported_products`, `failed_products`
- `error_message`
- `failure_details`
- `payload`

## Media Rules

Product images:

- originals are stored as `product_images` with `kind: "original"`
- processed outputs are separate `product_images`
- lifestyle outputs are separate `product_images` with `kind: "lifestyle_generated"`

Storefront gallery selection:

1. If any ready image has `storefront_visible: true`, only those are shown.
2. Otherwise fall back to approved lifestyle images, then background-removed images, then originals.
3. Public storefront rendering only uses images with `processing_status: "ready"`.

## Ownership and Status Rules

- authenticated API endpoints are ownership-scoped
- foreign-owned resources return `404`
- product image management is only allowed in mutable product states
- processing endpoints are gated by metrics/plan checks

## Recommended References

- route and payload source: `lib/reseller_web/controllers/api/v1/*`
- generated spec: `/api/v1/openapi.json`
- interactive docs: `/docs/api`
