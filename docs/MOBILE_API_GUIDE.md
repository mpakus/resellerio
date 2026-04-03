# ResellerIO Mobile API Guide

This is the compressed mobile integration guide for the current `/api/v1` surface.

## 1. Authentication

Register:

- `POST /api/v1/auth/register`

Log in:

- `POST /api/v1/auth/login`

Both return a bearer token. Send it on every protected call:

```text
Authorization: Bearer <token>
```

Recommended mobile flow:

1. Register or log in.
2. Persist the bearer token securely.
3. Fetch `GET /api/v1/me`.
4. Fetch `GET /api/v1/me/usage` if you display quotas.

## 2. User and Marketplace Settings

Current-user endpoints:

- `GET /api/v1/me`
- `PATCH /api/v1/me`
- `GET /api/v1/me/usage`

Important fields returned by `GET /api/v1/me`:

- `selected_marketplaces`
- `plan`, `plan_status`, `plan_period`
- `plan_expires_at`, `trial_ends_at`
- `addon_credits`
- `supported_marketplaces`

## 3. Product Flow

### Create a product

Use:

- `POST /api/v1/products`

You may send only seller fields, or seller fields plus `uploads`.

If `uploads` is present, the response includes:

- `product.images`
- `upload_instructions`

Each upload instruction contains:

- `image_id`
- `storage_key`
- `method`
- `upload_url`
- `headers`
- `expires_at`

### Upload originals

Perform a direct `PUT` to `upload_url` with the returned headers.

### Finalize uploads

Use:

- `POST /api/v1/products/:id/finalize_uploads`

The backend validates the uploaded image ids and starts processing.

### Poll product state

Use:

- `GET /api/v1/products/:id`

Watch:

- `status`
- `latest_processing_run`
- `description_draft`
- `price_research`
- `marketplace_listings`
- `images`

### Mutable product actions

- `PATCH /api/v1/products/:id`
- `DELETE /api/v1/products/:id`
- `POST /api/v1/products/:id/reprocess`
- `POST /api/v1/products/:id/mark_sold`
- `POST /api/v1/products/:id/archive`
- `POST /api/v1/products/:id/unarchive`

## 4. Product Payload Notes

Current mobile-relevant fields:

- `product_tab_id`, `product_tab`
- `storefront_enabled`, `storefront_published_at`
- `description_draft`
- `price_research`
- `marketplace_listings[*].external_url`
- `latest_processing_run`
- `latest_lifestyle_generation_run`
- `image_urls`
- `images[*].url`
- `images[*].storefront_visible`
- `images[*].storefront_position`

Media URL rule:

- use `image_urls` when the app only needs ordered URLs
- use `images` when the app needs metadata plus `url`

## 5. Product Tabs

Endpoints:

- `GET /api/v1/product_tabs`
- `POST /api/v1/product_tabs`
- `PATCH /api/v1/product_tabs/:id`
- `DELETE /api/v1/product_tabs/:id`

Use tabs for seller workspace organization only. They do not affect public storefront routing.

## 6. Storefront

Endpoints:

- `GET /api/v1/storefront`
- `PUT /api/v1/storefront`
- `GET /api/v1/storefront/pages`
- `POST /api/v1/storefront/pages`
- `PATCH /api/v1/storefront/pages/:page_id`
- `DELETE /api/v1/storefront/pages/:page_id`
- `PUT /api/v1/storefront/pages/order`
- `POST /api/v1/storefront/assets/:kind/prepare_upload`
- `DELETE /api/v1/storefront/assets/:kind`

Storefront payload notes:

- `assets[*].url` is the public branding asset URL
- `image_urls` is the ordered list of branding asset URLs
- `pages` is the seller-managed content set

Branding asset upload flow:

1. call `prepare_upload`
2. upload to returned signed URL
3. refetch storefront config

## 7. Lifestyle Images

Endpoints:

- `POST /api/v1/products/:id/generate_lifestyle_images`
- `GET /api/v1/products/:id/lifestyle_generation_runs`
- `POST /api/v1/products/:id/generated_images/:image_id/approve`
- `DELETE /api/v1/products/:id/generated_images/:image_id`

Generated images are normal `product_images` with `kind: "lifestyle_generated"`.

Relevant fields:

- `lifestyle_generation_run_id`
- `scene_key`
- `variant_index`
- `source_image_ids`
- `seller_approved`
- `approved_at`

## 8. Storefront Image Curation

Endpoints:

- `PATCH /api/v1/products/:id/images/:image_id/storefront`
- `PUT /api/v1/products/:id/images/storefront_order`

These control public storefront gallery visibility and ordering.

## 9. Inquiries

Endpoints:

- `GET /api/v1/inquiries`
- `DELETE /api/v1/inquiries/:id`

Supported query params:

- `page`
- `page_size`
- `q`

## 10. Exports and Imports

Export:

- `POST /api/v1/exports`
- `GET /api/v1/exports/:id`

Import:

- `POST /api/v1/imports`
- `GET /api/v1/imports/:id`

Mobile expectations:

- both are asynchronous
- poll the `:id` endpoint after the initial `202 Accepted`
- export records expose `download_url` when ready
- import records expose aggregate counts and failure details

## 11. Error Handling

Treat these as first-class cases:

- `401` — missing or invalid token
- `404` — unknown resource or foreign-owned resource
- `402` — usage limit exceeded
- `422 validation_failed` — bad input payload
- `422` with other codes — invalid resource state

For `402`, show the returned `upgrade_url` directly.

## 12. Suggested Sync Strategy

Recommended mobile sequence:

1. `GET /api/v1/me`
2. `GET /api/v1/me/usage`
3. `GET /api/v1/product_tabs`
4. `GET /api/v1/storefront`
5. `GET /api/v1/products`

On product detail:

1. `GET /api/v1/products/:id`
2. poll while `status` is `uploading` or `processing`
3. refresh after finalize, reprocess, or lifestyle actions

## 13. Source of Truth

- route list: `lib/reseller_web/router.ex`
- JSON shapes: `lib/reseller_web/controllers/api/v1/*`
- generated spec: `/api/v1/openapi.json`
- compressed reference: `docs/API.md`
