# Marketplace Copy Rules

This file is the compressed marketplace guidance set used to reason about generated listing copy.

## Global Rules

- keep copy factual and product-specific
- do not invent condition, measurements, authenticity, provenance, or warranty claims
- do not use irrelevant competitor brands or search-stuffing text
- do not direct buyers off-platform unless the marketplace explicitly requires it
- store `generated_tags` as neutral keywords; only render literal hashtags where the marketplace clearly supports them

## Marketplace Matrix

| Marketplace | Model | Copy Guidance | Operational Note |
| --- | --- | --- | --- |
| eBay | seller-managed | compact factual titles; structured specifics matter | avoid keyword stuffing and IP misuse |
| Depop | seller-managed | fashion-forward tone is fine, but stay truthful | relevant hashtags only |
| Poshmark | seller-managed | search-rich titles and descriptions | prioritize brand, style, condition, measurements |
| Mercari | seller-managed | concise mobile-first copy | avoid unrelated brands and hashtags |
| Facebook Marketplace | peer-to-peer | plain local-sale copy | keep communication on-platform |
| OfferUp | peer-to-peer | clear local-sale copy | no URLs, contact info, or stock photos |
| Whatnot | seller-managed/live | item-specific titles and condition notes | no clickbait or irrelevant keywords |
| Grailed | seller-managed | concise menswear/designer copy | measurements and exact condition matter |
| The RealReal | managed consignment | treat generated output as intake notes | not a normal self-serve listing channel |
| Vestiaire Collective | seller-managed + review | luxury-specific, condition-aware copy | catalog/auth checks may reject items |
| thredUp | managed consignment | treat generated output as intake notes | platform controls acceptance and listing |
| Etsy | seller-managed | structured tags, not inline hashtags | handmade/vintage/craft-supply eligibility matters |

## Implementation Guidance

- `therealreal` and `thredup` should be treated as intake-routing targets, not standard public-copy targets
- `etsy` tags should map to Etsy tag fields, not be rendered as inline hashtags
- plain-text marketplaces should default to no hashtag decoration
- keep final title and description limits runtime-driven by the seller UI when public docs are incomplete

## Source of Truth

- supported marketplace ids: `lib/reseller/marketplaces.ex`
- generated listing persistence: `lib/reseller/marketplaces/marketplace_listing.ex`
- API exposure: `lib/reseller_web/controllers/api/v1/product_controller.ex`
