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
- Health endpoint at `GET /api/v1/health`
- Stable JSON error payload shape for API errors
- Planning tracker in `docs/PLANS.md`

Not implemented yet:

- Authentication
- Product schemas and CRUD
- Upload flow
- Background jobs
- AI integrations
- Import/export

## Local Development

1. Run `mix setup`
2. Start the server with `mix phx.server`
3. Open [http://localhost:4000](http://localhost:4000)
4. Check the API with `GET /api/v1/health`

## Project Docs

- Implementation plan and progress tracker: `docs/PLANS.md`
- Project-specific coding guidance for agents and contributors: `AGENTS.md`

## Workflow

- Update `docs/PLANS.md` as each feature starts or completes.
- Keep each feature in its own git commit.
- Run `mix precommit` before finishing a feature.

## Phoenix References

- [Phoenix](https://www.phoenixframework.org/)
- [Phoenix Guides](https://hexdocs.pm/phoenix/overview.html)
- [Phoenix Docs](https://hexdocs.pm/phoenix)
- [Phoenix Forum](https://elixirforum.com/c/phoenix-forum)
