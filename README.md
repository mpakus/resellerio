# Resellerio

Resellerio is a Phoenix backend for a mobile app used by resellers to create and manage product inventory from photos.

The long-term product flow is:

1. User taps `+Add` in the mobile app.
2. Photos are uploaded and attached to a new product.
3. The backend stores originals in Tigris.
4. AI recognizes the item and fills product details.
5. The system generates marketplace-specific listing copy for eBay, Depop, Poshmark, and future channels.

## Current Status

The project is in early backend foundation work.

Implemented already:

- Versioned JSON API namespace at `/api/v1`
- API root endpoint at `GET /api/v1`
- Health endpoint at `GET /api/v1/health`
- Stable JSON error payload shape for API errors
- Password-based user registration and login
- Bearer-token authentication for `GET /api/v1/me`
- Authenticated product endpoints at `GET /api/v1/products`, `POST /api/v1/products`, `GET /api/v1/products/:id`, `PATCH /api/v1/products/:id`, and `DELETE /api/v1/products/:id`
- Product lifecycle endpoints at `POST /api/v1/products/:id/finalize_uploads`, `POST /api/v1/products/:id/mark_sold`, `POST /api/v1/products/:id/archive`, and `POST /api/v1/products/:id/unarchive`
- Browser sign-in and sign-up LiveViews
- Protected web workspace at `/app`, `/app/products`, `/app/listings`, `/app/exports`, and `/app/settings`
- Web product intake with browser photo uploads and product creation
- Web product detail editing with seller-managed tags and statuses, plus sold/archive/restore/delete lifecycle actions
- Web export requests and ZIP imports from the Resellerio workspace
- Backpex admin interface under `/admin` for admin users
- AI foundation contexts `Reseller.AI` and `Reseller.Search`
- Req-backed Gemini and SerpApi client modules with tests
- Recognition orchestration with image selection, confidence gating, Lens fallback, and reconciliation
- Product and product-image schemas plus signed upload intent generation
- Uploaded-image finalization and product state transitions into `processing`
- Product processing run records and lightweight background worker execution
- Real AI-backed product processing that persists recognition fields and closes image states
- AI-generated base description drafts stored separately from editable product fields
- AI-generated price research stored separately from editable product pricing
- Marketplace-specific listing records for eBay, Depop, and Poshmark
- Photoroom-backed processed image variants
- ZIP export generation with email-ready notifications
- ZIP import flow that recreates products, images, and generated metadata from reseller archives
- Product tags stored directly on `products` and preserved through ZIP export/import
- In-repo API reference in `docs/API.md`
- Planning tracker in `docs/PLANS.md`

Not implemented yet:

- Passkey authentication

## Local Development

