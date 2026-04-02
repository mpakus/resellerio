# ResellerIO

ResellerIO is an API-first Phoenix application for resellers. It powers:

- a mobile-facing JSON API
- a LiveView workspace for day-to-day operations
- public seller storefronts
- a Backpex admin surface

The core product flow is:

1. Create a `Product`.
2. Upload original photos to Tigris with signed upload instructions.
3. Finalize uploads and enqueue processing.
4. Run AI recognition and enrichment.
5. Generate seller-reviewable description, price research, and marketplace drafts.
6. Optionally create background-removed and lifestyle-generated images.
7. Publish to a storefront, export a ZIP archive, or import archived inventory back in.

## What The App Includes

- Versioned JSON API under `/api/v1`
- OpenAPI document at `/api/v1/openapi.json`
- Interactive API docs at `/docs/api`
- Browser auth at `/sign-up`, `/sign-in`, and `DELETE /sign-out`
- LiveView workspace at `/app`, `/app/products`, `/app/inquiries`, `/app/exports`, and `/app/settings`
- Public storefronts at `/store/:slug`
- Backpex admin at `/admin`
- Pricing page and LemonSqueezy webhook handling
- API usage tracking for Gemini, SerpApi, and Photoroom calls
- ZIP export and ZIP import flows

## Main Surfaces

### Public

- `/`
- `/pricing`
- `/privacy`
- `/dpa`
- `/docs/api`

### Storefront

- `/store/:slug`
- `/store/:slug/products/:product_ref`
- `/store/:slug/pages/:page_slug`

### Workspace

- `/app`
- `/app/products`
- `/app/products/new`
- `/app/products/:id`
- `/app/inquiries`
- `/app/exports`
- `/app/settings`

Additional workspace endpoint:

- `GET /app/products/export.xls`

### Admin

- `/admin`
- `/admin/usage-dashboard`
- `/admin/api-usage-events`

### API

Public:

- `GET /api/v1`
- `GET /api/v1/health`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`

Authenticated:

- `GET /api/v1/me`
- `PATCH /api/v1/me`
- `GET /api/v1/me/usage`
- product tabs, storefront, inquiries, products, exports, and imports endpoints under `/api/v1`

Current media payload convention:

- product responses include `image_urls` plus `images[*].url`
- storefront responses include `image_urls` for branding assets plus `assets[*].url`

See [`docs/API.md`](docs/API.md) and [`docs/MOBILE_API_GUIDE.md`](docs/MOBILE_API_GUIDE.md) for endpoint details.

## Product Capabilities

- Product CRUD with ownership-scoped access
- Seller-managed product tabs for workspace organization
- Signed upload preparation for product and storefront assets
- Upload finalization batches
- AI recognition with Gemini
- Lens and shopping enrichment with SerpApi
- Description drafts stored separately from seller-edited fields
- Price research stored separately from seller-edited pricing
- Marketplace-specific listing generation with separate listing records
- Processed media variants, including background removal
- Manual and optional pipeline-driven lifestyle image generation
- Storefront publication controls and gallery image curation
- Storefront inquiries with notification delivery
- ZIP export generation and ZIP import recreation
- Usage metrics, cost estimation, and admin reporting
- Subscription and checkout plumbing through LemonSqueezy

## Bounded Contexts

- `Reseller.Accounts` - users, passwords, browser auth, API tokens, admin grants, marketplace defaults
- `Reseller.Catalog` - products, product tabs, lifecycle, ownership-scoped access
- `Reseller.Media` - upload intents, finalization, storage, processed variants
- `Reseller.AI` - recognition, normalization, description drafts, price research, lifestyle generation
- `Reseller.Search` - Google Lens and shopping enrichment through SerpApi
- `Reseller.Marketplaces` - supported marketplaces and generated listing persistence
- `Reseller.Storefronts` - storefront settings, branding assets, pages, public rendering, inquiries
- `Reseller.Exports` - ZIP creation, upload, notifications
- `Reseller.Imports` - ZIP parsing and inventory recreation
- `Reseller.Metrics` - external API usage events, summaries, cost estimation
- `Reseller.Billing` - plans, checkout links, webhook processing, expiry reminders
- `Reseller.Workers` - async orchestration for processing, exports, imports, and reminders

## Architecture Notes

- Phoenix 1.8 + LiveView application
- PostgreSQL via Ecto
- Tigris for S3-compatible object storage
- Req for external HTTP integrations
- Backpex for admin CRUD screens
- Background work currently runs through `Task.Supervisor`
- Background jobs are asynchronous but not durable across process or node crashes

The current supervision tree starts:

- `ResellerWeb.Telemetry`
- `Reseller.Repo`
- `DNSCluster`
- `Phoenix.PubSub`
- `Task.Supervisor` as `Reseller.Workers.TaskSupervisor`
- `Reseller.Workers.ExpiryScheduler`
- `ResellerWeb.Endpoint`

For a deeper walkthrough, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Local Development

### Prerequisites

- Elixir and Erlang/OTP compatible with the project
- PostgreSQL
- Node is not required for normal Phoenix dev because asset tooling is managed through Mix tasks

### Quick Start

```bash
mix setup
cp .env.example .env
mix phx.server
```

Open:

- `http://localhost:4000`
- `http://localhost:4000/docs/api`
- `http://localhost:4000/api/v1`

