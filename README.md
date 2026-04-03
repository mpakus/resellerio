# ResellerIO

ResellerIO is an API-first Phoenix application for secondhand sellers. It combines:

- a mobile-facing JSON API under `/api/v1`
- a LiveView workspace under `/app`
- public storefronts under `/store/:slug`
- an admin surface under `/admin`

The codebase centers on one aggregate root: `Product`. The core flow is:

1. Create a product.
2. Upload original images to Tigris-compatible object storage.
3. Finalize uploads and enqueue processing.
4. Run AI recognition, description, price research, and marketplace copy generation.
5. Produce processed image variants and optional lifestyle images.
6. Publish to the seller storefront, export inventory, or import archived inventory back in.

## Main Surfaces

Public:

- `/`
- `/pricing`
- `/privacy`
- `/dpa`
- `/docs/api`

Storefront:

- `/store/:slug`
- `/store/:slug/products/:product_ref`
- `/store/:slug/pages/:page_slug`

Workspace:

- `/app`
- `/app/products`
- `/app/products/new`
- `/app/products/:id`
- `/app/inquiries`
- `/app/exports`
- `/app/settings`
- `GET /app/products/export.xls`

Admin:

- `/admin`
- `/admin/usage-dashboard`
- `/admin/api-usage-events`

API:

- public: `GET /api/v1`, `GET /api/v1/health`, `POST /api/v1/auth/register`, `POST /api/v1/auth/login`
- authenticated: products, product tabs, storefront, inquiries, exports, imports, and `GET /api/v1/me`, `PATCH /api/v1/me`, `GET /api/v1/me/usage`
- browser clients can send `OPTIONS` preflight requests to `/api/v1/*`, but only allowlisted origins receive CORS headers

## Source Map

Core contexts:

- `Reseller.Accounts` — users, passwords, API tokens, marketplace preferences
- `Reseller.Catalog` — products, tabs, lifecycle, ownership checks
- `Reseller.Media` — uploads, finalized images, public URLs, storage integration
- `Reseller.AI` — AI generation entry points and persisted AI artifacts
- `Reseller.Search` — SerpApi-backed enrichment
- `Reseller.Marketplaces` — marketplace catalog and generated listing records
- `Reseller.Storefronts` — storefront settings, assets, pages, inquiries, public product selection
- `Reseller.Exports` — ZIP export requests, storage, download links
- `Reseller.Imports` — ZIP import requests and archive recreation
- `Reseller.Metrics` — API usage events, summaries, cost estimation, limit checks
- `Reseller.Billing` — plans, LemonSqueezy subscriptions, add-on credits, expiry helpers
- `Reseller.Workers` — async orchestration for product processing and lifestyle generation

Web layer:

- `lib/reseller_web/router.ex` — route surface
- `lib/reseller_web/live/*` — marketing, workspace, and docs LiveViews
- `lib/reseller_web/controllers/api/v1/*` — mobile-facing JSON API
- `lib/reseller_web/components/*` — shared layouts, UI primitives, storefront rendering

## Product Rules

- `Product` is the aggregate root.
- Seller-edited fields stay on `products`; AI output is stored in separate records.
- Original uploads and processed variants are stored as distinct `product_images`.
- Ownership checks return `404` for foreign-owned resources.
- Long-running AI, export, import, and notification work runs through `Task.Supervisor`.
- Metrics recording is best-effort and must not block pipelines.

Current media payload convention:

- product API responses include `image_urls` and `images[*].url`
- storefront API responses include branding `image_urls` and `assets[*].url`
- storefront API responses also include `themes` for available preset theme choices

Current security posture:

- browser sessions use `HttpOnly` cookies with `SameSite=Lax` and `Secure` in production
- production endpoint enforces HTTPS redirects with HSTS enabled
- browser-origin API access is restricted by an explicit allowlist
- import archives are capped in size and reject unsafe entry paths
- API error responses avoid exposing raw internal exception terms

Current ID sequence convention for new records:

- `products` start from `16000`
- `users`, `storefronts`, `imports`, `exports`, and `api_tokens` start from `1000`
- `product_tabs` start from `1500`

## Local Development

Prerequisites:

- Elixir / OTP compatible with Phoenix 1.8
- PostgreSQL

Quick start:

```bash
mix setup
cp .env.example .env
mix phx.server
```

Useful entry points:

- `http://localhost:4000`
- `http://localhost:4000/docs/api`
- `http://localhost:4000/api/v1`

Seed accounts created by `mix setup`:

- `admin@resellerio.local` / `very-secure-password`
- `seller@resellerio.local` / `very-secure-password`

## Runtime Dependencies

External services used by the current code:

- Gemini for recognition, description, price research, marketplace copy, and lifestyle generation
- SerpApi for Google Lens and shopping comparables
- Photoroom for background removal
- Tigris-compatible object storage for images and archives
- LemonSqueezy for checkout and subscription webhooks

See [docs/API.md](/Users/mpak/www/elixir/reseller/docs/API.md), [docs/ARCHITECTURE.md](/Users/mpak/www/elixir/reseller/docs/ARCHITECTURE.md), [docs/MOBILE_API_GUIDE.md](/Users/mpak/www/elixir/reseller/docs/MOBILE_API_GUIDE.md), and [docs/PRICING.md](/Users/mpak/www/elixir/reseller/docs/PRICING.md) for the maintained docs set.
