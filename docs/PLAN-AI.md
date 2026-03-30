# Reseller AI Plan

## Progress Tracker

- [x] Step AI1: Add Gemini and SerpApi configuration, client modules, and test doubles.
- [x] Step AI2.1: Add image selection and confidence-based recognition orchestration.
- [x] Step AI2.2: Wire recognition pipeline into product/image records and background workers.
- [x] Step AI3: Add structured product description generation.
- [x] Step AI4: Add grounded price research with Gemini plus SerpApi comparables.
- [x] Step AI5: Add marketplace-specific listing generation.
- [ ] Step AI6: Add admin observability, retries, and cost controls.

## Latest AI Planning Status

- Current status: finalized product uploads now flow through `Reseller.Workers.AIProductProcessor`, which builds public image inputs, runs `Reseller.AI.RecognitionPipeline`, persists normalized fields onto `products`, generates a base description draft, runs grounded price research, generates marketplace listings, and marks image states `ready` or `failed`.
- Current limitation: this step uses finalized uploaded originals as the AI input source via `TIGRIS_BUCKET_URL`; normalization variants and Photoroom derivatives are still future work.
- Next implementation target: Step AI6 admin observability, retries, and cost controls.

## 1. Goal

Add Gemini-powered AI workflows to the backend so a reseller can upload product photos and have the system:

- recognize what is in the images
- extract structured product attributes
- draft a clean product title and base description
- research likely resale pricing from current web results
- generate marketplace-specific copy for eBay, Depop, Poshmark, and future channels

This plan is for backend integration first. Web and mobile surfaces should consume the resulting structured data and review states.

## 2. Current Repo Fit

The repo already has:

- `Reseller.Accounts` with password auth and API tokens
- `/api/v1` JSON foundation
- browser auth and a protected web shell
- Backpex admin for operational access
- `Req` already available for HTTP integrations
- `Reseller.AI` and `Reseller.Search` contexts with provider behaviours
- Req-backed Gemini and SerpApi production clients
- test-only fake providers for isolated unit tests
- `Reseller.AI.ImageSelection`, `Reseller.AI.Normalizer`, and `Reseller.AI.RecognitionPipeline`
- `Reseller.Catalog.Product` and `Reseller.Media.ProductImage`
- `Reseller.AI.ProductDescriptionDraft`
- `Reseller.AI.ProductPriceResearch`
- `Reseller.Marketplaces.MarketplaceListing`
- signed upload intent generation for product images
- upload finalization and uploaded-image state transitions
- `Reseller.Workers.ProductProcessingRun` plus lightweight async worker orchestration
- `Reseller.Workers.AIProductProcessor` for recognition, description, price research, and marketplace generation
- generated `product_description_drafts` stored separately from editable product fields
- generated `product_price_researches` stored separately from editable product pricing
- generated `marketplace_listings` stored separately per marketplace

The repo does not yet have:

- admin-facing AI retry/cost observability
- Photoroom-backed image-processing variants

So the core recognition, description, price research, and marketplace generation layers now exist, and the next AI milestone is operational hardening.

So Gemini should be added only after the catalog/media and worker foundations are in place, or in parallel with those foundations if we keep the write scope clean.

## 3. Provider Recommendation

Recommended provider path: Gemini Developer API over HTTPS using `Req`.

Why:

- It supports multimodal image understanding.
- It supports structured outputs via JSON schema.
- It supports Google Search grounding for fresher price research with citations.
- It fits a Phoenix backend well because we can call the REST API directly without adding a non-Elixir SDK.

Implementation note:

- Prefer direct REST calls with `Req` instead of wrapping another language runtime.
- Keep the integration behind a behaviour, for example `Reseller.AI.Provider`.

Recommended secondary search provider: SerpApi over HTTPS using `Req`.

Why:

- Google Lens search can find visual and exact matches that are useful for identifying branded or niche products from images.
- Lens `products`, `visual_matches`, and `exact_matches` results can seed stronger price-comparison inputs than model-only reasoning.
- SerpApi Google Shopping can provide an additional structured search path when we have a normalized product query.