`mix setup` will:

- fetch dependencies
- create and migrate the database
- seed local data
- install/build front-end assets

### Seed Accounts

`mix setup` runs `priv/repo/seeds.exs`, which creates:

- `admin@resellerio.local` / `very-secure-password`
- `seller@resellerio.local` / `very-secure-password`

It also creates starter products in `draft`, `ready`, `sold`, and `archived` states so the workspace and API are useful immediately.

## Environment Variables

The app loads dotenv files in development and test using `Nvir`.

Development load order:

- `.env`
- `.env.dev`
- `.env.local`
- `.env.dev.local`

Test load order:

- `.env.test`
- `.env.test.local`

After changing runtime config or environment variables, restart Phoenix.

### Required In Production

- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `PHX_HOST`
- `PORT`

### AI, Search, and Media

- `GEMINI_API_KEY`
- `SERPAPI_API_KEY`
- `TIGRIS_ACCESS_KEY_ID`
- `TIGRIS_SECRET_ACCESS_KEY`
- `AWS_ENDPOINT_URL_S3` or `TIGRIS_ENDPOINT_URL`
- `TIGRIS_PUBLIC_URL` or `TIGRIS_BUCKET_URL`
- `TIGRIS_BUCKET_NAME`
- `PHOTOROOM_API_KEY`

### Billing

- `LEMONSQUEEZY_API_KEY`
- `LEMONSQUEEZY_WEBHOOK_SECRET`
- `LEMONSQUEEZY_STORE_ID`
- `LS_VARIANT_STARTER_MONTHLY`
- `LS_VARIANT_STARTER_ANNUAL`
- `LS_VARIANT_GROWTH_MONTHLY`
- `LS_VARIANT_GROWTH_ANNUAL`
- `LS_VARIANT_PRO_MONTHLY`
- `LS_VARIANT_PRO_ANNUAL`
- `LS_VARIANT_ADDON_AI_DRAFTS`
- `LS_VARIANT_ADDON_LIFESTYLE`
- `LS_VARIANT_ADDON_BG_REMOVALS`
- `LS_VARIANT_ADDON_EXTRA_SEAT`
- `BILLING_FROM_EMAIL`

### Common Optional Runtime Config

