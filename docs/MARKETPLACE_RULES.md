# Marketplace Rules for Resellers — Complete Guide

> **12 marketplaces · Platform rules · Lifehacks · AI prompts for description generation**
> Last updated: March 2026

---

## Table of Contents

- [1. Overview & Comparison](#1-overview--comparison)
  - [1.1 Marketplace Comparison Table](#11-marketplace-comparison-table)
  - [1.2 Platform Selection Guide](#12-platform-selection-guide)
  - [1.3 Universal Product Data Schema](#13-universal-product-data-schema)
  - [1.4 API Integration Pattern](#14-api-integration-pattern)
  - [1.5 Universal Cross-Platform AI Prompt](#15-universal-cross-platform-ai-prompt)
- [2. eBay](#2-ebay)
  - [2.1 Platform Overview](#21-platform-overview)
  - [2.2 Listing Rules & Requirements](#22-listing-rules--requirements)
  - [2.3 Seller Performance Standards](#23-seller-performance-standards)
  - [2.4 Lifehacks & Best Practices](#24-lifehacks--best-practices)
  - [2.5 AI Prompts](#25-ai-prompts)
- [3. Depop](#3-depop)
  - [3.1 Platform Overview](#31-platform-overview)
  - [3.2 Listing Rules & Requirements](#32-listing-rules--requirements)
  - [3.3 Seller Performance & Top Seller Status](#33-seller-performance--top-seller-status)
  - [3.4 Lifehacks & Best Practices](#34-lifehacks--best-practices)
  - [3.5 AI Prompts](#35-ai-prompts)
- [4. Poshmark](#4-poshmark)
  - [4.1 Platform Overview](#41-platform-overview)
  - [4.2 Listing Rules & Requirements](#42-listing-rules--requirements)
  - [4.3 Seller Performance](#43-seller-performance)
  - [4.4 Lifehacks & Best Practices](#44-lifehacks--best-practices)
  - [4.5 AI Prompts](#45-ai-prompts)
- [5. Mercari](#5-mercari)
  - [5.1 Platform Overview](#51-platform-overview)
  - [5.2 Listing Rules & Requirements](#52-listing-rules--requirements)
  - [5.3 Lifehacks & Best Practices](#53-lifehacks--best-practices)
  - [5.4 AI Prompts](#54-ai-prompts)
- [6. Facebook Marketplace](#6-facebook-marketplace)
  - [6.1 Platform Overview](#61-platform-overview)
  - [6.2 Listing Rules & Requirements](#62-listing-rules--requirements)
  - [6.3 Lifehacks & Best Practices](#63-lifehacks--best-practices)
  - [6.4 AI Prompts](#64-ai-prompts)
- [7. OfferUp](#7-offerup)
  - [7.1 Platform Overview](#71-platform-overview)
  - [7.2 Listing Rules & Requirements](#72-listing-rules--requirements)
  - [7.3 Lifehacks & Best Practices](#73-lifehacks--best-practices)
  - [7.4 AI Prompts](#74-ai-prompts)
- [8. Whatnot](#8-whatnot)
  - [8.1 Platform Overview](#81-platform-overview)
  - [8.2 Listing Rules & Requirements](#82-listing-rules--requirements)
  - [8.3 Lifehacks & Best Practices](#83-lifehacks--best-practices)
  - [8.4 AI Prompts](#84-ai-prompts)
- [9. Grailed](#9-grailed)
  - [9.1 Platform Overview](#91-platform-overview)
  - [9.2 Listing Rules & Requirements](#92-listing-rules--requirements)
  - [9.3 Bumping & Visibility](#93-bumping--visibility)
  - [9.4 Lifehacks & Best Practices](#94-lifehacks--best-practices)
  - [9.5 AI Prompts](#95-ai-prompts)
- [10. The RealReal](#10-the-realreal)
  - [10.1 Platform Overview](#101-platform-overview)
  - [10.2 How It Works (Consignment Model)](#102-how-it-works-consignment-model)
  - [10.3 Listing Rules & Requirements](#103-listing-rules--requirements)
  - [10.4 Lifehacks & Best Practices](#104-lifehacks--best-practices)
  - [10.5 AI Prompts](#105-ai-prompts)
- [11. Vestiaire Collective](#11-vestiaire-collective)
  - [11.1 Platform Overview](#111-platform-overview)
  - [11.2 Listing Rules & Requirements](#112-listing-rules--requirements)
  - [11.3 Lifehacks & Best Practices](#113-lifehacks--best-practices)
  - [11.4 AI Prompts](#114-ai-prompts)
- [12. thredUp](#12-thredup)
  - [12.1 Platform Overview](#121-platform-overview)
  - [12.2 How It Works (Consignment Model)](#122-how-it-works-consignment-model)
  - [12.3 Listing Rules & Requirements](#123-listing-rules--requirements)
  - [12.4 Lifehacks & Best Practices](#124-lifehacks--best-practices)
  - [12.5 AI Prompts](#125-ai-prompts)
- [13. Etsy](#13-etsy)
  - [13.1 Platform Overview](#131-platform-overview)
  - [13.2 Listing Rules & Requirements](#132-listing-rules--requirements)
  - [13.3 Etsy Search (SEO) — 2025 Updates](#133-etsy-search-seo--2025-updates)
  - [13.4 Lifehacks & Best Practices](#134-lifehacks--best-practices)
  - [13.5 AI Prompts](#135-ai-prompts)

---

# 1. Overview & Comparison

## 1.1 Marketplace Comparison Table

| ID | Label | Model | Fee Range | Best For |
|----|-------|-------|-----------|----------|
| `ebay` | eBay | Self-managed | ~13% | Everything — broadest reach, auction + fixed |
| `depop` | Depop | Self-managed | 0% + 3.3% processing (US/UK) | Gen Z fashion, vintage, streetwear |
| `poshmark` | Poshmark | Self-managed | 20% (or $2.95 < $15) | Women's fashion, branded items |
| `mercari` | Mercari | Self-managed | 10% + 2.9% + $0.30 | General resale, electronics, home goods |
| `facebook_marketplace` | Facebook Marketplace | Self-managed | Free local / 5% shipped | Local sales, furniture, bulky items |
| `offerup` | OfferUp | Self-managed | Free (optional buyer protection) | Local sales, casual selling |
| `whatnot` | Whatnot | Self-managed (live) | ~11% | Live selling, sneakers, trading cards, luxury |
| `grailed` | Grailed | Self-managed | ~12% | Men's streetwear, designer, archive fashion |
| `therealreal` | The RealReal | Full-service consignment | 30–60% commission | Luxury consignment, hands-off selling |
| `vestiaire_collective` | Vestiaire Collective | Seller-managed + auth | 12% + 3% processing | Luxury fashion, authenticated designer |
| `thredup` | thredUp | Full-service consignment | 3–80% (varies by price) | Volume decluttering, mainstream brands |
| `etsy` | Etsy | Self-managed | ~10% | Handmade, vintage (20+ yr), craft supplies |

## 1.2 Platform Selection Guide

```
Is the item luxury/designer ($500+)?
├── YES → The RealReal, Vestiaire Collective, Grailed (if menswear), eBay, Whatnot
├── MAYBE ($100-$500 designer) → Poshmark, eBay, Grailed, Vestiaire, Depop
└── NO (mainstream/casual)
    ├── Is it clothing/fashion?
    │   ├── Men's streetwear/designer → Grailed, eBay, Depop, Whatnot
    │   ├── Women's fashion → Poshmark, Depop, Mercari, eBay
    │   ├── Vintage (20+ years) → Etsy, eBay, Depop, Grailed
    │   └── Budget/fast fashion → Mercari, Depop, FB Marketplace
    ├── Is it bulky/heavy?
    │   └── YES → FB Marketplace, OfferUp (local), eBay (shipped)
    ├── Is it electronics/home goods?
    │   └── YES → Mercari, eBay, FB Marketplace, OfferUp
    ├── Is it handmade/craft?
    │   └── YES → Etsy (primary), eBay
    └── General items
        └── Mercari, eBay, FB Marketplace, OfferUp
```

**Volume Decluttering?** If you have large volumes of mainstream-brand clothing and don't want to manage individual listings: **thredUp** — send a bag, they do everything (but margins are low on items under $50). Better margins: batch-list on Poshmark or Mercari with AI-generated descriptions.

## 1.3 Universal Product Data Schema

Collect this data for each item, then feed it into marketplace-specific AI prompts:

```json
{
  "brand": "Nike",
  "item_type": "Sneakers",
  "model": "Air Max 90",
  "color": "White/Black",
  "size": "Men's US 9",
  "material": "Leather/Mesh",
  "condition": "Used - Excellent",
  "condition_details": "Worn 3 times, no visible wear on uppers, minimal sole wear",
  "flaws": "Light creasing on left toe box",
  "measurements": {
    "insole_length": "10.5 inches"
  },
  "retail_price": "$130",
  "purchase_year": 2024,
  "included": ["Original box", "Extra laces"],
  "photos": ["front.jpg", "back.jpg", "sole.jpg", "flaw_detail.jpg", "box.jpg"],
  "category": "Footwear",
  "era": null,
  "tags": ["athletic", "streetwear", "running"]
}
```

## 1.4 API Integration Pattern

```elixir
# For each marketplace the seller uses:
for marketplace <- seller.marketplaces do
  # Load the rules section for this marketplace from this file (or split sections)
  rules = load_marketplace_rules(marketplace.id)

  prompt = extract_prompt(rules, :universal)
  |> String.replace("{product_data}", Jason.encode!(product_data))

  system_message = """
  You are a product listing expert. Follow the rules and format specified exactly.
  Context: #{rules}
  """

  {:ok, response} = AI.generate(%{
    system: system_message,
    user: prompt,
    model: "claude-sonnet-4-20250514"
  })

  save_listing(marketplace.id, response)
end
```

## 1.5 Universal Cross-Platform AI Prompt

Use this prompt when you want ONE AI call to generate descriptions for ALL marketplaces simultaneously:

```
You are a multi-platform resale listing expert. Given product data and a list of target
marketplaces, generate an optimized listing (title + description) for EACH marketplace,
following the specific rules, tone, and format for each platform.

## TARGET MARKETPLACES:
{marketplace_list}

## MARKETPLACE RULES:
{loaded_rules_for_each_marketplace}

## PRODUCT DATA:
{product_data}

## INSTRUCTIONS:
For EACH marketplace in the target list:
1. Generate a platform-optimized TITLE following that platform's character limits and style
2. Generate a platform-optimized DESCRIPTION following that platform's tone, structure, and rules
3. Include platform-specific extras (hashtags for Depop/Mercari, tags for Etsy/Grailed,
   item specifics for eBay)
4. Flag any marketplace where this item may NOT be appropriate (e.g., fast fashion on
   Vestiaire, non-vintage on Etsy, non-menswear on Grailed)

## OUTPUT FORMAT:
For each marketplace, output:

### [MARKETPLACE_LABEL]
**TITLE:** ...
**DESCRIPTION:** ...
**EXTRAS:** (tags, hashtags, item specifics as applicable)
**COMPATIBILITY NOTE:** (any warnings about platform fit)

---
(repeat for each marketplace)
```

---
---

# 2. eBay

## 2.1 Platform Overview
- **ID:** `ebay`
- **Audience:** Broadest marketplace — all ages, all categories, global reach
- **Fees:** ~13% total (final value fee varies by category + payment processing)
- **Listing formats:** Fixed price & auction
- **Description tone:** Professional, detailed, trust-building
- **Character limits:** Title: 80 characters | Description: unlimited (but concise wins)

## 2.2 Listing Rules & Requirements

### Mandatory
- Use your OWN photos (no stock photos unless from eBay catalog)
- Accurate item condition using eBay's grading scale (New, Like New, Very Good, Good, Acceptable)
- Accurate item location disclosed
- No keyword stuffing or search manipulation (unrelated keywords = policy violation)
- One fixed-price listing per identical item (no duplicate listings)
- No links to external sites
- No JavaScript or active content in listings
- No third-party endorsement logos
- Ship within stated handling time
- Signature confirmation required for orders $750+
- Tracking/delivery confirmation on all shipments

### Prohibited
- Counterfeit items (zero tolerance — VeRO program enforced)
- Shill bidding (artificially inflating prices)
- Fee avoidance schemes
- Off-platform transaction solicitation
- Pre-sale items without meeting strict requirements

## 2.3 Seller Performance Standards
- Transaction defect rate: < 2%
- Cases closed without resolution: < 0.3% of transactions
- Late shipment rate must stay minimal
- **Top Rated Seller:** 1-business-day handling + 30-day free returns = 10% FVF discount + Top Rated Plus badge

## 2.4 Lifehacks & Best Practices

1. **Use all 24 photo slots** — front, back, tags, flaws, measurements, packaging
2. **Fill every item specific** — eBay search heavily indexes item specifics (brand, size, color, material, style)
3. **Price with "Best Offer" enabled** — increases conversion 15-30%
4. **Promote listings at 2-5%** — Promoted Listings Standard has strong ROI on competitive items
5. **Offer free shipping** — automatic 5-star shipping rating + search boost
6. **Use eBay's Terapeak** for sold comp research before pricing
7. **Relist stale items** every 30 days to refresh search position
8. **Set up business policies** (shipping, returns, payment) for faster listing
9. **Accept 30-day returns** — massive search visibility boost
10. **Ship same day** — improves seller metrics and wins Buy It Now placement

## 2.5 AI Prompts

### Universal Product Description Generator

```
You are an expert eBay listing copywriter. Generate a professional eBay product listing
based on the product data provided.

## RULES:
- Title: Maximum 80 characters. Front-load with brand, key attribute, and item type.
  Include size/color if space allows. No ALL CAPS words. No special characters or emojis.
- Description structure:
  1. Opening hook (1 sentence — what the item IS and why it's desirable)
  2. Condition details (honest, specific — mention any flaws with measurements)
  3. Key features & specifications (bullet points OK here)
  4. Measurements (flat lay, in inches — pit to pit, length, sleeve, inseam as applicable)
  5. Shipping & handling note
  6. Call to action (brief — "Add to cart" or "Make an offer")
- Tone: Professional, trustworthy, factual. No hype words ("amazing", "must-have").
  No subjective claims ("best quality").
- SEO: Naturally incorporate searchable terms (brand, model, color, size, material,
  style, era/year if vintage).
- Disclose ALL flaws — hidden flaws cause returns and defects.
- Do NOT use: HTML formatting, links, contact info, or references to other platforms.

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**TITLE:** [80 chars max]

**DESCRIPTION:**
[Generated description following the structure above]

**SUGGESTED ITEM SPECIFICS:**
- Brand:
- Size:
- Color:
- Material:
- Style:
- Condition:
```

### Auction Style Variation

```
You are writing an eBay auction listing that creates urgency and buyer excitement.

## RULES:
- Title: 80 characters max, front-load brand + item type + key detail
- Description: Start with what makes this item special or rare. Include condition,
  measurements, and flaws. End with "Don't miss this — bid now!"
- Tone: Enthusiastic but honest. Build excitement without exaggeration.
- Include a brief authenticity statement if branded/designer item.

## PRODUCT DATA:
{product_data}

Generate the listing title and description.
```

---
---

# 3. Depop

## 3.1 Platform Overview
- **ID:** `depop`
- **Audience:** Gen Z and young millennials (18–35), fashion-forward, sustainability-minded
- **Fees:** 0% marketplace fee (US/UK, as of mid-2024) + 3.3% + $0.45 payment processing (Stripe)
- **Boost fee:** 8% (US/AU) or 12% (UK) if item sells via boosted tile (28-day attribution window)
- **Listing format:** Fixed price only
- **Description tone:** Casual, conversational, aesthetic-driven — "like texting a friend"
- **Photo slots:** 4 per listing (some reports of 8)
- **Hashtags:** 5–10 relevant hashtags at end of description

## 3.2 Listing Rules & Requirements

### Mandatory
- Honest descriptions and photos for every listing
- Use Depop Payments (or PayPal outside US/UK) — no off-platform transactions
- Accurate brand names only
- Ship items promptly (Top Sellers ship within 3 days)
- Respond to messages within 24 hours ideally
- All items must comply with Terms of Service and Community Guidelines
- Minimum age: 13 to use, 18 to sell

### Prohibited
- Counterfeit/fake goods (immediate removal)
- Weapons, drugs, illegal items
- Hateful, threatening, or abusive language
- Body shaming or sexual advances
- Sharing others' personal details
- Off-platform deals to avoid fees
- Keyword stuffing with irrelevant brand names
- Used/open electronics or appliances (must be new & sealed)
- Stock photos

### Cross-listing
- Depop explicitly acknowledges sellers may use third-party crosslisting platforms
- Sellers are responsible for maintaining accurate inventory across platforms

## 3.3 Seller Performance & Top Seller Status
- **Sales threshold:** $1,000/month for 4 consecutive months (US)
- **Rating:** Maintain 4.5+ star average
- **Shipping:** 90%+ orders shipped within 5 days (best practice: 3 days)
- **Refund rate:** Below 5%
- **Compliance:** Full adherence to Terms of Service & Community Guidelines
- **Benefits:** Verified badge, higher search ranking, promotional opportunities, priority support

## 3.4 Lifehacks & Best Practices

1. **Photos ARE content** — Depop is Instagram-for-shopping. Styled shots on models/mannequins outperform flat lays
2. **Consistent aesthetic feed** — similar backgrounds and lighting across your shop
3. **Use natural light** — shoot near windows during golden hour
4. **Write like you're texting** — casual, personality-driven descriptions ("insane vintage find" not "pre-owned garment")
5. **Include measurements** — flat lay with measuring tape photo
6. **Use all photo slots** — front, back, details, flaws, tags
7. **Use Photoroom** through Depop for background removal (available since June 2025)
8. **Hashtags matter** — 5-10 relevant aesthetic + item type tags (#y2k #vintage #streetwear #cottagecore)
9. **Never keyword stuff** — listing "Nike Adidas Zara vintage" tanks trust and violates rules
10. **Refresh old listings** — edit and save to migrate to 0% fee tier
11. **Post seasonally ahead** — swimsuits in January, puffers in August
12. **List 1-2 items daily** — algorithm favors active sellers
13. **Send offers to likers** — 24-hour window creates urgency
14. **Use Depop's Boost sparingly** — 8% fee only worth it for high-margin items
15. **Bulk listing tool** (since June 2025) — CSV upload for larger inventories

## 3.5 AI Prompts

### Universal Product Description Generator

```
You are a Depop listing copywriter. Write casual, Gen Z-friendly product descriptions
that feel like a text to a friend about something cool you found.

## RULES:
- Tone: Conversational, enthusiastic, authentic. Use lowercase naturally.
  Slight slang OK ("goes hard", "fire", "insane find"). NO corporate language.
- Structure:
  1. Opening hook — what it IS and why it's cool (1-2 sentences, personality-driven)
  2. Key details — brand, era/decade, colorway, fit description
  3. Condition — honest, casual ("tiny mark on sleeve, barely noticeable when worn")
  4. Measurements — pit to pit, length, and any relevant flat-lay measurements in inches
  5. Shipping/bundle note (optional — "free shipping on bundles of 2+")
  6. Hashtags — 5-10 relevant tags at the end
- Do NOT use: formal language, bullet points, ALL CAPS, emojis excessively,
  or irrelevant brand names as hashtags
- Aesthetic keywords to weave in when relevant: vintage, y2k, cottagecore, streetwear,
  gorpcore, dark academia, minimalist, oversized
- Be honest about flaws — Depop buyers appreciate transparency

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**DESCRIPTION:**
[Casual, conversational description following the structure above]

[hashtags line: #tag1 #tag2 #tag3 ...]
```

### Trendy/Hype Item Variation

```
You are writing a Depop listing for a hyped or trending item. Create urgency and
desirability while staying authentic.

## RULES:
- Lead with the trend/aesthetic this fits ("if you're into gorpcore, this is THE jacket")
- Mention rarity or era if applicable
- Include fit details — Depop buyers care about how it looks ON, not just specs
- Stay casual but confident
- End with hashtags (5-10 relevant aesthetic + item type tags)

## PRODUCT DATA:
{product_data}

Generate the description with hashtags.
```

---
---

# 4. Poshmark

## 4.1 Platform Overview
- **ID:** `poshmark`
- **Audience:** Fashion-conscious women (primarily), men, kids — ages 25–45, US/Canada/Australia/India
- **Fees:** Flat $2.95 on sales under $15 | 20% commission on sales $15+
- **Shipping:** Flat $6.49 for up to 5 lbs (USPS Ground), buyer pays
- **Listing format:** Fixed price with offer/negotiation system
- **Description tone:** Friendly, descriptive, brand-focused
- **Social features:** Sharing, following, Posh Parties, Posh Shows (live selling)

## 4.2 Listing Rules & Requirements

### Mandatory
- Clear photos and accurate descriptions
- Authentic items only (zero tolerance for counterfeits)
- All transactions must stay on-platform (no off-site deals)
- Items must be clean and in sellable condition
- Accurate brand, size, color, and condition information
- Cannot create listings for donations, services, or financial solicitation

### Prohibited
- Counterfeit/replica items
- Damaged or unsafe items (heavily stained, worn, hazardous)
- Off-platform transactions or price negotiation outside Poshmark
- Excessive listing removal/relisting within 60 days (new 2025 policy)
- Mass listing removals (manual or automated) — can result in 6-day suspension
- Listings for non-tangible items (services, donations, tips)

### Excessive Listing Removal Policy (2025)
- Cannot repeatedly remove and relist same items within 60 days
- Refreshing listings after 60+ days IS encouraged
- When cross-listed items sell elsewhere, space out deletions — avoid bulk removal
- Violation = 6-day suspension; severe cases = permanent limitations

## 4.3 Seller Performance
- **Posh Ambassador:** Earn through community engagement, sharing, sales volume
- **Average Ship Time** tracked and displayed — ship fast (same/next day ideal)
- **5-star ratings** driven by accurate descriptions and fast shipping
- **Combined Orders:** Can combine multiple purchases from same buyer within 24 hours

## 4.4 Lifehacks & Best Practices

1. **Share your closet daily** — Poshmark's algorithm rewards active closets (3-5 shares per item/day)
2. **Relist stale items every 30-60 days** — moves items back to top of search
3. **Use "Offer to Likers"** — send targeted discounts to people who liked your item
4. **Price Drop strategy** — drop price 10%+ to trigger "Price Drop" notification to likers
5. **List during peak hours** — evenings and weekends see most buyer activity
6. **Join Posh Parties** — submit relevant items to themed events for extra exposure
7. **Bundle discounts** — encourage larger orders with volume pricing
8. **Use Smart List AI** — Poshmark's built-in tool to enhance listing quality
9. **Offer shipping discounts** — absorb part of shipping cost to close sales
10. **Cross-list strategically** — tweak titles per platform, space out deletions on Poshmark
11. **Use all photo slots** — cover photo should be styled/attractive; include tags, measurements, flaws
12. **Write keyword-rich titles** — Brand + Item Type + Key Details (color, size, style)
13. **Posh Shows (live selling)** — host real-time shows for higher sell-through rates
14. **Clear, neutral backgrounds** — Poshmark buyers expect clean, professional photos
15. **Respond fast to comments and offers** — algorithm rewards responsiveness

## 4.5 AI Prompts

### Universal Product Description Generator

```
You are a Poshmark listing copywriter. Write friendly, detailed product descriptions
that build buyer confidence and include SEO keywords.

## RULES:
- Title: Include Brand + Item Type + Key Details (color, size, style).
  Example: "Lululemon Align High-Rise Leggings Black Size 6"
- Description structure:
  1. Greeting/hook (1 sentence — warm, inviting)
  2. Item description (what it is, brand, style name/number if applicable)
  3. Condition details (NWT, NWOT, EUC, GUC — explain any wear)
  4. Key features (fabric, stretch, pockets, special details)
  5. Measurements (flat lay in inches)
  6. Styling suggestion (optional — "Pairs great with..." or "Perfect for...")
  7. Bundle/offer note ("Bundle 2+ items for a discount!" or "Open to reasonable offers!")
- Tone: Warm, friendly, helpful — like a personal shopper giving advice
- Use Poshmark condition abbreviations: NWT (New With Tags), NWOT (New Without Tags),
  EUC (Excellent Used Condition), GUC (Good Used Condition)
- Include brand name, size, color, and material in both title and description
- Disclose ALL flaws with measurements ("small pull near hem, approx 0.5 inches")
- Do NOT use: links, contact info, references to other platforms, excessive emojis

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**TITLE:** [Brand + Item Type + Key Details]

**DESCRIPTION:**
[Generated description following the structure above]

**SUGGESTED TAGS:** [brand], [item type], [color], [style], [occasion]
```

### Posh Party / Trending Item Variation

```
You are writing a Poshmark listing optimized for Posh Party visibility and trending searches.

## RULES:
- Title: Front-load trending brand + current season relevance
- Description: Start with why this item is trending NOW (aesthetic, season, celebrity style)
- Include all standard details (condition, measurements, flaws)
- End with engagement driver ("Like this listing to be notified of price drops!")
- Reference relevant Posh Party themes if applicable

## PRODUCT DATA:
{product_data}

Generate the listing title and description.
```

---
---

# 5. Mercari

## 5.1 Platform Overview
- **ID:** `mercari`
- **Audience:** Broad US marketplace, casual sellers and resellers, ages 25–45
- **Fees:** 10% selling fee + 2.9% + $0.30 payment processing (as of Jan 2025)
- **Listing format:** Fixed price with offer/negotiation system + Smart Pricing auto-reduction
- **Shipping:** Prepaid labels (USPS, UPS, FedEx) or ship on your own
- **Description tone:** Clear, honest, keyword-rich but natural
- **Photo slots:** Up to 12 per listing
- **Hashtags:** 3 per listing maximum

## 5.2 Listing Rules & Requirements

### Mandatory
- Accurate descriptions and honest condition disclosure
- Only list items you intend to sell at the price listed
- Negotiate in good faith
- All communication and transactions must stay on-platform
- Ship within 3 business days of sale
- All items must be legal to sell and legal to ship
- Only list items you own

### Prohibited
- Counterfeit, stolen, or illegal items
- Weapons, alcohol, hazardous materials
- Off-platform transactions or meetups (except Mercari Meetup Beta in eligible areas)
- Trades or partial trades
- Hateful, violent, racist, or discriminatory content
- Keyword stuffing with irrelevant terms

### Return Policy
- Buyers have a 3-day return window if item doesn't match description
- Accurate descriptions protect sellers from returns

### Seller Payments
- Payment released after buyer rates transaction OR 3 days after confirmed delivery
- **Direct Deposit:** Free (5-7 business days)
- **Instant Pay:** $3 fee (30 minutes to debit card)
- Failed deposit fee: $2

## 5.3 Lifehacks & Best Practices

1. **Use all 12 photo slots** — first photo is thumbnail, make it count
2. **Natural light photography** — ring light or window light, plain backgrounds
3. **Keyword-rich titles** — Brand + Model + Color + Size + Condition (e.g., "Nike Air Max 90 Men's Size 9 White")
4. **3 strategic hashtags** — complement title, don't repeat (#athletic #streetwear #vintage)
5. **Enable Smart Pricing** — auto-reduces price over time with a floor you set
6. **Research sold listings** — price competitively based on actual sold comps
7. **Price 10-15% higher** than target to leave negotiation room
8. **Respond quickly** — Mercari rewards fast responders in search rankings
9. **Relist stale items** — old listings lose search position
10. **List during peak hours** — evenings and weekends for maximum eyeballs
11. **Offer free shipping** — build cost into item price for higher conversion
12. **Use lightest shipping tier** — weigh and measure before listing to avoid overpaying
13. **Bundle offers** — attract buyers looking for deals on multiple items
14. **Include measurements** — reduces returns, builds buyer confidence
15. **Cross-list to expand reach** — sync inventory to avoid overselling

## 5.4 AI Prompts

### Universal Product Description Generator

```
You are a Mercari listing copywriter. Write clear, buyer-friendly product descriptions
with strong keywords that help items appear in Mercari search.

## RULES:
- Title: Brand + Model/Style + Key Detail + Size + Condition keyword. Max ~80 characters.
  Example: "Nike Air Max 90 Men's Size 9 White - Excellent Condition"
- Description structure:
  1. What the item IS (1-2 sentences — brand, type, model, style)
  2. Condition (specific and honest: "Worn twice, no visible wear" or
     "Small scuff on left toe — see photo 4")
  3. Key details (material, color, dimensions/measurements, weight if relevant)
  4. What's included (original box, tags, accessories, etc.)
  5. Shipping note (how it will be packaged)
- Tone: Clear, honest, approachable. Not overly casual (like Depop) or overly formal
  (like eBay). Natural and buyer-friendly.
- Use descriptive terms like "new," "vintage," or "rare" ONLY when genuinely applicable
- Include brand, model, color, size, and material naturally in text
- Disclose all flaws with specific details and reference to photo numbers
- Do NOT use: irrelevant hashtags, keyword stuffing, links, or off-platform references
- End with 3 relevant hashtags on a new line

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**TITLE:** [Brand + Model + Key Details]

**DESCRIPTION:**
[Generated description following the structure above]

#hashtag1 #hashtag2 #hashtag3
```

### Quick-Sell / Competitive Pricing Variation

```
You are writing a Mercari listing designed to sell FAST in a competitive category.

## RULES:
- Title: Lead with most-searched terms for this item type
- Description: Short, punchy, all essential info in first 3 lines
  (mobile users see truncated descriptions)
- Emphasize condition and value proposition ("Retails for $120, get it for less!")
- Include measurements and flaw disclosure
- End with 3 hashtags

## PRODUCT DATA:
{product_data}

Generate the listing title and description.
```

---
---

# 6. Facebook Marketplace

## 6.1 Platform Overview
- **ID:** `facebook_marketplace`
- **Audience:** Broadest local audience — all ages, all categories, neighborhood-centric
- **Fees:** Free for local pickup | 5% on shipped orders (min $0.40 for orders under $8)
- **Listing format:** Fixed price, local pickup or shipping
- **Description tone:** Casual, conversational, neighborhood-friendly
- **Reach:** Massive — leverages Facebook's social graph and local targeting

## 6.2 Listing Rules & Requirements

### Mandatory
- Accurate photos of the actual item (no stock photos)
- Honest description of condition
- Real item must be for sale (no "testing interest" posts)
- Must comply with Facebook Commerce Policies
- Shipped items must include tracking
- Seller must be at least 18 years old

### Prohibited
- Counterfeit or unauthorized items
- Animals
- Healthcare products (thermometers, first-aid kits exempted)
- Weapons, ammunition, explosives
- Alcohol, tobacco, drugs
- Adult products or services
- Recalled products
- Digital products or subscriptions (with some exceptions)
- Services (use Facebook Services instead)
- Misleading, false, or deceptive listings
- Before-and-after photos for health/weight loss products
- No discrimination in housing, employment, or credit listings

### Content Rules
- No hate speech, threats, or harassment
- No clickbait or engagement-bait titles
- Photos must show actual item, not screenshots of other listings

## 6.3 Lifehacks & Best Practices

1. **Local + shipped = maximum reach** — offer both options when item size allows
2. **Respond within 1 hour** — Facebook tracks response time and rewards fast responders
3. **Price slightly high for negotiation** — Marketplace buyers expect to haggle
4. **Join local Buy/Sell groups** — cross-post listings to relevant Facebook groups for more exposure
5. **Renew listings weekly** — bump to top of local feed by marking as available
6. **Use all 10 photo slots** — first photo is critical for scroll-stopping
7. **Title = search keywords** — Facebook search is basic, so front-load with item type and brand
8. **Meet in public places** for local sales — police station parking lots are ideal
9. **Ship heavier items** via Marketplace shipping for wider audience
10. **Bundle items** — "take all for $X" deals move inventory fast locally
11. **Tag location accurately** — helps local buyers find you
12. **Use Messenger professionally** — respond promptly, confirm details clearly
13. **Seasonal timing matters** — list seasonal items 2-4 weeks before peak demand
14. **Clean items and photograph well** — Marketplace is casual but good photos still win
15. **No-shows are common** — confirm meetup 1 hour before and have backup buyers

## 6.4 AI Prompts

### Universal Product Description Generator

```
You are a Facebook Marketplace listing writer. Write casual, clear descriptions that
local and online buyers can quickly scan and understand.

## RULES:
- Title: Short and searchable — Item Type + Brand + Key Detail. Max ~100 characters.
  Example: "Nike Air Max 90 Size 9 - Like New"
- Description structure:
  1. What it is (1 sentence — item type, brand, model)
  2. Condition (straightforward — "Like new, worn once" or "Good condition, normal wear")
  3. Key details (size, color, material, dimensions, age)
  4. Any flaws (honest and specific)
  5. Price note (firm, OBO, or bundle discount)
  6. Pickup/shipping info ("Pickup in [area] or happy to ship")
- Tone: Casual and friendly — like posting in a neighborhood group. Short sentences. No jargon.
- Keep it brief — Marketplace buyers scan fast, mobile-first
- Include price context if relevant ("Retails for $150, selling for $60")
- Do NOT use: hashtags, excessive formatting, links, or platform references
- LOCAL SELLING TIP: Mention neighborhood/area for local discoverability

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**TITLE:** [Item Type + Brand + Key Detail]

**DESCRIPTION:**
[Short, scannable description following the structure above]
```

### Local Quick-Sell Variation

```
You are writing a Facebook Marketplace listing optimized for fast local sale.

## RULES:
- Title: Item + condition keyword ("Like New", "Brand New", "Great Condition")
- Description: 3-5 lines max. What it is, condition, why you're selling, pickup details.
- Include "OBO" (or best offer) if flexible on price
- Mention cross-streets or neighborhood (not exact address)
- Casual, zero-fluff tone

## PRODUCT DATA:
{product_data}

Generate the listing title and description.
```

---
---

# 7. OfferUp

## 7.1 Platform Overview
- **ID:** `offerup`
- **Audience:** Local buyers/sellers, mobile-first, US-focused, all categories
- **Fees:** No seller commission fees | Optional buyer protection at $2.99/sale | Shipped items: varies
- **Listing format:** Fixed price, local pickup primary, shipping available
- **Description tone:** Ultra-casual, brief, mobile-optimized
- **Strength:** Local selling with minimal fees — great for furniture, electronics, bulky items

## 7.2 Listing Rules & Requirements

### Mandatory
- Photos of actual item
- Accurate description of condition
- Legal items only
- Must be at least 18 to use
- Shipped items require tracking

### Prohibited
- Weapons and ammunition
- Drugs, alcohol, tobacco
- Animals
- Recalled products
- Stolen goods
- Counterfeit items
- Services (job postings, rentals handled separately)
- Adult content
- Misleading listings

### Safety Features
- TruYou identity verification (optional but builds trust)
- In-app messaging (keep all communication on-platform)
- Community meetup spots
- Rating system for buyers and sellers

## 7.3 Lifehacks & Best Practices

1. **Get TruYou verified** — verified profiles get more buyer trust and visibility
2. **Price for negotiation** — OfferUp buyers expect to haggle 15-25% off listed price
3. **Respond instantly** — app shows response time; fast responders get more inquiries
4. **Boost listings** for paid visibility in local feed (worth it for high-value items)
5. **Use clear, bright photos** — minimum 3 photos, show all angles
6. **Title = searchability** — item type + brand + key feature
7. **Keep descriptions SHORT** — OfferUp is mobile-first; 3-5 sentences max
8. **Offer shipping** for lightweight items to expand beyond local
9. **Renew listings regularly** — bump to top of local feed
10. **Meet at safe locations** — police stations, bank lobbies, busy public areas
11. **Cash or in-app payment only** — avoid Venmo/Zelle for stranger transactions
12. **Post in the right category** — miscategorized items get buried
13. **Bundle similar items** — "lot of 5 shirts for $25" moves volume
14. **Seasonal timing** — furniture sells best during move-in months (May-Sept)
15. **Mark items as sold promptly** — keeps your profile trustworthy

## 7.4 AI Prompts

### Universal Product Description Generator

```
You are an OfferUp listing writer. Write ultra-concise, mobile-friendly descriptions
for local and shipped sales.

## RULES:
- Title: Item Type + Brand + Key Detail. Short and searchable. Max ~80 characters.
  Example: "Sony 65" 4K Smart TV - Like New"
- Description: 3-5 sentences MAXIMUM. Mobile users see very little text.
  1. What it is (brand, model, what category)
  2. Condition (1 sentence — honest and direct)
  3. Key specs or details (size, color, age, what's included)
  4. Price context if relevant ("Paid $300, asking $120")
  5. Pickup/shipping note
- Tone: Ultra-casual. Short sentences. No fluff. Like a text message.
- Do NOT use: hashtags, bullet points, long paragraphs, formal language, platform references
- OfferUp buyers are bargain hunters — mention value or deal when relevant

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**TITLE:** [Item Type + Brand + Key Detail]

**DESCRIPTION:**
[3-5 sentence description, mobile-optimized]
```

---
---

# 8. Whatnot

## 8.1 Platform Overview
- **ID:** `whatnot`
- **Audience:** Collectors, enthusiasts, live-shopping fans — sneakers, trading cards, fashion, vintage, luxury
- **Fees:** 8% commission + 2.9% + $0.30 payment processing (~11% total)
- **Selling format:** PRIMARY = live auction shows | Secondary = fixed-price "Shop" listings
- **Description tone:** Energetic, collector-focused, hype-aware
- **Unique feature:** Live selling platform — real-time bidding, interaction, and community

## 8.2 Listing Rules & Requirements

### Mandatory
- Authentic items only — Whatnot has authentication for high-value categories
- Accurate descriptions and photos
- Ship within stated timeframe (typically 3 business days post-sale)
- All transactions on-platform
- Seller approval required to go live (application process)
- Must follow community guidelines during live shows

### Prohibited
- Counterfeit/replica items
- Weapons, drugs, illegal items
- Off-platform transactions
- Misleading descriptions or photos
- Harassment during live shows

### Live Show Requirements
- Must be approved as a seller (application + interview for some categories)
- Professional-quality video setup recommended (lighting, camera, audio)
- Must be engaging and interactive with buyers
- Follow content guidelines during stream
- Handle disputes through platform, not on-stream

## 8.3 Lifehacks & Best Practices

1. **Live shows are KING** — static listings exist but live auctions drive 90%+ of sales
2. **Start with discounted items** — warm up audience with deals before premium lots
3. **Interact actively** — say buyer names, answer questions, create energy
4. **Schedule shows consistently** — build a regular audience who returns weekly
5. **Giveaways drive attendance** — offer a free item for first X viewers or random winner
6. **Lighting and camera quality matter** — invest in ring light + phone mount minimum
7. **Show items up close** — buyers need to see condition, tags, stitching, details
8. **Bundle "mystery lots"** — popular format that creates excitement
9. **Cross-promote on social media** — Instagram, TikTok, YouTube to drive viewers to your show
10. **Fast shipping = repeat buyers** — ship within 1-2 days, include thank-you note
11. **Lower fees than Poshmark** — 11% vs 20%, better margins for high-value items
12. **Sell what Vestiaire bans** — Hermès accessories, small LV goods, collector items
13. **Use "Shop" listings** for items that don't need live auction energy
14. **Category matters** — sneakers, trading cards, vintage fashion, luxury are top performers
15. **End shows with a strong CTA** — "Follow for next week's drop!"

## 8.4 AI Prompts

### Universal Product Description Generator

```
You are a Whatnot listing copywriter. Write descriptions for both static shop listings
and items that will be shown during live auctions.

## RULES:
- Title: Brand + Item + Key Detail + Condition. Collector-focused.
  Example: "Supreme Box Logo Hoodie FW21 Red - DS (Deadstock)"
- Description structure (for Shop listings):
  1. What it is — brand, item, season/year, colorway
  2. Condition — use collector grading ("DS/Deadstock", "VNDS/Very Near Deadstock",
     "9/10", "8/10 — slight heel drag")
  3. Authenticity note ("100% authentic, purchased from [retailer]" or "Receipt available")
  4. Key details — size, measurements if applicable, what's included (box, tags, extras)
  5. Shipping note
- For live show lots: Write a brief "lot description" that the seller can read aloud:
  1. Item name and brand (2-3 words)
  2. One-line hook ("This one's a grail for any streetwear head")
  3. Condition and size
  4. Starting bid suggestion
- Tone: Enthusiastic, collector-savvy, uses community language
  (grail, heat, deadstock, fire, drip)
- Be honest about condition — Whatnot's Purchase Protection is strict on misrepresentation
- Do NOT use: excessive hype without substance, vague condition descriptions,
  or off-platform references

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**SHOP LISTING TITLE:** [Brand + Item + Key Detail]

**SHOP DESCRIPTION:**
[Detailed description for static listing]

**LIVE SHOW SCRIPT:**
[2-3 sentence script the seller can read during live auction]
```

---
---

# 9. Grailed

## 9.1 Platform Overview
- **ID:** `grailed`
- **Audience:** Male fashion enthusiasts 18–35 — streetwear, designer, archive, luxury menswear
- **Fees:** 9% commission + ~3% PayPal processing (~12% total)
- **Listing format:** Fixed price with offer/negotiation system
- **Listing cost:** Free to list, pay only when you sell
- **Description tone:** Knowledgeable, fashion-literate, detail-oriented
- **Photo slots:** Up to 12 per listing
- **Listing tags:** Up to 10 per listing (32 chars each)

## 9.2 Listing Rules & Requirements

### Mandatory
- Accurate photos required for authentication — Grailed's team reviews before going live
- Follow Grailed's Photo Guide for authentication (tags, logos, stitching, close-ups)
- Accurate condition description — if not "New/Never Worn", describe condition and flaws
- Include measurements (buyers shop by measurement, not tagged size)
- Accurate brand, designer, season, and style information
- All sales initiated on Grailed must complete on Grailed (no redirecting)
- Tracked shipping required on all parcels

### Prohibited
- Counterfeit items (authentication review + community reporting)
- Duplicate listings of identical items
- Harassment, bullying, hate speech
- Off-platform transaction solicitation
- Stock images or photos from other listings
- Misleading condition descriptions

### Authentication
- AI scans listings for duplicated stock photos and mismatched branding
- Human moderators inspect flagged listings (especially high-end/hyped brands)
- Community can report suspicious listings
- Listings with receipts, close-up stitching, and tag photos have highest trust rating
- "Authenticated by Grailed" badge for verified items

## 9.3 Bumping & Visibility
- Bump listing every 7 days (within first 30 days)
- After 30 days: must drop price 10%+ to bump
- Items curated into Designer/Grails/Hype sections by Grailed curation team
- Price, condition, brand, and style factor into section placement

## 9.4 Lifehacks & Best Practices

1. **Measurements are EVERYTHING** — include pit-to-pit, length, shoulder, sleeve, inseam in both inches and cm
2. **Keep titles under 7 words** — Grailed stats show shorter titles perform better
3. **5-10 high-quality photos minimum** — plain background, natural light, show every angle
4. **Include season/collection** — "SS21" or "FW19" — Grailed buyers care about archive details
5. **Use the description template** — Brand, condition rating (8/10, 9/10), measurements, flaws, retail price
6. **Price 10-15% above target** — Grailed buyers negotiate hard; leave room for offers
7. **Research sold comps** — Use "Show Only > Sold" filter to price accurately
8. **Use all 10 listing tags** — relevant style, brand, aesthetic tags boost discoverability
9. **Bump strategically** — bump on Sunday evenings when browsing peaks
10. **Keep ~25 active listings** — maintains shop visibility and activity signals
11. **Ship same/next day** — fast shipping builds reputation and repeat buyers
12. **Pack well** — Grailed items are often $200+; buyers expect quality packaging
13. **Include authenticity proof** — photos of receipts, order confirmations boost trust
14. **Cross-list** — Grailed for menswear/streetwear, Poshmark/eBay for everything else
15. **Respond promptly to messages** — engaged sellers rank higher

## 9.5 AI Prompts

### Universal Product Description Generator

```
You are a Grailed listing copywriter. Write fashion-literate, detail-oriented descriptions
for a knowledgeable menswear/streetwear audience.

## RULES:
- Title: Designer/Brand + Item Type + Key Detail. Under 7 words.
  Example: "Rick Owens DRKSHDW Geobasket Size 43"
- Description structure (follows Grailed's unwritten formula):
  1. Opening line: Brand + item type + size + key detail (colorway, collaboration, season)
  2. Season/Collection: "From the FW19 collection" or "SS21 drop"
  3. Condition: Use numeric rating — "9/10" or "8/10 — light fading at collar".
     Be specific about any wear.
  4. Measurements: ALL relevant measurements in both inches and centimeters:
     - Tops: Pit to pit, length, shoulder, sleeve
     - Bottoms: Waist, inseam, thigh, leg opening
     - Shoes: Insole length
  5. Retail context: Original retail price, exclusivity, sellout speed if relevant
  6. What's included: Original box, tags, dust bag, receipt, etc.
  7. Shipping policy: "Ships within 1-2 business days via [carrier]"
- Tone: Knowledgeable, fashion-insider, but not pretentious. Assume the buyer knows brands.
- Use correct designer terminology and abbreviations (DRKSHDW, CDG, WTAPS, etc.)
- Be brutally honest about condition — Grailed's Purchase Protection refunds
  misrepresented items
- Do NOT use: hype buzzwords without substance, vague descriptions, stock photos reference

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**TITLE:** [Designer + Item + Key Detail — under 7 words]

**DESCRIPTION:**
[Fashion-literate description following the structure above]

**SUGGESTED TAGS:** [up to 10 tags, 32 chars max each]
```

### Archive/Grail Item Variation

```
You are writing a Grailed listing for a rare or archive fashion piece that
collectors actively seek.

## RULES:
- Title: Brand + Item + Season/Year + Size
- Description: Lead with rarity and significance ("One of the most sought-after
  pieces from Raf Simons' AW03 collection")
- Include provenance if known (where purchased, from what collection)
- Condition must be detailed with specific flaw descriptions
- Measurements in both inches and cm
- Include authentication details (receipt, COA, known authentication markers)
- End with what makes this a "grail" — cultural significance, limited production,
  designer history

## PRODUCT DATA:
{product_data}

Generate the listing title and description.
```

---
---

# 10. The RealReal

## 10.1 Platform Overview
- **ID:** `therealreal`
- **Audience:** Luxury fashion buyers/sellers — Gucci, Chanel, Louis Vuitton, Hermès, Prada
- **Fees:** 30–60% commission (varies by item value and seller tier — consignment model)
- **Selling model:** FULL-SERVICE CONSIGNMENT — you ship items, they do everything else
- **Description tone:** Luxury editorial — polished, aspirational, brand-knowledgeable
- **Unique feature:** In-house authentication, professional photography, pricing, and listing

## 10.2 How It Works (Consignment Model)
1. **Submit items** — request a free shipping label or in-person pickup (10+ items in eligible cities)
2. **Authentication** — in-house team verifies all items
3. **Photography & listing** — professional studio photos, they write the descriptions
4. **Pricing** — TRR sets prices based on market data (you have limited control)
5. **Payout** — percentage of sale based on commission tier

### Commission Structure (approximate)
- Items under $200: Seller earns ~30-40%
- Items $200–$1,000: Seller earns ~50-60%
- Items $1,000+: Seller earns ~60-70%
- VIP/high-volume consignors may get better rates
- Unsold items returned after consignment period (at seller's expense) or donated

## 10.3 Listing Rules & Requirements

### What They Accept
- Luxury and designer brands (Chanel, Gucci, Hermès, Louis Vuitton, Prada, Dior, Balenciaga, etc.)
- High-end contemporary brands (The Row, Brunello Cucinelli, etc.)
- Clothing, handbags, shoes, jewelry, watches, home decor
- Items must be in good to excellent condition
- Clean, authentic items with no major damage

### What They Reject
- Fast fashion brands (H&M, Zara, Forever 21, etc.)
- Non-designer/contemporary brands below their threshold
- Items with significant damage, stains, or odors
- Counterfeit items (rejected at authentication)
- Items that don't meet their current demand standards

### Authentication
- All items authenticated in-house before listing
- ~8% of submitted items fail authentication
- Authentication certificate provided for sold items

## 10.4 Lifehacks & Best Practices

1. **Send your highest-value items** — commission structure favors items $500+
2. **Clean and prepare items** — polish hardware, dry-clean garments, remove personal items
3. **Include original packaging** — dust bags, boxes, authenticity cards increase value 20-30%
4. **Keep receipts** — proof of purchase speeds authentication and boosts buyer confidence
5. **Time submissions seasonally** — send winter coats in September, swimwear in February
6. **VIP consignor status** — higher volume = better commission rates
7. **Check their "most wanted" list** — TRR publishes what's in demand
8. **Combine with direct sales** — use TRR for items $500+, sell cheaper items on Poshmark/eBay
9. **Track your consignment** — monitor via dashboard; request return before donation deadline
10. **Photograph items before sending** — document condition in case of disputes
11. **White-glove service** — in eligible cities, request free home pickup for large collections
12. **Consider timing** — items listed during seasonal peaks sell faster and for more

## 10.5 AI Prompts

> **Note:** The RealReal writes their own listing descriptions. This prompt is for generating **pre-submission descriptions** to document items accurately before shipping, or for creating descriptions if cross-listing items on other platforms in luxury-appropriate style.

### Luxury Product Description Generator

```
You are a luxury fashion copywriter. Write polished, editorial-quality product descriptions
suitable for high-end consignment or luxury resale.

## RULES:
- Title: Brand + Item Type + Key Detail.
  Example: "Chanel Classic Medium Double Flap Bag - Black Caviar with Gold Hardware"
- Description structure:
  1. Brand and item identification (full name, collection/season if known)
  2. Materials and construction (leather type, hardware metal, fabric composition)
  3. Dimensions (in inches and centimeters — height, width, depth for bags;
     standard garment measurements for clothing)
  4. Condition assessment (use luxury scale: Pristine, Excellent, Very Good, Good, Fair —
     with specific notes on any wear)
  5. Provenance (where purchased, year, retail price if known)
  6. Included accessories (dust bag, box, authenticity card, receipt, strap, etc.)
  7. Authentication markers (serial number location, date code, known markers
     without revealing how to forge)
- Tone: Luxury editorial — sophisticated, knowledgeable, aspirational.
  Think Net-a-Porter product copy.
- Use correct luxury terminology (caviar leather, lambskin, toile canvas,
  palladium hardware)
- Never use casual language, slang, or abbreviations
- Condition honesty is paramount — luxury buyers expect precision

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**TITLE:** [Brand + Item + Key Detail]

**DESCRIPTION:**
[Luxury editorial description following the structure above]

**AUTHENTICATION NOTES:**
[Brief notes on what to document for authentication]
```

---
---

# 11. Vestiaire Collective

## 11.1 Platform Overview
- **ID:** `vestiaire_collective`
- **Audience:** Luxury fashion enthusiasts — global (strong in Europe, US, Australia)
- **Fees:** 12% on items $83+ | Flat $10 fee for items under $83 | Fixed $2,000 fee for items $16,667+ | 3% payment processing on all
- **Selling model:** Seller-managed listings with platform authentication before delivery
- **Description tone:** Sophisticated, curated, luxury-appropriate
- **Unique feature:** Pre-delivery authentication — items shipped to Vestiaire for verification before reaching buyer

## 11.2 Listing Rules & Requirements

### Mandatory
- Submit clear photos of actual item (front, back, details, tags, hardware, serial numbers)
- Accurate description of brand, model, size, condition, and materials
- Photos and descriptions are pre-approved before listing goes live
- Seller ships item to Vestiaire after sale for authentication before buyer receives it
- All transactions on-platform
- Free to list

### Prohibited
- Fast fashion brands — Vestiaire has banned 30+ brands including Gap, H&M, Zara, Boohoo, Shein
- Counterfeit items (rejected at authentication — ~8% rejection rate)
- Non-branded jewelry (recently restricted)
- Items not meeting condition standards
- Off-platform transactions
- Certain categories being restricted: Hermès home decor, VIP gifts, non-branded accessories

### Accepted Brands
- Focus on luxury and premium: Chanel, Hermès, Louis Vuitton, Gucci, Dior, Prada, Balenciaga, Celine, Saint Laurent, Bottega Veneta, The Row, Jacquemus, etc.
- Mid-tier designer accepted: Sandro, Maje, Isabel Marant, Acne Studios, etc.
- Check their brand list — it changes as they push upmarket

### Authentication Process
1. Item sells on platform
2. Seller ships to Vestiaire authentication center
3. Team verifies authenticity
4. If authentic → shipped to buyer
5. If not authentic → returned to seller (seller pays return shipping)
6. Adds 1-2 weeks to transaction time

## 11.3 Lifehacks & Best Practices

1. **Price competitively** — Vestiaire suggests prices based on similar sold items; use these
2. **Focus on items $200+** — fee structure and authentication overhead favor higher-value items
3. **Include ALL original packaging** — dust bags, boxes, cards increase perceived value significantly
4. **Photograph authentication markers** — serial numbers, date codes, brand stamps, hardware engravings
5. **Clean and prep items professionally** — first impressions matter for the approval process
6. **List in-demand brands** — Chanel, Hermès, Louis Vuitton sell fastest
7. **Monitor for listing removals** — Vestiaire has been aggressively removing edge-case items
8. **Time submissions** — seasonal alignment helps (winter coats in fall, etc.)
9. **Direct Shipping option** — some sellers can ship directly to buyers (higher trust level required)
10. **Negotiate smartly** — buyers can make offers; price 10-15% above your minimum
11. **Cross-list high-value items** — Vestiaire for authentication credibility + other platforms for speed
12. **Keep photos professional** — Vestiaire's audience expects a curated, editorial look
13. **Describe condition precisely** — use their condition scale and be detailed about any wear
14. **Consider Whatnot for items Vestiaire rejects** — especially accessories and collector items

## 11.4 AI Prompts

### Universal Product Description Generator

```
You are a Vestiaire Collective listing copywriter. Write sophisticated, curated
descriptions for luxury items that will pass Vestiaire's listing approval.

## RULES:
- Title: Brand + Item Type + Key Detail (color, material, size).
  Example: "Louis Vuitton Neverfull MM Damier Ebene"
- Description structure:
  1. Item identification (brand, item name, model, collection if known)
  2. Color and materials (use precise luxury terminology — "grained calfskin",
     "toile monogram canvas")
  3. Dimensions (cm and inches for bags: H x W x D; standard for clothing)
  4. Condition (Vestiaire scale: Never Worn, Very Good Condition, Good Condition,
     Fair Condition — with specific details)
  5. Hardware details (gold-tone, silver-tone, palladium, ruthenium —
     note any scratching or tarnishing)
  6. Included accessories (list everything: dust bag, box, authenticity card,
     receipt, lock/key, strap)
  7. Purchase details if known (where, when, retail price)
  8. Interior condition for bags (lining, pockets, zipper function)
- Tone: Curated and sophisticated — like a luxury consignment boutique sales associate
- Use French/Italian fashion terminology where appropriate and recognized
- Must be factual and precise — Vestiaire reviews descriptions against photos
- Do NOT use: casual language, slang, abbreviations, emojis, or unverifiable claims
- Do NOT reference other selling platforms

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**TITLE:** [Brand + Item + Key Detail]

**DESCRIPTION:**
[Sophisticated description following the structure above]

**CONDITION SUMMARY:** [Never Worn / Very Good / Good / Fair + brief detail]
```

---
---

# 12. thredUp

## 12.1 Platform Overview
- **ID:** `thredup`
- **Audience:** Women and children's clothing shoppers seeking value — eco-conscious, mainstream brands
- **Fees:** Commission-based consignment — seller earns 3%–80% depending on sale price
- **Selling model:** FULL-SERVICE CONSIGNMENT — you send a bag, they do everything
- **Description tone:** N/A for sellers — thredUp writes all descriptions
- **Unique feature:** Completely hands-off selling experience

## 12.2 How It Works (Consignment Model)
1. **Order a Clean Out Kit** — prepaid bag ($9.99+ service fee deducted from earnings)
2. **Fill with qualifying items** — clean, good condition, from accepted brands
3. **Ship it** — thredUp receives and inspects items
4. **They process** — photograph, list, price, and sell approved items
5. **You earn** — percentage of final sale price based on tier

### Payout Structure (approximate)
- Items selling $5–$19.99: Seller earns 3–15%
- Items selling $20–$49.99: Seller earns 15–30%
- Items selling $50–$99.99: Seller earns 40–60%
- Items selling $100–$199.99: Seller earns 60–80%
- Items selling $200+: Seller earns 70–80%
- **Service fee:** $14.99 per standard bag ($34.99 for premium bags) deducted from earnings
- **Payout options:** PayPal, prepaid Visa, thredUp credit, or charity donation

### Item Types
- **Upfront items:** On-trend, in-season, great condition → thredUp buys directly (immediate payout)
- **Consignment items:** Listed and sold over time → payout when sold (you can adjust price)

## 12.3 Listing Rules & Requirements

### What They Accept
- Women's and children's clothing, shoes, accessories
- Must be from thredUp's accepted brands list (ranges from Gap, J.Crew, Levi's to Coach, Vince, Theory)
- Clean, good-to-excellent condition
- No stains, holes, excessive wear, pilling, or odors

### What They Reject (~50% of submitted items)
- Items not on accepted brands list
- Items in poor condition
- Fast fashion below quality threshold
- Items with damage, stains, or odor
- Rejected items: donated unless you pay $10.99 return shipping

### Seller Control
- **Pricing:** thredUp sets prices; you can adjust consignment item prices
- **Speed:** Items start selling 4-6 weeks after bag received
- **Returns:** thredUp handles all buyer returns
- **Unsold items:** Eventually marked down or donated

## 12.4 Lifehacks & Best Practices

1. **Send higher-value items** — payout percentage is dramatically better for items $50+
2. **Only send accepted brands** — check the brand list before packing; rejected items cost you
3. **Clean and prep thoroughly** — wrinkle-free, fresh-smelling items get accepted at higher rates
4. **Send in-season items** — winter coats in fall, summer dresses in spring for best pricing
5. **Use thredUp credit** — higher payout than cash; good if you shop on thredUp too
6. **Sell cheap items elsewhere** — thredUp takes 85-97% on items under $20; use Poshmark or Mercari instead
7. **Track your bag** — monitor via dashboard; items appear 2-4 weeks after receipt
8. **Request return for rejects** — $10.99 to get items back; worth it for items you can sell elsewhere
9. **Combine with other platforms** — use thredUp for decluttering volume, other platforms for valuable pieces
10. **Maximize bag value** — fill with the best quality items to maximize acceptance rate
11. **Premium bags** ($34.99 service fee) — for designer/premium brands with higher payout potential
12. **Donate option** — choose a charity partner for rejected items instead of paying for returns

## 12.5 AI Prompts

> **Note:** thredUp writes all their own listings. This prompt is for generating **item documentation** before shipping to help you decide what to send, or for **cross-listing descriptions** if you choose to sell items elsewhere instead.

### Pre-Submission Triage & Cross-List Generator

```
You are a resale inventory manager. Generate a brief, accurate description of this item
to help decide whether it's better suited for thredUp (hands-off consignment) or another
platform (higher margins, more control).

## RULES:
- Assess item value tier:
  - Under $20 expected sale → Better on Poshmark/Mercari (thredUp keeps 85-97%)
  - $20-$50 → Marginal for thredUp; depends on effort tolerance
  - $50+ → Good thredUp candidate for hands-off selling
  - $100+ → Consider selling yourself on Poshmark/eBay for much higher margins
- Description includes:
  1. Brand and item type
  2. Condition assessment (Excellent, Very Good, Good, Fair)
  3. Estimated resale value (based on brand and condition)
  4. Platform recommendation (thredUp vs. self-listing)
  5. If self-listing recommended: brief marketplace-optimized description
- Tone: Practical, advisor-like

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**ITEM:** [Brand + Item Type]
**CONDITION:** [Assessment]
**ESTIMATED VALUE:** [$X range]
**RECOMMENDED PLATFORM:** [thredUp / Self-list on X]
**REASONING:** [1-2 sentences]

**CROSS-LISTING DESCRIPTION (if applicable):**
[Brief description suitable for Poshmark/eBay/Mercari]
```

---
---

# 13. Etsy

## 13.1 Platform Overview
- **ID:** `etsy`
- **Audience:** Buyers seeking handmade, vintage (20+ years), craft supplies, and unique items
- **Fees:** $0.20 listing fee + 6.5% transaction fee + 3% + $0.25 payment processing (~10% total)
- **Listing format:** Fixed price, variations supported, digital downloads
- **Description tone:** Artisanal, personal, story-driven
- **Search:** Holistic — weighs title, tags (13 max), attributes, descriptions, photos, reviews
- **Title guidance:** Under 15 words, clear and specific (2025 update)

## 13.2 Listing Rules & Requirements

### Creativity Standards (Critical for Etsy)
Everything on Etsy must be **made, designed, handpicked, or sourced** by the seller:
- **Handmade:** Made by seller using hand or computerized tools with ORIGINAL designs
- **Vintage:** Must be 20+ years old
- **Craft supplies:** Items that enable buyer creativity
- **Curated/handpicked:** Gift baskets with a clear theme (must list all contents)
- **AI-generated art:** Allowed IF based on seller's original prompts — MUST disclose AI use

### What's NOT Allowed
- **Reselling commercially available items** newer than 20 years (unless craft supplies)
- **Dropshipping** (except specific cases like craft supplies)
- Mass-produced items without seller's original design
- Stock photos or photos from other sellers/sites
- Items from generic templates (especially with computerized tools like Cricut — must use original designs)
- Natural items (rocks, gems, plants) not personally found/cultivated by seller
- Holiday décor in "Sourced by Seller" category (loophole closed 2025)

### Mandatory Listing Requirements
- Your OWN photographs or video (not stock photos, not AI renderings for the primary image)
- Accurate description of how item was made, by whom, and where shipped from
- Disclose production partners if used
- Accurate representation of item — first image must show actual finished product
- Comply with all IP/trademark rules — no using brand names you don't own

### Intellectual Property (Strict)
- No using popular brand names in titles, tags, or descriptions (even "inspired by" can get flagged)
- No references to movies, TV shows, books, or celebrities without license
- VeRO-equivalent enforcement — IP owners can request takedowns
- Violations = listing removal, warnings, potential shop closure

## 13.3 Etsy Search (SEO) — 2025 Updates

### Title Guidelines (New)
- Under 15 words recommended
- Lead with WHAT the item is (noun) + top 3 objective details (color, size, material)
- Remove subjective words ("beautiful", "perfect") — move to tags/description
- Remove aspirational search terms ("gift for him") — move to tags
- Remove pricing/shipping info from titles
- No keyword repetition

### Tags
- 13 tags per listing — USE ALL OF THEM
- Multi-word phrases are OK and recommended
- Complement your title (don't just repeat it)
- Include gift occasions, styles, use cases

### Attributes & Categories
- Fill in every available attribute — Etsy's search uses them heavily
- Correct category selection is critical for discovery

### Description
- Helps Etsy's search engine understand your listing
- First 160 characters appear in search snippets — make them count
- Natural keyword inclusion (not stuffing)

## 13.4 Lifehacks & Best Practices

1. **Use all 13 tags** — each should be a unique multi-word phrase buyers might search
2. **Clear, scannable titles under 15 words** — "Item + Color + Material + Size"
3. **First photo = actual finished product** — not a mockup or rendering
4. **Fill every attribute field** — color, material, occasion, style, etc.
5. **Tell your story** — Etsy buyers value the maker's narrative; use "About" section
6. **Reviews matter enormously** — follow up with buyers, provide excellent service
7. **Use Etsy's search analytics** — check what keywords drive traffic to your shop
8. **Seasonal inventory** — align listings with seasonal search trends
9. **Offer free shipping** — Etsy boosts listings with free shipping in US search
10. **Use Etsy Ads sparingly** — start with $1-5/day, focus on proven sellers
11. **Disclose AI use** — if any part of creation uses AI tools, state it in description
12. **Production partners** — if using one, disclose in relevant listings
13. **Original designs for computerized tools** — if using Cricut/laser cutter, designs must be your own
14. **Vintage items (20+ years)** — huge opportunity; detailed provenance increases value
15. **Download CSV of listings** — backup before making bulk title changes (2025 recommendation)

## 13.5 AI Prompts

### Universal Product Description Generator

```
You are an Etsy listing copywriter. Write artisanal, story-driven product descriptions
that balance SEO with the personal, handmade feel Etsy buyers expect.

## RULES:
- Title: Under 15 words. Structure: [Item Type] + [Top 3 Objective Details:
  color, material, size]. Example: "Handmade Ceramic Coffee Mug Blue Speckled Stoneware 12oz"
  - NO subjective words (beautiful, perfect, unique)
  - NO aspirational phrases (gift for her, birthday present) — put these in tags
  - NO pricing/shipping info
- Description structure:
  1. Opening paragraph: What the item is and what makes it special — weave in the
     maker's story or process (2-3 sentences)
  2. Materials and specifications (material, dimensions, weight, color details)
  3. How it's made (handcrafted process, tools used, time invested)
  4. Care instructions (if applicable)
  5. Shipping details (processing time, packaging)
  6. Customization options (if available)
  7. AI disclosure (if AI was used in any part of creation)
- First 160 characters: Must be compelling — this appears in search snippets
- Tags: Generate 13 unique multi-word tags that complement (not duplicate) the title
- Tone: Warm, personal, artisanal — the buyer should feel connected to the maker
- Include relevant keywords naturally — don't stuff
- For VINTAGE items: Include era, provenance, condition, and historical context
- Do NOT use: trademarked brand names you don't own, "inspired by [brand]", stock phrases

## PRODUCT DATA:
{product_data}

## OUTPUT FORMAT:
**TITLE:** [Under 15 words — item + key details]

**DESCRIPTION:**
[Story-driven description following the structure above]

**TAGS (13):**
1. [multi-word tag]
2. [multi-word tag]
...
13. [multi-word tag]

**ATTRIBUTES:**
- Material:
- Color:
- Dimensions:
- Style:
- Occasion:
```

### Vintage Item Variation

```
You are writing an Etsy listing for a vintage item (20+ years old). Highlight the era,
provenance, and collectibility.

## RULES:
- Title: Era/Decade + Item Type + Key Detail.
  Example: "1970s Brass Table Lamp Art Deco Style"
- Description: Lead with the era and historical context. Include condition honestly
  with vintage-appropriate language ("patina", "age-appropriate wear").
  Provide measurements and materials.
- Tags: Include decade, era, style movement, and use-case tags
- For clothing: Include measurements (vintage sizing differs from modern)
- Note: Vintage items ARE allowed to be resold on Etsy (20+ year rule)

## PRODUCT DATA:
{product_data}

Generate the title, description, and 13 tags.
```

---
---

## Notes

- All rules and fees are current as of research conducted March 2026
- Platform fees and policies change frequently — verify before major listing campaigns
- Cross-listing is standard practice — use inventory sync tools to prevent overselling
- AI-generated descriptions should ALWAYS be reviewed for accuracy before posting
