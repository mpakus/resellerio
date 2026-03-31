# Resellerio Lifestyle Image Generation Plan

## Progress Tracker

- [x] Step GI1: Research Gemini Developer API image generation and editing capabilities for this repo.
- [x] Step GI2: Add a dedicated lifecycle model for lifestyle-image generation runs and generated outputs.
- [x] Step GI3: Add Gemini provider support for image generation/editing from existing product images.
- [x] Step GI4: Add category-aware scene planning for apparel, furniture, electronics, and fallback product types.
- [x] Step GI5: Run lifestyle-image generation as the 8th and final optional product-processing step.
- [x] Step GI6: Add review, regenerate, approve, and delete controls in web and API surfaces.
- [ ] Step GI7: Add cost controls, rate limits, observability, and rollout guardrails.

## Latest Planning Status

- Current status: Steps GI3 through GI6 are now in place. The product page and JSON API can review dedicated lifestyle-generation runs, manually trigger generation or scene regeneration, approve generated previews, and delete unwanted outputs.
- Rollout status: auto-generation is still disabled by default behind `Reseller.AI.lifestyle_generation_enabled?/1`, but seller-triggered generation controls now work for products that already reached review-ready states.
- Next implementation target: Step GI7, adding cost controls, rate limits, observability, and rollout guardrails.
- Technical fit remains strong: the official Gemini image-generation docs state that Gemini can generate and process images conversationally with text, images, or a combination of both, which fits our goal of using uploaded and background-cleaned product images as conditioning input.
- Recommended default model: `gemini-2.5-flash-image` for the first implementation because the repo already uses the Gemini Developer API directly with `Req`, and this model is optimized for fast, high-volume image generation and editing.
- Recommended quality fallback: `gemini-3.1-flash-image-preview` or `gemini-3-pro-image-preview` for seller-triggered regenerations or high-value items where fidelity matters more than cost.
- Recommended generation pattern: generate 2-3 lifestyle images as 2-3 separate requests, not one bulk request. This keeps prompt variation explicit, isolates failures, and fits the current worker architecture better than trying to multiplex all variants in one response.
- Recommended source image policy: prefer `background_removed` first, then fall back to the original upload. Legacy `white_background` images can still be used as a fallback when older products already have them attached. Gemini docs currently say `gemini-2.5-flash-image` works best with up to 3 input images, so we should keep each request tight.

## 1. Goal

Add a final AI workflow that creates 2-3 "real life" lifestyle images for each product as the 8th and last processing step, after uploads, recognition, pricing, marketplace copy, and image cleanup are already complete.

Examples:

- clothes: show the item on a person or model in a believable lifestyle scene
- furniture: place the item inside a realistic room interior with supporting decor
- electronics: show the item in a natural desk, home, work, or everyday-use setting
- general products: produce believable contextual scenes that help a reseller visualize how the item appears in real use

This feature should be optional, reviewable, and clearly labeled as AI-generated.

## 2. Research Summary

Official Gemini docs currently indicate:

- Gemini image models support image generation and editing from text, images, or both.
- `gemini-2.5-flash-image` is positioned as a native image-generation and editing model optimized for fast creative workflows.
- `gemini-3.1-flash-image-preview` supports text-plus-image generation with `responseModalities` and `imageConfig`.
- Gemini image requests can include multiple images, but the current docs note that `gemini-2.5-flash-image` works best with up to 3 input images.
- Inline image bytes are limited by total request size under 20MB; for larger or repeated inputs, Google recommends the Files API.
- Generated Gemini images include SynthID watermarking.

Planning implication:

- Yes, the main idea is technically viable with Gemini.
- The safest first version is not "virtual try-on" in the strict ecommerce sense. It is lifestyle scene generation grounded by our uploaded item images.
- We should treat the output as illustrative marketing media, not as documentary evidence of true fit, scale, condition, or included accessories.

## 3. Current Repo Fit

The repo already has the right foundations:

