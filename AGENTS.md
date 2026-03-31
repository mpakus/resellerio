# Resellerio Agent Guide

## Product

Resellerio is an API-first Phoenix backend for a reseller mobile app, with a LiveView workspace for operational use and Backpex for admin work.

Core flow:

1. Create a `Product`.
2. Upload original images to Tigris.
3. Finalize uploads and start background processing.
4. Generate AI metadata, pricing guidance, marketplace copy, and optional image variants.
5. Manage inventory state, exports, and imports.

## Current surfaces

- Public: `/`
- Browser auth: `/sign-up`, `/sign-in`, `DELETE /sign-out`
- Workspace: `/app`, `/app/products`, `/app/exports`, `/app/settings`
- Legacy redirect: `GET /app/listings -> /app/products`
- Admin: `/admin`
- API: `/api/v1`

## Main components

- `Reseller.Accounts`
  Users, passwords, browser auth, API tokens, marketplace defaults, admin flagging.

- `Reseller.Catalog`
  Products, seller-managed edits, product lifecycle, ownership-scoped reads/writes.

- `Reseller.Media`
  Upload intents, `ProductImage`, upload finalization, Tigris storage, processed variants.

- `Reseller.AI`
  Recognition, description drafts, price research, lifestyle generation support.

- `Reseller.Marketplaces`
  Supported marketplace catalog and per-marketplace listing drafts.

- `Reseller.Workers`
  Async product processing and lifestyle generation orchestration.

- `Reseller.Exports`
  ZIP export creation, artifact upload, download URLs, notifications.

- `Reseller.Imports`
  ZIP intake, parsing, recreation, and failure tracking.

## Domain rules

- `Product` is the aggregate root.
- Keep seller-edited product fields separate from AI-generated records.
- Store generated descriptions in `product_description_drafts`.
- Store generated pricing in `product_price_researches`.
- Store marketplace-specific copy in `marketplace_listings`.
- Keep original and processed images as separate `product_images`.
- Put business logic in contexts, not controllers or LiveViews.
- Use background work for long-running AI, media, export, import, and notification flows.

## Development rules

- Prefer JSON APIs under `/api/v1` for mobile-facing features.
- Reuse `Reseller.Media.Storage` for upload signing and download URLs.
- Reuse `Reseller.Workers` for async orchestration instead of ad hoc tasks from controllers.
- Use `Req`; do not add `HTTPoison`, `Tesla`, or `:httpc`.
- Keep auth, ownership, and admin checks explicit and regression-tested.
- Return `404` for foreign owned resources rather than leaking resource existence.

## Docs to keep in sync

- Update `docs/API.md` when routes, payloads, auth behavior, or response shapes change.
- Update `docs/ARCHITECTURE.md` when schemas, relationships, workers, or integrations change.
- Update `docs/UIUX.md` when shared LiveView patterns or components change.
- Update `docs/PLANS.md`, `docs/PLAN-AI.md`, and `docs/PLAN-WEB.md` when milestone status changes.

## Testing and verification

- Add tests with every auth, ownership, admin, API, or worker change.
- Prefer fixtures from `test/support/fixtures`.
- Cover missing, malformed, expired, and valid bearer-token cases on protected API routes.
- Cover unauthenticated, non-admin, and admin paths for admin surfaces.
- Run `mix precommit` before closing a task.

## Naming

- Use `User`, `Product`, `ProductImage`, `MarketplaceListing`, `Export`, and `Import`.
- Avoid introducing parallel inventory nouns like `asset` unless there is a real distinction.
