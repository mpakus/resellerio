# Reseller

Reseller is a Phoenix backend for a mobile app used by resellers to create and manage product inventory from photos.

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
- Authenticated product endpoints at `GET /api/v1/products`, `POST /api/v1/products`, and `GET /api/v1/products/:id`
- Upload finalization endpoint at `POST /api/v1/products/:id/finalize_uploads`
- Browser sign-in and sign-up LiveViews
- Protected web workspace at `/app`
- Backpex admin interface under `/admin` for admin users
- AI foundation contexts `Reseller.AI` and `Reseller.Search`
- Req-backed Gemini and SerpApi client modules with tests
- Recognition orchestration with image selection, confidence gating, Lens fallback, and reconciliation
- Product and product-image schemas plus signed upload intent generation
- Uploaded-image finalization and product state transitions into `processing`
- Product processing run records and lightweight background worker execution
- Real AI-backed product processing that persists recognition fields and closes image states
- AI-generated base description drafts stored separately from editable product fields
- In-repo API reference in `docs/API.md`
- Planning tracker in `docs/PLANS.md`

Not implemented yet:

- Product edit/delete/sold lifecycle endpoints
- Passkey authentication
- Photoroom-powered image variants
- Marketplace-specific listing generation
- Import/export

## Local Development

1. Run `mix setup`
2. Start the server with `mix phx.server`
3. Open [http://localhost:4000](http://localhost:4000)
4. Check the API with `GET /api/v1`

## Project Docs

- Implementation plan and progress tracker: `docs/PLANS.md`
- API reference: `docs/API.md`
- Web implementation plan: `docs/PLAN-WEB.md`
- AI implementation plan: `docs/PLAN-AI.md`
- Project-specific coding guidance for agents and contributors: `AGENTS.md`

## AI Provider Setup

The recognition pipeline is now wired into product processing runs.

- Gemini API key: `GEMINI_API_KEY`
- Optional Gemini model overrides: `GEMINI_MODEL_RECOGNITION`, `GEMINI_MODEL_DESCRIPTION`, `GEMINI_MODEL_PRICE_RESEARCH`, `GEMINI_MODEL_RECONCILIATION`
- SerpApi key: `SERPAPI_API_KEY`
- Tigris upload signing and public image base: `TIGRIS_ACCESS_KEY_ID`, `TIGRIS_SECRET_ACCESS_KEY`, `TIGRIS_BUCKET_URL`

Current implementation note:

- `TIGRIS_BUCKET_URL` is used both for upload signing and for building public image URLs consumed by Gemini and SerpApi during processing
- recognized products can now also receive a generated `product_description_draft` during the same processing run

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