- `Reseller.Media.ProductImage` stores original and processed images.
- `Reseller.Media.generate_product_variants/2` already creates a `background_removed` variant, and older products may still carry legacy `white_background` variants.
- `Reseller.Workers.AIProductProcessor` already orchestrates the product AI pipeline.
- `Reseller.Workers.ProductProcessingRun` already records pipeline status and payloads.
- `Reseller.AI.Providers.Gemini` already talks to Gemini through direct HTTP requests with `Req`.
- The web product review screen already shows pipeline progress and generated image variants.

That means this feature can be added as another AI/media generation step, not a new subsystem from scratch.

## 4. Product Requirements Translation

The user-facing requirement should be formalized as:

- once a product reaches the end of the current AI pipeline
- and once at least one cleaned or original hero image is available
- the backend may generate 2-3 optional lifestyle images
- those images should be tailored to the product type
- those images should be stored as additional `product_images`
- those images should never replace the original or cleaned product photos

## 5. Recommendation

### Default provider path

Use the Gemini Developer API first, behind the existing `Reseller.AI.Provider` behaviour.

Why:

- we already use Gemini directly over HTTPS with `Req`
- Gemini now supports native image generation and editing
- Gemini can accept text plus image inputs in one request
- we can keep one provider abstraction instead of introducing a second image-generation vendor immediately

### Default model path

Use `gemini-2.5-flash-image` first.

Reasoning:

- it is explicitly positioned for fast, contextual image generation and editing
- it is materially cheaper than the newer Gemini 3 image models
- this feature will likely multiply output volume because each product may request 2-3 new images

Inference from official docs:

- `gemini-2.5-flash-image` is the best first production candidate for reseller-scale throughput
- `gemini-3.1-flash-image-preview` and `gemini-3-pro-image-preview` should be treated as quality overrides, not the default path, until we validate cost and latency

## 6. Scene Strategy

We should not use one generic "make it look real" prompt for every item. We need category-aware scene planning.

### Apparel and accessories

Primary goal:

- show the clothing, shoes, bag, or accessory on a person or in a believable on-body context

Recommended output set:

- look 1: clean ecommerce-adjacent model shot
- look 2: casual lifestyle scene
- look 3: optional detail or alternate styling scene

Prompt rules:

- preserve color, silhouette, logos, and obvious construction details
- do not invent extra garments that cover the product
- do not claim an exact fit, size, or material beyond what the source images show
- keep faces generic and non-identifying

### Furniture and decor

Primary goal:

- place the item in a realistic interior that helps buyers understand scale and style

Recommended output set:

- look 1: clean hero room placement
- look 2: alternate room context
- look 3: optional closer styling scene

Prompt rules:

- preserve proportions and dominant materials
- keep surrounding furniture secondary
- avoid changing shape or dimensions
- keep room styling consistent with the product category

### Electronics

Primary goal:

- show the item in a believable everyday-use environment

Recommended output set:

- look 1: desk or home setup
- look 2: in-use context
- look 3: optional premium product-ad scene

Prompt rules:

- preserve ports, buttons, lens layout, screen borders, and brand marks when visible
- do not imply unsupported functionality
- do not fabricate included accessories unless clearly present

### Fallback product categories

For categories that do not fit the above:

- generate a clean contextual hero scene
- generate a second angle or use scenario
- optionally generate one premium editorial shot

## 7. Input Selection Strategy

Per lifestyle generation request, use at most 3 input images:

1. primary: `background_removed`
2. secondary fallback: one original image
3. legacy fallback: `white_background` only when older products already have it attached

Why:

- the official docs say `gemini-2.5-flash-image` works best with up to 3 input images
- cleaned images should help isolate the item
- one original photo can preserve texture, lighting clues, and hard-to-extract details

Request-size rules:

- use inline bytes only when total request size stays comfortably under 20MB
- for repeated reuse of the same source image bytes, or larger requests, use the Gemini Files API

## 8. Generation Strategy

