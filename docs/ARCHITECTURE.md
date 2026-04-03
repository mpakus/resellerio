# ResellerIO Architecture

This document is the compressed architecture map for the current codebase.

## Stack

- Phoenix 1.8 + LiveView
- Ecto + PostgreSQL
- Tigris-compatible object storage
- Req for external HTTP
- Backpex for admin
- `Task.Supervisor` for background work

## Runtime Topology

`Reseller.Application` starts:

- `ResellerWeb.Telemetry`
- `Reseller.Repo`
- `DNSCluster`
- `Phoenix.PubSub`
- `Task.Supervisor` as `Reseller.Workers.TaskSupervisor`
- `Reseller.Workers.ExpiryScheduler`
- `ResellerWeb.Endpoint`

Background jobs are asynchronous but not durable across node crashes.

## Route Surface

Browser:

- marketing: `/`, `/pricing`, `/privacy`, `/dpa`, `/docs/api`
- auth: `/sign-up`, `/sign-in`, `DELETE /sign-out`
- storefront: `/store/:slug`, `/store/:slug/products/:product_ref`, `/store/:slug/pages/:page_slug`
- workspace: `/app`, `/app/products`, `/app/products/new`, `/app/products/:id`, `/app/inquiries`, `/app/exports`, `/app/settings`
- admin: `/admin`, `/admin/usage-dashboard`, `/admin/api-usage-events`

API:

- versioned under `/api/v1`
- public auth/health/discovery endpoints
- authenticated user, product tab, storefront, inquiry, product, export, and import endpoints

Source of truth: `lib/reseller_web/router.ex`

## Bounded Contexts

### `Reseller.Accounts`

Responsibilities:

- registration and password auth
- API token issuance and lookup
- selected marketplace defaults
- admin flag management

Core records:

- `users`
- `api_tokens`

### `Reseller.Catalog`

Responsibilities:

- product CRUD
- product tab CRUD
- ownership-scoped fetches
- manual lifecycle transitions
- storefront publication flags

Core records:

- `products`
- `product_tabs`

Key rule:

- `Product` is the aggregate root for the reseller domain

### `Reseller.Media`

Responsibilities:

- upload intent validation
- storage-key generation
- finalize-upload flow
- product image mutation
- public URL generation

Core record:

- `product_images`

Key rule:

- originals and derived variants are separate rows

### `Reseller.AI`

Responsibilities:

- AI provider facade
- recognition pipeline entry point
- description draft persistence
- price research persistence
- lifestyle generation run persistence

Core records:

- `product_description_drafts`
- `product_price_researches`
- `product_lifestyle_generation_runs`

### `Reseller.Search`

Responsibilities:

- SerpApi-backed Google Lens and shopping lookups

### `Reseller.Marketplaces`

Responsibilities:

- marketplace catalog
- generated listing persistence
- seller-managed external URLs

Core record:

- `marketplace_listings`

Supported marketplace ids in code:

- `ebay`
- `depop`
- `poshmark`
- `mercari`
- `facebook_marketplace`
- `offerup`
- `whatnot`
- `grailed`
- `therealreal`
- `vestiaire_collective`
- `thredup`
- `etsy`

### `Reseller.Storefronts`

Responsibilities:

- storefront settings
- storefront theme presets
- branding assets
- seller-authored pages
- public storefront lookup
- public product listing
- inquiry capture and notification

Core records:

- `storefronts`
- `storefront_assets`
- `storefront_pages`
- `storefront_inquiries`

Theme source of truth:

- `Reseller.Storefronts.ThemePresets` defines the preset catalog used by storefront rendering and the authenticated storefront API

Public image selection rule:

`ResellerWeb.StorefrontComponents.storefront_gallery_images/1` chooses:

1. ready visible images first
2. otherwise approved lifestyle images
3. then background-removed images
4. then originals

### `Reseller.Exports`

Responsibilities:

- export request lifecycle
- filter normalization
- ZIP assembly and storage
- signed or public download URLs
- PubSub update broadcasts

Core record:

- `exports`

### `Reseller.Imports`

Responsibilities:

- import request lifecycle
- archive upload and fetch
- ZIP parsing
- product recreation

Core records:

- `imports`
- `import_requests`

### `Reseller.Metrics`

Responsibilities:

- append-only API usage events
- daily summaries
- cost estimation
- daily limit checks
- monthly plan checks
- admin reporting queries

Core records:

- `api_usage_events`
- `user_usage_summaries`

Important rule:

- metrics writes are best-effort and must not stop product pipelines

### `Reseller.Billing`

Responsibilities:

- subscription state
- plan metadata
- add-on credits
- expiry sweeps
- LemonSqueezy webhook application

Billing state lives on `users`.

### `Reseller.Workers`

Responsibilities:

- create processing runs
- enqueue core product processing
- prepare and enqueue lifestyle generation
- schedule billing reminder/expiry work

Core worker records:

- `product_processing_runs`
- `product_lifestyle_generation_runs`

## Main Product Flow

### 1. Product creation

`Catalog.create_product_for_user/4`:

- creates the product
- optionally creates pending upload image rows
- returns upload instructions

### 2. Upload finalization

`Catalog.finalize_product_uploads_for_user/3`:

- validates the image ids
- marks uploads ready
- starts a processing run through `Reseller.Workers`

### 3. Core processing

The pipeline writes back to:

- `products`
- `product_images`
- `product_description_drafts`
- `product_price_researches`
- `marketplace_listings`
- `api_usage_events`

### 4. Optional lifestyle generation

Triggered manually through API or workspace.

Outputs:

- `product_lifestyle_generation_runs`
- `product_images` with `kind: "lifestyle_generated"`

### 5. Storefront publication

Products can be marked `storefront_enabled`.

Public storefront queries only expose:

- enabled storefronts
- ready products
- ready public images according to gallery-selection rules

### 6. Export / import

Exports:

- build a ZIP with spreadsheet + images
- store the archive
- expose `download_url`

Imports:

- accept a ZIP
- store the source archive
- parse and recreate products/images
- track failures on the import record

## Data Model

Primary user-owned records:

- `users`
- `api_tokens`
- `products`
- `product_tabs`
- `storefronts`
- `exports`
- `imports`

Product-adjacent records:

- `product_images`
- `product_processing_runs`
- `product_description_drafts`
- `product_price_researches`
- `marketplace_listings`
- `product_lifestyle_generation_runs`

Storefront-adjacent records:

- `storefront_assets`
- `storefront_pages`
- `storefront_inquiries`

Operational records:

- `api_usage_events`
- `user_usage_summaries`

## Integrations

Gemini:

- recognition
- description generation
- price research
- marketplace copy
- lifestyle image generation

SerpApi:

- Google Lens matches
- shopping comparables

Photoroom:

- background removal

Tigris-compatible storage:

- product images
- storefront assets
- export ZIPs
- import ZIPs

LemonSqueezy:

- checkout URLs
- webhook-driven subscription updates

## Current Documentation Set

- [README.md](/Users/mpak/www/elixir/reseller/README.md) — repo overview
- [docs/API.md](/Users/mpak/www/elixir/reseller/docs/API.md) — compressed API guide
- [docs/MOBILE_API_GUIDE.md](/Users/mpak/www/elixir/reseller/docs/MOBILE_API_GUIDE.md) — mobile integration notes
- [docs/PRICING.md](/Users/mpak/www/elixir/reseller/docs/PRICING.md) — pricing source of truth
- [docs/UIUX.md](/Users/mpak/www/elixir/reseller/docs/UIUX.md) — shared UI rules
