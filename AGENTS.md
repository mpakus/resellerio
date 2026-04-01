# Resellerio Agent Guide

## Product

Resellerio is an API-first Phoenix backend for a reseller mobile app, with a LiveView workspace for operational use and Backpex for admin work.

Core flow:

1. Create a `Product`.
2. Upload original images to Tigris.
3. Finalize uploads and start background processing.
4. Generate AI metadata, pricing guidance, marketplace copy, and optional image variants.
5. Optionally generate AI lifestyle preview images.
6. Manage inventory state, exports, and imports.
7. Publish products to a seller storefront.

## Current surfaces

- Public: `/`, `/privacy`, `/dpa`
- Public storefront: `/store/:slug`, `/store/:slug/products/:product_ref`, `/store/:slug/pages/:page_slug`
- Browser auth: `/sign-up`, `/sign-in`, `DELETE /sign-out`
- Workspace: `/app`, `/app/products`, `/app/products/new`, `/app/products/:id`, `/app/inquiries`, `/app/exports`, `/app/settings`
- Legacy redirects: `GET /app/listings -> /app/products`, `GET /app/products/export.xls`
- Admin: `/admin`, `/admin/usage-dashboard`, `/admin/api-usage-events`
- API: `/api/v1`

## Main components

- `Reseller.Accounts`
  Users, passwords, browser auth, API tokens, marketplace defaults, admin flagging.

- `Reseller.Catalog`
  Products, seller-defined product tabs, seller-managed edits, product lifecycle, ownership-scoped reads/writes.

- `Reseller.Media`
  Upload intents, `ProductImage`, upload finalization, Tigris storage, processed variants.

- `Reseller.AI`
  Recognition, description drafts, price research, lifestyle generation runs and orchestration.

- `Reseller.Search`
  Google Lens visual matches and Google Shopping comparables via SerpApi.

- `Reseller.Marketplaces`
  Supported marketplace catalog and per-marketplace listing drafts with seller-managed external URLs.

- `Reseller.Storefronts`
  Seller storefront identity, branding assets, theme presets, custom pages, inquiry capture and notifications, and public storefront browser rendering.

- `Reseller.Workers`
  Async product processing and lifestyle image generation orchestration.

- `Reseller.Exports`
  ZIP export creation (XLS + manifest + images), artifact upload, download URLs, notifications, stalled-export retry.

- `Reseller.Imports`
  ZIP intake, parsing, recreation, and per-product failure tracking.

- `Reseller.Metrics`
  Per-call recording of every Gemini, SerpApi, and Photoroom API call; cost estimation; daily per-user usage summaries; configurable daily limits; admin dashboards.

## Domain rules

- `Product` is the aggregate root.
- Keep seller-edited product fields separate from AI-generated records.
- Store generated descriptions in `product_description_drafts`.
- Store generated pricing in `product_price_researches`.
- Store marketplace-specific copy in `marketplace_listings`.
- Keep original and processed images as separate `product_images`.
- Put business logic in contexts, not controllers or LiveViews.
- Use background work for long-running AI, media, export, import, and notification flows.
- Metrics recording is best-effort — a `record_event` failure must never halt a processing pipeline.

## Development rules

- Prefer JSON APIs under `/api/v1` for mobile-facing features.
- Reuse `Reseller.Media.Storage` for upload signing and download URLs.
- Reuse `Reseller.Workers` for async orchestration instead of ad hoc tasks from controllers.
- Use `Req`; do not add `HTTPoison`, `Tesla`, or `:httpc`.
- Keep auth, ownership, and admin checks explicit and regression-tested.
- Return `404` for foreign-owned resources rather than leaking resource existence.
- Propagate `user_id` and `product_id` through worker opts so metrics can be attributed correctly.

## Docs to keep in sync

- Update `docs/API.md` when routes, payloads, auth behavior, or response shapes change.
- Update `docs/ARCHITECTURE.md` when schemas, relationships, workers, or integrations change.
- Update `docs/UIUX.md` when shared LiveView patterns or components change.
- Update `docs/PLANS.md`, `docs/PLAN-AI.md`, and `docs/PLAN-WEB.md` when milestone status changes.
- Update `docs/METRICS-LIMITS-PLAN.md` when metrics, cost config, or limit logic changes.

## Testing and verification

- Add tests with every auth, ownership, admin, API, or worker change.
- Prefer fixtures from `test/support/fixtures`.
- Cover missing, malformed, expired, and valid bearer-token cases on protected API routes.
- Cover unauthenticated, non-admin, and admin paths for admin surfaces.
- Run `mix precommit` before closing a task.

## Naming

- Use `User`, `Product`, `ProductImage`, `MarketplaceListing`, `Export`, `Import`, `Storefront`, `StorefrontInquiry`, and `ApiUsageEvent`.
- Avoid introducing parallel inventory nouns like `asset` unless there is a real distinction.

## Current API endpoints

Public:

- `GET /api/v1`
- `GET /api/v1/health`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`

Authenticated (Bearer token required):

- `GET /api/v1/me`
- `PATCH /api/v1/me`
- `GET /api/v1/product_tabs`
- `POST /api/v1/product_tabs`
- `PATCH /api/v1/product_tabs/:id`
- `DELETE /api/v1/product_tabs/:id`
- `GET /api/v1/storefront`
- `PUT /api/v1/storefront`
- `GET /api/v1/storefront/pages`
- `POST /api/v1/storefront/pages`
- `PATCH /api/v1/storefront/pages/:page_id`
- `DELETE /api/v1/storefront/pages/:page_id`
- `DELETE /api/v1/storefront/assets/:kind`
- `GET /api/v1/inquiries`
- `DELETE /api/v1/inquiries/:id`
- `GET /api/v1/products`
- `POST /api/v1/products`
- `GET /api/v1/products/:id`
- `PATCH /api/v1/products/:id`
- `DELETE /api/v1/products/:id`
- `POST /api/v1/products/:id/finalize_uploads`
- `POST /api/v1/products/:id/reprocess`
- `POST /api/v1/products/:id/generate_lifestyle_images`
- `GET /api/v1/products/:id/lifestyle_generation_runs`
- `POST /api/v1/products/:id/generated_images/:image_id/approve`
- `DELETE /api/v1/products/:id/generated_images/:image_id`
- `DELETE /api/v1/products/:id/images/:image_id`
- `POST /api/v1/products/:id/mark_sold`
- `POST /api/v1/products/:id/archive`
- `POST /api/v1/products/:id/unarchive`
- `POST /api/v1/exports`
- `GET /api/v1/exports/:id`
- `POST /api/v1/imports`
- `GET /api/v1/imports/:id`