Combined strategy:

- Gemini handles multimodal extraction, normalization, and final reasoning.
- SerpApi supplies structured visual-match and shopping results.
- The backend merges both into one price-research record with confidence and sources.

Official references:

- Image understanding: [ai.google.dev/gemini-api/docs/image-understanding](https://ai.google.dev/gemini-api/docs/image-understanding)
- Files API: [ai.google.dev/gemini-api/docs/files](https://ai.google.dev/gemini-api/docs/files)
- Structured outputs: [ai.google.dev/gemini-api/docs/structured-output](https://ai.google.dev/gemini-api/docs/structured-output)
- Google Search grounding: [ai.google.dev/gemini-api/docs/grounding](https://ai.google.dev/gemini-api/docs/grounding)
- Pricing: [ai.google.dev/gemini-api/docs/pricing](https://ai.google.dev/gemini-api/docs/pricing)
- SerpApi Google Lens: [serpapi.com/google-lens-api](https://serpapi.com/google-lens-api)
- SerpApi Google Lens Products: [serpapi.com/google-lens-products-api](https://serpapi.com/google-lens-products-api)
- SerpApi Google Shopping: [serpapi.com/google-shopping-api](https://serpapi.com/google-shopping-api)

## 4. Model Strategy

Recommended default:

- use `gemini-2.5-flash` for image recognition, extraction, and description generation

Recommended escalation path:

- allow fallback or manual rerun with `gemini-2.5-pro` for difficult or high-value items

This model selection is an implementation recommendation inferred from the current official docs: Gemini 2.5 Flash supports multimodal image input, structured outputs, and Google Search grounding while remaining cheaper than the larger model.

## 5. Product Workflow

### Recommended Intake Pipeline

This is the recommended product-intake AI pipeline for the first production version:

1. User uploads `1..5` photos.
2. Backend creates normalized derivatives:
   - resized versions for model input
   - optional object crop when the subject can be isolated safely
   - white-background version when that improves identification or listing quality
3. Backend sends the best image set to Gemini and asks for structured JSON.
4. Gemini returns:
   - `brand`
   - `category`
   - `possible_model`
   - `color`
   - `material`
   - `logo_text`
   - `distinguishing_features`
   - `confidence`
5. If confidence is low, backend calls SerpApi Google Lens.
6. Backend collects the top visual matches and extracts `title`, `brand`, `price`, and `source`.
7. Backend makes a second LLM reconciliation call to answer:
   - whether the matches are the same model or not
   - which model is most likely
   - what `min`, `max`, and `median` resale prices look reasonable
   - what short product-card description should be saved
8. Backend stores the structured result in the database for user review.

Recommended adjustments:

- always keep the original uploaded images untouched
- use field-level confidence, not only one overall confidence score
- treat object crop as optional because aggressive cropping can remove useful logos, stitching, or tags
- use SerpApi not only for low-confidence recognition, but also as an optional pricing enrichment step when confidence is medium and brand/model hints exist
- compute pricing after basic outlier filtering, because top Lens matches can mix unrelated or retail results

### A. Recognition

1. User uploads product photos to Tigris.
2. Backend finalizes `ProductImage` records.
3. A worker creates normalized AI-input image variants from up to 5 selected photos.
4. Backend sends images plus extraction instructions to Gemini.
5. Gemini returns structured JSON for product attributes.
6. Backend evaluates confidence by field and overall.
7. If recognition confidence is below threshold, backend enriches with SerpApi Google Lens matches.
8. Backend normalizes the response into product fields and review flags.
9. Product moves to `review` or `ready`.

### B. Description Generation

1. After recognition succeeds, a worker calls Gemini again with the normalized product data.
2. Gemini returns a base title, summary, bullets, and optional notes for missing details.
3. Backend stores generated copy separately from user-edited copy.

### C. Price Research

1. Backend asks Gemini to perform grounded price research using the `google_search` tool.
2. Backend also calls SerpApi Google Lens on one or more product images to fetch `products`, `visual_matches`, and optionally `exact_matches`.
3. If we have a good normalized title or brand/model signal, backend also calls SerpApi Google Shopping with a text query.
4. Backend extracts top comparable fields such as `title`, `brand`, `price`, and `source` from SerpApi responses.
5. Backend merges Gemini grounded results with SerpApi comparables.
6. Gemini performs a reconciliation step and returns or refines a structured price recommendation with citations and comparable listings summary.
7. Backend stores the suggested price range and source metadata.
8. UI can show the recommendation as advisory, never as an automatic final sale price.

### D. Marketplace Copy

1. Backend takes the normalized product attributes and base description.
2. Gemini generates marketplace-specific title/description/tag output per channel.
3. Backend stores each output in `marketplace_listings`.
4. User reviews and edits before publishing anywhere.

## 6. Output Contracts

### Recognition JSON

Use Gemini structured output with a JSON schema so parsing stays deterministic.

Suggested fields:

- `item_type`
- `title_seed`
- `brand`
- `category`
- `subcategory`
- `possible_model`
- `condition`
- `color`
- `size`
- `material`
- `logo_text`
- `gender_age_group`
- `style_tags`
- `detected_logos`
- `visible_flaws`
- `inventory_notes`
- `distinguishing_features`
- `confidence_score`
- `field_confidence`
- `needs_review`
- `missing_information`

Suggested rule:

- keep model output descriptive and structured
- do not let Gemini write directly to `products` without normalization

### Description JSON

Suggested fields:

- `suggested_title`
- `short_description`
- `long_description`
- `key_features`
- `care_or_condition_notes`
- `seo_keywords`
- `missing_details_warning`

### Price Research JSON

Suggested fields:

- `currency`
- `suggested_min_price`
- `suggested_target_price`
- `suggested_max_price`
- `suggested_median_price`
- `pricing_confidence`
- `rationale_summary`
- `market_signals`
- `comparable_results`

Each comparable result should include:

- `title`
- `marketplace`
- `price`
- `condition`
- `url`
- `source_domain`

### Marketplace Listing JSON

Suggested fields:

- `marketplace`
- `generated_title`
- `generated_description`
- `generated_tags`
- `pricing_note`
- `compliance_warnings`

## 7. Data Model Additions

Recommended additions after `products` and `product_images` exist:

- `product_ai_runs`
  - `product_id`
  - `status`
  - `step`
- `provider`
- `model`
- `request_id`
- `input_image_count`
- `normalization_profile`
  - `input_tokens`
  - `output_tokens`
  - `cost_cents`
  - `started_at`
  - `finished_at`
  - `error_code`
  - `error_message`

- `product_ai_extractions`
  - `product_id`
  - `run_id`
  - `raw_payload`
  - `normalized_payload`
  - `confidence_score`
  - `field_confidence`
  - `needs_review`

- `product_price_researches`
  - `product_id`
  - `run_id`
  - `currency`
  - `suggested_min_price`
  - `suggested_target_price`
  - `suggested_max_price`
  - `pricing_confidence`
  - `rationale_summary`
  - `source_strategy`
  - `raw_payload`

- `product_price_comparables`
  - `price_research_id`
  - `title`
  - `marketplace`
  - `price`
  - `condition`
  - `url`
  - `source_domain`
  - `source_provider`
  - `match_type`

- `product_external_searches`
  - `product_id`
  - `run_id`
  - `provider`
  - `search_type`
  - `request_payload`
  - `response_payload`
  - `status`
  - `requested_at`
  - `completed_at`

Important rule:

- keep AI raw payloads for debugging, but store normalized business fields separately

## 8. Integration Design

Recommended modules:

- `Reseller.AI`
  - public context API

- `Reseller.AI.Provider`
  - behaviour for model operations

- `Reseller.AI.Providers.Gemini`
  - production Gemini implementation using `Req`

- `Reseller.Search`
  - external search orchestration for comparables

- `Reseller.Search.Provider`
  - behaviour for external search providers

- `Reseller.Search.Providers.SerpApi`
  - production SerpApi implementation using `Req`

- `Reseller.AI.Prompts`
  - prompt builders and JSON schema helpers

- `Reseller.AI.Normalizer`
  - converts Gemini output into internal product fields

- `Reseller.AI.Reconciliation`
  - merges Gemini extraction with SerpApi evidence and computes the final structured result

- `Reseller.AI.PriceResearch`
  - merges Gemini and SerpApi signals into a normalized pricing view

- `Reseller.Workers.ProductRecognitionWorker`
- `Reseller.Workers.ProductDescriptionWorker`
- `Reseller.Workers.ProductPriceResearchWorker`
- `Reseller.Workers.MarketplaceListingWorker`

Recommended configuration:

- `config :reseller, Reseller.AI, provider: Reseller.AI.Providers.Gemini`
- `config :reseller, Reseller.AI.Providers.Gemini, api_key: ..., base_url: ...`
- `config :reseller, Reseller.Search, provider: Reseller.Search.Providers.SerpApi`
- `config :reseller, Reseller.Search.Providers.SerpApi, api_key: ..., base_url: ...`

Environment variables:

- `GEMINI_API_KEY`
- `GEMINI_MODEL_RECOGNITION`
- `GEMINI_MODEL_DESCRIPTION`
- `GEMINI_MODEL_PRICE_RESEARCH`
- `SERPAPI_API_KEY`

## 9. Image Input Strategy

Gemini supports inline image data for smaller requests and the Files API for larger or reusable inputs.

Recommended backend rule:

- for small image batches, send inline bytes
- for larger requests or retries across multiple prompts, upload to Gemini Files API first

Recommended normalization flow before model calls:

- preserve the original upload as the source of truth
- generate AI-input resized versions
- optionally create object-crop variants
- optionally create white-background variants
- keep metadata linking every derivative back to the original image

Decision rule:

- send both the original-style normalized image and the crop only when the crop materially improves focus
- do not replace all inputs with crops because labels, soles, tags, or edge details may be lost

Important operational detail from the official Files API docs:

- uploaded Gemini files are temporary and automatically deleted after 48 hours

So:

- Tigris remains the system of record
- Gemini Files API is only transient processing storage

## 10. Price Search Strategy

For price research, prefer a blended strategy instead of asking Gemini to guess from model memory.

Recommended approach:

- enable the `google_search` tool
- run SerpApi Google Lens on the strongest product image
- use SerpApi `type=products` and `type=visual_matches` by default
- use SerpApi `type=exact_matches` when brand/model confidence is high enough
- use SerpApi Lens `q` when Gemini already extracted a likely brand/model and we want to refine the visual search
- optionally run SerpApi Google Shopping from the normalized product query
- ask for resale-oriented price analysis, not retail MSRP
- constrain the output to used-item or secondhand-market signals when possible
- require citations in stored output
- retain source-provider attribution for every comparable

Important product rule:

- never auto-publish or auto-save a final user-facing price from AI alone
- always treat AI pricing as a suggestion with confidence and sources

Recommended decision order:

1. SerpApi Lens finds likely matches and comparable offers from the image itself.
2. Gemini grounded search broadens the evidence set and summarizes current web pricing signals.
3. Backend merges the comparables, deduplicates them, removes obvious outliers, and asks Gemini to synthesize a price range.

Recommended statistics:

- keep `min`, `max`, and `median`
- prefer `median` as the default internal anchor because it is more robust than average
- track whether each comparable looks resale, marketplace, or retail-like

## 11. Prompting Rules

### Recognition Prompt Rules

- include only the images and minimal known metadata
- ask for visible facts, not speculation
- ask the model to explicitly mark uncertainty
- prefer shorter, structured attribute values over long prose
- ask for field-level confidence when possible
- ask for `possible_model` rather than claiming an exact model when uncertainty remains

### Description Prompt Rules

- use normalized product fields as the source of truth
- avoid inventing missing dimensions, sizing, or authenticity claims
- generate concise reseller-friendly copy
- mention condition issues clearly if present

### Price Prompt Rules

- ask for secondhand resale pricing, not new-item retail pricing
- ask for a realistic sale range, not one fixed number
- provide SerpApi Lens and Shopping results as structured evidence when available
- require comparable links and a short rationale
- require a confidence score and `needs_review` style outcome
- ask the model to decide whether the top matches refer to the same model or to similar but different items

## 12. API Shape

This should stay asynchronous.

Recommended future internal or authenticated endpoints:

- `POST /api/v1/products/:id/recognize`
- `POST /api/v1/products/:id/generate-description`
- `POST /api/v1/products/:id/research-price`
- `POST /api/v1/products/:id/regenerate-marketplace-listings`
- `GET /api/v1/products/:id/ai`

Behavior:

- enqueue work and return job state
- do not block mobile requests on full Gemini round-trips

## 13. Failure Handling

Expected failure cases:

- invalid or unsupported image formats
- low-confidence recognition
- Gemini rate limiting
- SerpApi rate limiting or quota exhaustion
- weak or noisy Lens visual matches
- grounding returning weak or no comparables
- malformed structured output
- partial success where recognition works but price research fails

Recommended behavior:

- store step-level failure status
- support retry by step
- preserve last successful outputs
- allow price research to proceed with Gemini-only or SerpApi-only evidence when one provider fails
- surface human-review-required states instead of silent failure

## 14. Security and Privacy

- send only the minimum required data to Gemini
- send only the minimum required product image URLs or metadata to SerpApi
- never send password, token, or unrelated user data
- keep external requests server-side only
- log request IDs and high-level status, not full sensitive payloads by default
- gate admin inspection of raw AI payloads to admin-only screens
- clearly disclose that price research uses web-grounded AI results

## 15. Testing Plan

### Unit tests

- prompt builders
- JSON normalization
- confidence and review-flag logic
- comparable parsing and citation extraction
- Lens and Shopping result normalization
- reconciliation of ambiguous model matches
- outlier filtering and median price calculation

### Integration tests

- `Reseller.AI` context with mocked provider
- `Reseller.Search` context with mocked SerpApi provider
- worker tests for happy path, retry, and partial failure
- API endpoint tests for enqueue and status retrieval

### Security and regression tests

- provider responses missing required fields
- invalid JSON or schema mismatch
- unexpected extra fields
- failed grounding calls
- failed or empty SerpApi Lens responses
- retry idempotency so the same product is not duplicated

## 16. Delivery Order

### Phase AI1

- add `Reseller.AI` context
- add `Reseller.Search` context
- add Gemini provider behaviour and production implementation
- add SerpApi provider behaviour and production implementation
- add config, test doubles, and request/response logging wrappers

### Phase AI2

- add recognition worker
- define recognition JSON schema
- normalize into product draft fields
- add image normalization and derivative selection for AI input

### Phase AI3

- add base description generation
- store generated copy separately from editable product fields

### Phase AI4

- add grounded price research
- add SerpApi Google Lens and Shopping enrichment
- add reconciliation step for “same model or similar model”
- store comparable links, source providers, pricing stats, and rationale

### Phase AI5

- add marketplace-specific output generation
- store one generated record per marketplace

### Phase AI6

- add admin visibility, retries, metrics, and cost reporting

## 17. Open Decisions

- Gemini Developer API vs Vertex AI for long-term production compliance needs
- exact worker library choice if background jobs are not yet settled
- whether price research should be user-triggered only or part of the automatic pipeline
- whether marketplace pricing should be one shared suggestion or one per marketplace
- whether we should support a manual “re-run with stronger model” action from the start

## 18. Recommendation

Start with:

1. structured image recognition
2. base product description generation
3. grounded price research with Gemini plus SerpApi Lens/Shopping enrichment

Marketplace-specific generation should come after those three are stable, because it depends on clean extracted product data and trustworthy review flows.