1. Run `mix setup`
2. Create a local `.env` from `.env.example` and fill in the credentials you need
3. Start the server with `mix phx.server`
4. Open [http://localhost:4000](http://localhost:4000)
5. Check the API with `GET /api/v1`

`mix setup` already runs [priv/repo/seeds.exs](/Users/mpak/www/elixir/reseller/priv/repo/seeds.exs), which now creates local starter data:

- `admin@resellerio.local` / `very-secure-password`
- `seller@resellerio.local` / `very-secure-password`

It also creates a few starter products in `draft`, `ready`, `sold`, and `archived` states so the UI and API are useful on first boot.

## Project Docs

- Implementation plan and progress tracker: `docs/PLANS.md`
- API reference: `docs/API.md`
- Web implementation plan: `docs/PLAN-WEB.md`
- AI implementation plan: `docs/PLAN-AI.md`
- Project-specific coding guidance for agents and contributors: `AGENTS.md`

## Credentials

This project reads runtime credentials from environment variables in [config/runtime.exs](/Users/mpak/www/elixir/reseller/config/runtime.exs) and uses `Nvir` to load local dotenv files during development and test.

For local development, the simplest path is:

```bash
cp .env.example .env
```

Then fill in the values you need and start Phoenix. In development, the app loads these files automatically if they exist:

- `.env`
- `.env.dev`
- `.env.local`
- `.env.dev.local`

In test, the app loads:

- `.env.test`
- `.env.test.local`

After changing credentials or `config/*.exs`, restart the Phoenix server.

You can still export variables in the shell if you prefer. Example:

```bash
export GEMINI_API_KEY="..."
export SERPAPI_API_KEY="..."
export TIGRIS_ACCESS_KEY_ID="..."
export TIGRIS_SECRET_ACCESS_KEY="..."
export TIGRIS_BUCKET_URL="https://your-bucket-name.your-region.tigris.dev"
export PHOTOROOM_API_KEY="..."
mix phx.server
```

If you use `direnv`, `mise`, Docker, Fly.io, Render, Railway, or another deploy system, put the same variable names there. `.env` files are for local development and test convenience and should not be committed.

### Required in Production

- `DATABASE_URL`
  PostgreSQL connection string used by Ecto.
  Example: `ecto://USER:PASS@HOST/DATABASE`

- `SECRET_KEY_BASE`
  Phoenix secret used to sign/encrypt cookies and tokens.
  Generate with `mix phx.gen.secret`

- `PHX_HOST`
  Public host name for the app.
  Example: `api.example.com`

- `PORT`
  HTTP port for the Phoenix endpoint.
  Defaults to `4000` if omitted

### Required For AI, Search, and Media Features

- `GEMINI_API_KEY`
  Google Gemini API key used for image recognition, reconciliation, description generation, price research, and marketplace listing generation

- `SERPAPI_API_KEY`
  SerpApi key used for Google Lens and Shopping enrichment

- `TIGRIS_ACCESS_KEY_ID`
  Tigris S3-compatible access key ID used for upload signing and object uploads

- `TIGRIS_SECRET_ACCESS_KEY`
  Tigris S3-compatible secret key used for upload signing and object uploads

- `TIGRIS_BUCKET_URL`
  Public base URL for your Tigris bucket
  Example: `https://bucket-name.region.tigris.dev`
  This is used both for storage operations and for public image URLs consumed by Gemini, SerpApi, ZIP export downloads, and ZIP import archive fetches

- `PHOTOROOM_API_KEY`
  Photoroom API key used for background removal and white-background image variants

### Optional Runtime Variables

- `PHX_SERVER`
  Set to `true` when starting a release if you want the web server enabled

- `POOL_SIZE`
  Database pool size in production
  Defaults to `10`

- `ECTO_IPV6`
  Set to `true` or `1` to enable IPv6 socket options for Postgres connections

- `DNS_CLUSTER_QUERY`
  Optional DNS cluster query used for clustered deployments

### Optional Gemini Model Overrides

If you want to override the default Gemini model per operation, set any of:

- `GEMINI_MODEL_RECOGNITION`
- `GEMINI_MODEL_DESCRIPTION`
- `GEMINI_MODEL_MARKETPLACE_LISTING`
- `GEMINI_MODEL_PRICE_RESEARCH`
- `GEMINI_MODEL_RECONCILIATION`

Current defaults in runtime config are all `gemini-2.5-flash`.

### Optional Mailer Credentials

The repo uses the local Swoosh adapter in development and test, so no mail credentials are required locally by default.

If you switch production email delivery to a real provider, add the provider-specific credentials in your deployment environment. The example already noted in [config/runtime.exs](/Users/mpak/www/elixir/reseller/config/runtime.exs) is:

- `MAILGUN_API_KEY`
- `MAILGUN_DOMAIN`

You will also need to change the Swoosh adapter config accordingly.

### Where To Add Them

- Local terminal session:
  Export variables in your shell before `mix phx.server`

- Shell profile:
  Add `export ...` lines to `~/.zshrc`, `~/.bashrc`, or equivalent if you want them loaded automatically

- `direnv` / `.envrc`:
  Good for project-local development secrets without committing them

- Docker / Compose:
  Put them in `environment:` or `env_file`

- Production hosting:
  Add them in your platform's secrets/settings UI, because `runtime.exs` reads them at boot time

## Docker

This repo now includes:

- [Dockerfile](/Users/mpak/www/elixir/reseller/Dockerfile)
  Multi-stage production image that builds a Phoenix release

- [docker-compose.yml](/Users/mpak/www/elixir/reseller/docker-compose.yml)
  Production-style app + Postgres setup with automatic migrations on boot

- [.dockerignore](/Users/mpak/www/elixir/reseller/.dockerignore)
  Keeps the build context small and avoids copying local build artifacts into the image

### Docker Compose Credentials

For `docker compose`, set the same runtime secrets in your shell or in a compose `.env` file before starting:

```bash
export POSTGRES_PASSWORD="change-me"
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export DATABASE_URL="ecto://reseller:${POSTGRES_PASSWORD}@db/reseller_prod"
export PHX_HOST="your-domain.example"
export GEMINI_API_KEY="..."
export SERPAPI_API_KEY="..."
export TIGRIS_ACCESS_KEY_ID="..."
export TIGRIS_SECRET_ACCESS_KEY="..."
export TIGRIS_BUCKET_URL="https://your-bucket-name.your-region.tigris.dev"
export PHOTOROOM_API_KEY="..."
```

Then run:

```bash
docker compose up -d --build
```

The compose setup will:

- build the release image
- start Postgres
- wait for Postgres health checks
- run `Reseller.Release.migrate()`
- start the Phoenix release on port `4000`

### Docker Notes

- The app container expects `DATABASE_URL` explicitly, even though the compose file also starts Postgres
- The published port is controlled by `APP_PORT`, which defaults to `4000`
- `PHX_HOST` should match the external host you use in production
- If you use an external managed Postgres instead of the included `db` service, point `DATABASE_URL` at that database and remove or ignore the compose `db` service

## Implementation Notes

- `TIGRIS_BUCKET_URL` is used both for upload signing and for building public image URLs consumed by Gemini and SerpApi during processing
- recognized products can now also receive a generated `product_description_draft` during the same processing run
- recognized products can now also receive a generated `product_price_research` during the same processing run
- recognized products can now also receive generated `marketplace_listings` during the same processing run
- recognized products can now also receive Photoroom-backed `background_removed` and `white_background` image variants during the same processing run
- authenticated users can now request ZIP exports that are uploaded in the background and emailed when ready
- authenticated users can now import Resellerio ZIP archives via `POST /api/v1/imports`; the current API accepts the archive as base64 JSON and recreates products without re-running AI
- authenticated users can now update product details, delete products, mark products as sold, archive them, and restore archived products through explicit lifecycle endpoints

## Admin Access

Backpex is installed for the admin interface.

- Admin UI: `/admin`
- Bootstrap an admin user: `mix reseller.make_admin EMAIL`

Admin routes are protected and only users with `is_admin = true` can access them.

## Workflow

- Update `docs/PLANS.md` as each feature starts or completes.
- Keep each feature in its own git commit.
- Run `mix precommit` before finishing a feature.

## Phoenix References

- [Phoenix](https://www.phoenixframework.org/)
- [Phoenix Guides](https://hexdocs.pm/phoenix/overview.html)
- [Phoenix Docs](https://hexdocs.pm/phoenix)
- [Phoenix Forum](https://elixirforum.com/c/phoenix-forum)
