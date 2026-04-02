# Resellerio Agent Guide

## Product

Resellerio is an API-first Phoenix backend for a reseller mobile app, with a LiveView workspace for operational use and Backpex for admin work.

Core flow: create `Product` → upload originals to Tigris → finalize & process → AI metadata + pricing + marketplace copy + image variants → optional lifestyle images → manage lifecycle → publish to storefront.

## Surfaces

- Public: `/`, `/privacy`, `/dpa`
- Storefront: `/store/:slug`, `/store/:slug/products/:product_ref`, `/store/:slug/pages/:page_slug`
- Auth: `/sign-up`, `/sign-in`, `DELETE /sign-out`
- Workspace: `/app`, `/app/products`, `/app/products/new`, `/app/products/:id`, `/app/inquiries`, `/app/exports`, `/app/settings`
- Legacy: `GET /app/listings → /app/products`, `GET /app/products/export.xls`
- Admin: `/admin`, `/admin/usage-dashboard`, `/admin/api-usage-events`
- API: `/api/v1`

## Contexts

- `Reseller.Accounts` — users, passwords, browser auth, API tokens, marketplace defaults, admin flag.
- `Reseller.Catalog` — products, product tabs, seller edits, lifecycle, ownership-scoped access.
- `Reseller.Media` — upload intents, `ProductImage`, finalization, Tigris storage, processed variants.
- `Reseller.AI` — recognition, description drafts, price research, lifestyle generation runs.
- `Reseller.Search` — Google Lens + Shopping via SerpApi.
- `Reseller.Marketplaces` — per-marketplace listing drafts and seller-managed external URLs.
- `Reseller.Storefronts` — storefront identity, branding, theme presets, custom pages, inquiry capture/notifications, public rendering, gallery image selection.
- `Reseller.Workers` — async product processing and lifestyle image generation orchestration.
- `Reseller.Exports` — ZIP export: assembly, upload, download URLs, notifications, stalled-export retry.
- `Reseller.Imports` — ZIP intake, parsing, recreation, per-product failure tracking.
- `Reseller.Metrics` — per-call recording (Gemini, SerpApi, Photoroom), cost estimation, daily summaries, limits, admin dashboards.

## Domain rules

- `Product` is the aggregate root.
- Keep seller-edited fields separate from AI-generated records (`product_description_drafts`, `product_price_researches`, `marketplace_listings`).
- Keep original and processed images as separate `product_images`.
- Business logic in contexts, not controllers or LiveViews.
- Background work for long-running AI, media, export, import, and notification flows.
- Metrics recording is best-effort — a failure must never halt a pipeline.

## Storefront gallery image selection

`ResellerWeb.StorefrontComponents.storefront_gallery_images/1`:

1. If any image has `storefront_visible: true` → show those, ordered by `storefront_position NULLS LAST, position, id`.
2. Fallback (no visible images set by seller):
   - Approved `lifestyle_generated` images (`seller_approved: true`), sorted by `position, id`.
   - Then `background_removed` images, sorted by `position, id`.
   - If neither exist, fall back to `original` images sorted by `position, id`.
3. Only `processing_status: "ready"` images are shown publicly.

## Development rules

- JSON APIs under `/api/v1` for mobile-facing features.
- Reuse `Reseller.Media.Storage` for upload signing and download URLs.
- Reuse `Reseller.Workers` for async orchestration.
- Use `Req`; do not add `HTTPoison`, `Tesla`, or `:httpc`.
- Auth, ownership, and admin checks must be explicit and regression-tested.
- Return `404` for foreign-owned resources.
- Propagate `user_id` and `product_id` through worker opts for metric attribution.

## Docs to keep in sync

- `docs/API.md` — routes, payloads, auth, response shapes.
- `docs/ARCHITECTURE.md` — schemas, relationships, workers, integrations.
- `docs/UIUX.md` — shared LiveView patterns and components.
- `docs/PLANS.md`, `docs/PLAN-AI.md`, `docs/PLAN-GENERATE-IMAGE.md` — milestone status and open items.
- `docs/PRICING_PLAN.md`, `docs/PRICING_CHECKS.md` — billing milestone status and audit gaps.
- `docs/METRICS-LIMITS-PLAN.md` — metrics, cost config, limit logic.

## Testing

- Add tests with every auth, ownership, admin, API, or worker change.
- Fixtures from `test/support/fixtures`.
- Cover missing, malformed, expired, and valid bearer-token cases on protected API routes.
- Cover unauthenticated, non-admin, and admin paths for admin surfaces.
- Run `mix precommit` before closing a task.

## Naming

Use: `User`, `Product`, `ProductImage`, `MarketplaceListing`, `Export`, `Import`, `Storefront`, `StorefrontInquiry`, `ApiUsageEvent`. Avoid parallel inventory nouns like `asset` unless there is a real distinction.

## API endpoints

Public: `GET /api/v1`, `GET /api/v1/health`, `POST /api/v1/auth/register`, `POST /api/v1/auth/login`

Authenticated (Bearer token required):

- `GET /api/v1/me`, `PATCH /api/v1/me`
- `GET /api/v1/product_tabs`, `POST`, `PATCH /:id`, `DELETE /:id`
- `GET /api/v1/storefront`, `PUT /api/v1/storefront`
- `GET /api/v1/storefront/pages`, `POST`, `PATCH /:page_id`, `DELETE /:page_id`
- `DELETE /api/v1/storefront/assets/:kind`
- `GET /api/v1/inquiries`, `DELETE /:id`
- `GET /api/v1/products`, `POST`, `GET /:id`, `PATCH /:id`, `DELETE /:id`
- `POST /api/v1/products/:id/finalize_uploads`
- `POST /api/v1/products/:id/reprocess`
- `POST /api/v1/products/:id/generate_lifestyle_images`
- `GET /api/v1/products/:id/lifestyle_generation_runs`
- `POST /api/v1/products/:id/generated_images/:image_id/approve`
- `DELETE /api/v1/products/:id/generated_images/:image_id`
- `DELETE /api/v1/products/:id/images/:image_id`
- `PATCH /api/v1/products/:id/images/:image_id/storefront`
- `PUT /api/v1/products/:id/images/storefront_order`
- `POST /api/v1/products/:id/mark_sold`
- `POST /api/v1/products/:id/archive`
- `POST /api/v1/products/:id/unarchive`
- `POST /api/v1/exports`, `GET /api/v1/exports/:id`
- `POST /api/v1/imports`, `GET /api/v1/imports/:id`
