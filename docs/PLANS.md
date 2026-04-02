# ResellerIO Backend Plan

## Progress Tracker

- [x] Step 1: API foundation with versioned `/api/v1`, health check endpoint, and stable JSON error shape.
- [x] Step 2: Accounts foundation with `users`, password auth, and mobile session tokens.
- [x] Step 3.1: Product and product image schemas plus signed upload intent generation.
- [x] Step 3.2: Finalize-upload endpoint and uploaded-image state transitions.
- [x] Step 4.1: Product processing run records and lightweight async worker foundation.
- [x] Step 4.2: Connect processing runs to the real AI/media worker pipeline.
- [x] Step 5.1: Base AI description generation and product description draft storage.
- [x] Step 5.2: Grounded price research with Gemini plus SerpApi comparables.
- [x] Step 5.3: Marketplace listing generation.
- [x] Step 6: Photoroom-powered image processing variants.
- [x] Step 7: ZIP export generation and export-ready email flow.
- [x] Step 8: ZIP import flow.
- [x] Step 9: Product lifecycle endpoints for edit, delete, sold, archive, and restore flows.
- [x] Step 10: Production Docker packaging with release-based container startup.
- [x] Step 11: Product tags plus seller-managed status changes in API and web workspace.
- [x] Step 11.1: Per-user marketplace defaults plus expanded marketplace catalog.

## Open Items

- Step GI7: Cost controls, rate limits, observability, and rollout guardrails for lifestyle image generation. See `docs/PLAN-GENERATE-IMAGE.md`.
- Step SF7: SEO and social card meta tags (canonical URL, Open Graph image, description) for public storefront pages.
- Step AI6: Admin observability, retries, and cost controls. See `docs/PLAN-AI.md`.
- Pricing system audit gaps: trial start on registration, trial expiry enforcement, lifestyle limit gate, addon credit math fix. See `docs/PRICING_CHECKS.md`.

## Docs

- `docs/API.md` — routes, payloads, auth, response shapes.
- `docs/ARCHITECTURE.md` — schemas, relationships, workers, integrations.
- `docs/UIUX.md` — shared LiveView patterns and components.
- `docs/PLAN-AI.md` — AI pipeline milestone status.
- `docs/PLAN-GENERATE-IMAGE.md` — lifestyle image generation status.
- `docs/PRICING_PLAN.md` — billing and subscription milestone status.
- `docs/PRICING_CHECKS.md` — billing system audit gaps and fix recommendations.
- `docs/METRICS-LIMITS-PLAN.md` — metrics, cost config, limit logic.
- `docs/MOBILE_API_GUIDE.md` — mobile integration guide.
- `docs/MARKETS.md` — marketplace-specific copy generation rules.
- `docs/MARKETPLACE_RULES.md` — marketplace policy reference.
- `docs/PRICING.md` — pricing positioning and competitor analysis.

## Working Rules

- Update this file before creating each feature commit.
- Keep one feature per git commit.
- Run `mix precommit` before finishing the feature branch or checkpoint.
