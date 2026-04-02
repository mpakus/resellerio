# ResellerIO AI Plan

## Progress Tracker

- [x] Step AI1: Add Gemini and SerpApi configuration, client modules, and test doubles.
- [x] Step AI2.1: Add image selection and confidence-based recognition orchestration.
- [x] Step AI2.2: Wire recognition pipeline into product/image records and background workers.
- [x] Step AI3: Add structured product description generation.
- [x] Step AI4: Add grounded price research with Gemini plus SerpApi comparables.
- [x] Step AI5: Add marketplace-specific listing generation.
- [ ] Step AI6: Add admin observability, retries, and cost controls.

## Current Status

All AI pipeline steps through AI5 are shipped. The `Reseller.Workers.AIProductProcessor` orchestrates recognition, description generation, price research, marketplace listing generation, image processing, and optional lifestyle image generation as the final step.

Key modules:
- `Reseller.AI` — public context
- `Reseller.AI.Provider` — behaviour
- `Reseller.AI.Providers.Gemini` — HTTP client via `Req`
- `Reseller.Search.Providers.SerpApi` — HTTP client via `Req`
- `Reseller.AI.RecognitionPipeline` — image selection, Gemini extraction, SerpApi enrichment
- `Reseller.AI.Normalizer` — converts Gemini output to product fields
- `Reseller.AI.ScenePlanner` — category-aware scene planning for lifestyle generation
- `Reseller.AI.LifestylePromptBuilder` — scene-specific prompt construction
- `Reseller.Workers.AIProductProcessor` — full pipeline orchestration
- `Reseller.Workers.LifestyleImageGenerator` — lifestyle image step

## Open: Step AI6 — Admin Observability, Retries, Cost Controls

- Per-model cost dashboard in admin
- Retry UI for failed processing runs
- Per-user and per-product cost breakdown
- Configurable per-operation rate limits
- Rollout flag management for lifestyle generation

## Provider Notes

- Default model: `gemini-2.5-flash` for recognition, description, price research
- Lifestyle generation: `gemini-2.5-flash-image`
- SerpApi: Google Lens (`type=products`, `type=visual_matches`) + optional Google Shopping
- Gemini Files API: transient only (48-hour TTL); Tigris is the system of record
