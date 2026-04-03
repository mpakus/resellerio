# Lifestyle Image Generation Status

## Shipped

- `product_lifestyle_generation_runs`
- generated images stored as `product_images`
- category-aware scene planning
- prompt building
- API endpoints for generate/list/approve/delete
- workspace support for review and reruns

## Key Modules

- `Reseller.AI.ScenePlanner`
- `Reseller.AI.LifestylePromptBuilder`
- `Reseller.AI.GeneratedImage`
- `Reseller.Workers.LifestyleImageGenerator`

## Current Constraints

- feature is optional and gated by `Reseller.AI.lifestyle_generation_enabled?/1`
- outputs remain seller-reviewable before storefront use
- storefront fallback logic only shows approved ready images publicly

## Remaining Improvements

- tighter admin reporting for generation volume and cost
- clearer product decision on quotas during trial/free states