- `PHX_SERVER`
- `POOL_SIZE`
- `ECTO_IPV6`
- `DNS_CLUSTER_QUERY`
- `GEMINI_MODEL_RECOGNITION`
- `GEMINI_MODEL_DESCRIPTION`
- `GEMINI_MODEL_MARKETPLACE_LISTING`
- `GEMINI_MODEL_PRICE_RESEARCH`
- `GEMINI_MODEL_RECONCILIATION`
- `GEMINI_MODEL_LIFESTYLE_IMAGE`
- `GEMINI_TIMEOUT_MS`
- `GEMINI_MAX_RETRIES`
- `GEMINI_RETRY_BACKOFF_MS`

See [`config/runtime.exs`](config/runtime.exs) and [`.env.example`](.env.example) for the current source of truth.

## Docker

This repo includes:

- `Dockerfile` for a production release image
- `docker-compose.yml` for app + Postgres

The compose setup expects runtime secrets such as:

- `POSTGRES_PASSWORD`
- `SECRET_KEY_BASE`
- `DATABASE_URL`
- `PHX_HOST`
- any optional AI, storage, and billing credentials you want enabled

Start it with:

```bash
docker compose up -d --build
```

On container boot, the app service runs:

```bash
/app/bin/reseller eval 'Reseller.Release.migrate()'
/app/bin/reseller start
```

## Admin

Backpex is used for the admin UI.

- Admin dashboard: `/admin`
- Usage dashboard: `/admin/usage-dashboard`
- Raw API usage events: `/admin/api-usage-events`

Grant admin access to an existing user with:

```bash
mix reseller.make_admin EMAIL
```

## API Docs And Mobile Integration

- Human-readable API reference: [`docs/API.md`](docs/API.md)
- Mobile integration guide: [`docs/MOBILE_API_GUIDE.md`](docs/MOBILE_API_GUIDE.md)
- Architecture reference: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- UI system guidance: [`docs/UIUX.md`](docs/UIUX.md)

## Related Docs

- [`docs/PLANS.md`](docs/PLANS.md) - project progress tracker
- [`docs/PLAN-AI.md`](docs/PLAN-AI.md) - AI pipeline milestones
- [`docs/PLAN-GENERATE-IMAGE.md`](docs/PLAN-GENERATE-IMAGE.md) - lifestyle image generation plan
- [`docs/PRICING_PLAN.md`](docs/PRICING_PLAN.md) - billing implementation status
- [`docs/PRICING_CHECKS.md`](docs/PRICING_CHECKS.md) - billing audit gaps
- [`docs/METRICS-LIMITS-PLAN.md`](docs/METRICS-LIMITS-PLAN.md) - metrics and quota design
- [`docs/MARKETS.md`](docs/MARKETS.md) - marketplace-specific generation rules
- [`docs/MARKETPLACE_RULES.md`](docs/MARKETPLACE_RULES.md) - marketplace policy references

## Development Rules

- Keep business logic in contexts, not controllers or LiveViews
- Reuse `Reseller.Media.Storage` for upload signing and download URLs
- Reuse `Reseller.Workers` for async orchestration
- Use `Req` for HTTP integrations
- Make auth, ownership, and admin checks explicit and regression-tested
- Return `404` for foreign-owned resources
- Propagate `user_id` and `product_id` through worker opts for metric attribution

## Testing

Useful commands:

```bash
mix test
mix precommit
```

`mix precommit` runs:

- compile with warnings as errors
- `deps.unlock --unused`
- formatter
- test suite

Add tests with every auth, ownership, admin, API, or worker change. Fixtures live under `test/support/fixtures`.

## Current Status

The core inventory, AI enrichment, storefront, imports/exports, admin, metrics, and billing foundations are all present in the codebase.

Open follow-up work is tracked in:

- [`docs/PLANS.md`](docs/PLANS.md)
- [`docs/PLAN-GENERATE-IMAGE.md`](docs/PLAN-GENERATE-IMAGE.md)
- [`docs/PRICING_CHECKS.md`](docs/PRICING_CHECKS.md)

## References

- [Phoenix](https://www.phoenixframework.org/)
- [Phoenix Guides](https://hexdocs.pm/phoenix/overview.html)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [Backpex](https://hexdocs.pm/backpex/readme.html)
