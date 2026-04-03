# AI Status

## Shipped

- Gemini provider integration
- recognition pipeline
- product normalization
- description draft generation
- price research generation
- marketplace listing generation
- optional lifestyle image generation entry points

## Key Modules

- `Reseller.AI`
- `Reseller.AI.Provider`
- `Reseller.AI.RecognitionPipeline`
- `Reseller.AI.Normalizer`
- `Reseller.AI.ScenePlanner`
- `Reseller.AI.LifestylePromptBuilder`
- `Reseller.Workers.AIProductProcessor`
- `Reseller.Workers.LifestyleImageGenerator`

## Still Worth Improving

- richer admin observability for per-model cost and failures
- explicit retry UX for failed runs
- clearer rollout controls around optional lifestyle generation