Do not ask Gemini for 3 images in one opaque batch request in v1.

Instead:

- run 3 explicit generation requests
- each request uses the same source item inputs
- each request uses a distinct scene brief
- each output is stored and tracked independently

Benefits:

- better diversity between outputs
- easier retries
- easier partial success handling
- simpler cost accounting per generated image
- cleaner UI because each generated image maps to one scene profile

## 9. Data Model Recommendation

### Keep generated bytes in `product_images`

This matches current repo direction:

- processed outputs should remain additional `product_images`
- generated lifestyle images are supporting assets, not a new first-class inventory concept

### Add a dedicated run table

Recommended new table:

- `product_lifestyle_generation_runs`
  - `product_id`
  - `status`
  - `step`
  - `scene_family`
  - `model`
  - `prompt_version`
  - `requested_count`
  - `completed_count`
  - `error_code`
  - `error_message`
  - `payload`
  - `started_at`
  - `finished_at`

Recommended `product_images` additions:

- new `kind` values such as `lifestyle_generated`
- nullable metadata that identifies:
  - source run id
  - scene key
  - variant index
  - source image ids

If we want to keep `product_images` narrower, we can instead add:

- `product_lifestyle_generation_images`
  - `run_id`
  - `product_image_id`
  - `scene_key`
  - `variant_index`
  - `prompt_excerpt`

Recommended direction:

- v1 should add a separate run table
- store the actual generated files as `product_images`
- keep image-generation metadata off the core `products` table

## 10. Worker Flow Recommendation

Add this as the 8th and last optional step in `Reseller.Workers.AIProductProcessor`.

Recommended order:

1. uploads finalize
2. recognition
3. description draft
4. price research
5. marketplace texts
6. cleaned variants (`background_removed`)
7. mark image states ready
8. lifestyle image generation

Important behavior:

- lifestyle generation failure must not make the whole product unusable
- treat it like a warning or partial failure, similar to the current image-variant failure handling
- the product should already be usable by step 7, and should still remain `review` or `ready` even if the final generated lifestyle scenes fail
- keep the step feature-flagged until seller review/regeneration controls are shipped

Recommended run steps:

- `lifestyle_generating`
- `lifestyle_generated`
- `lifestyle_partial`
- `lifestyle_failed`

## 11. Provider and Module Shape

Recommended modules:

- `Reseller.AI.ScenePlanner`
  - maps product category and AI signals into a `scene_family`

- `Reseller.AI.LifestylePromptBuilder`
  - builds 2-3 scene-specific prompts from product facts

- `Reseller.AI.GeneratedImage`
  - normalizes Gemini image response parts into a storage-friendly internal shape

- `Reseller.Workers.LifestyleImageGenerator`
  - optional helper called by `AIProductProcessor`

Recommended provider callback addition:

- `generate_lifestyle_image(attrs, images, opts)`

`attrs` should include:

- product title, brand, category, condition, color, material
- AI summary
- chosen scene family
- one scene brief
- prompt version
- negative rules

`images` should include:

- selected cleaned image bytes or Gemini File references
- optional original image detail shot

## 12. Prompt Contract

The prompt should be grounded and conservative.

Required instructions:

- keep the uploaded item as the main subject
- preserve visible color, silhouette, logos, and distinctive details
- do not add visible text overlays, watermarks, labels, or price tags
- do not invent included accessories unless visible in the source image
- do not exaggerate condition or material quality
- produce a realistic lifestyle scene appropriate for the product type

Category-specific instructions:

- apparel: place on a generic person or model in a believable outfit context
- furniture: place in a realistic room matching the item type
- electronics: place in a believable real-use environment

Recommended output config:

- default aspect ratio: `4:5`
- default image size: `1K`
- default response modality in production: `IMAGE`
- optional response modality in staging/debug: `TEXT` + `IMAGE`

## 13. UI and API Recommendation

### Web

On the product detail page:

- add a "Lifestyle images" panel
- show generation status separately from raw upload variants
- clearly label every output as `AI-generated lifestyle preview`
- allow regenerate, delete, and favorite/approve actions

### API

Recommended endpoints:

- `POST /api/v1/products/:id/generate_lifestyle_images`
- `GET /api/v1/products/:id/lifestyle_generation_runs`
- `DELETE /api/v1/products/:id/generated_images/:image_id`

Recommended web controls:

- `Generate lifestyle images`
- `Regenerate all`
- `Regenerate one scene`
- `Delete generated image`

## 14. Cost and Limit Guidance

Official pricing currently indicates:

- `gemini-2.5-flash-image` paid output pricing is approximately `$0.039` per generated image up to `1024x1024`
- `gemini-3.1-flash-image-preview` is materially more expensive at roughly `$0.067` per `1K` image

Planning implication:

- generating 3 lifestyle images per product with `gemini-2.5-flash-image` is roughly `$0.117` in image output cost before additional input token costs
- the same 3-image set on `gemini-3.1-flash-image-preview` is roughly `$0.201` in image output cost before input costs

So v1 should include:

- per-user monthly generation limits
- optional seller opt-in
- regenerate limits
- admin observability on generated-image cost and volume

## 15. Safety, Honesty, and Marketplace Risk

This feature must be opinionated about disclosure.

Required product rules:

- AI-generated lifestyle images must never replace original seller photos
- original and cleaned images must remain the primary truth source
- generated lifestyle images must be labeled as illustrative
- generated scenes must not be used as evidence of exact fit, size, scale, or included accessories

Operational rule:

- treat marketplace-policy compliance as a separate review concern because platform rules can change quickly
- do not auto-publish AI-generated lifestyle images to external marketplaces until those policies are checked and the seller explicitly opts in

## 16. Rollout Plan

### Phase 1

- add provider support for Gemini image generation
- add one category-agnostic generation path
- store generated outputs as `product_images`
- surface them in the web UI with clear labeling

### Phase 2

- add category-aware scene planner
- add 2-3 distinct scene templates per family
- add regenerate/delete controls

### Phase 3

- add run table and admin observability
- add per-user quotas and premium model fallback
- add A/B evaluation on source-image strategy and prompt variants

## 17. Testing Plan

Add tests for:

- Gemini request building for image generation with text + image inputs
- inline image and Files API request paths
- category-to-scene-family mapping
- prompt generation and negative-rule inclusion
- partial success when 1 or 2 of 3 generated images fail
- product remains usable when lifestyle generation fails
- generated outputs persist as additional `product_images`
- seller-facing web review and regenerate flows

## 18. Open Questions

- Do we want one shared `lifestyle_generated` image kind, or multiple kinds per scene family?
- Do we want to keep generation metadata in a dedicated run table from day one, or allow a smaller v1 that stores more metadata inside run payloads?
- Do we want apparel images to default to full-person scenes, or a safer torso / faceless framing to reduce bad outputs and identity issues?
- Do we want to auto-run this step for every eligible product, or gate it behind an explicit seller action?

## 19. Sources

Official sources used for this plan:

- Gemini image generation docs: https://ai.google.dev/gemini-api/docs/image-generation
- Gemini image understanding docs: https://ai.google.dev/gemini-api/docs/image-understanding
- Gemini models docs: https://ai.google.dev/gemini-api/docs/models
- Gemini pricing docs: https://ai.google.dev/gemini-api/docs/pricing
- Gemini OpenAI compatibility docs: https://ai.google.dev/gemini-api/docs/openai

Relevant current details verified from those pages:

- the image-generation page was last updated `2026-03-25 UTC`
- Gemini docs currently state that `gemini-2.5-flash-image` works best with up to 3 input images
- Gemini docs currently state that all generated images include a SynthID watermark
- Gemini pricing currently lists `gemini-2.5-flash-image` output at about `$0.039` per `1024x1024` image on the paid tier
