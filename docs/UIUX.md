# Resellerio UI/UX System

## Purpose

This document defines the visual system for the Resellerio web app so LiveView screens feel like one product instead of a set of unrelated pages.

The current UI direction is:

- editorial serif headlines over calm utility-driven UI chrome
- warm, light workspace surfaces with soft borders instead of heavy card stacks
- rounded geometry with a premium but restrained feel
- subtle motion only on high-value elements like hero cards and interactive tiles
- dense operational screens that still preserve whitespace and reading rhythm

## Visual principles

### 1. Calm control room

The web app is not a marketplace storefront. It is an operational workspace for sellers reviewing products, uploads, AI output, and archive jobs.

Use:

- clear section framing
- stable surfaces
- predictable spacing
- utility actions near the related data

Avoid:

- decorative clutter inside data-heavy screens
- loud gradients behind form-heavy panels
- mixed card treatments on the same screen

### 2. Editorial hierarchy

Resellerio uses serif display typography to make core screens feel branded and intentional, while body and control text stay simple and readable.

Use:

- `.reseller-display` for page titles and major marketing statements
- uppercase eyebrow labels for section context
- standard sans-serif text for forms, tables, and metadata

### 3. One surface language

Panels should come from shared UI components, not one-off class strings.

Use:

- `<.surface>` for panels and containers
- `<.metric_card>` for dashboard numbers
- `<.feature_tile>` for action-oriented cards
- `<.status_badge>` for lifecycle and job states
- `<.upload_panel>` for file intake

Avoid:

- manually retyping `rounded-[1.75rem] border border-base-300 bg-base-100 p-6`
- inventing new badge styles per screen
- mixing dashed upload boxes with unrelated paddings and row treatments

## Layout rules

### App shell

- Public pages use `<Layouts.app ...>`
- Authenticated pages use `<Layouts.app_shell ...>`
- LiveViews should always start inside the correct layout wrapper

### Section framing

Use `<.section_intro>` for page and section headers when you need:

- eyebrow
- large title
- description
- optional action cluster

This keeps hero, auth, and workspace intros aligned.

### Spacing

Preferred rhythm:

- `gap-8` between major workspace sections
- `gap-4` between sibling cards
- `p-6` for standard surfaces
- `p-4` for soft inset surfaces

## Canonical components

### `<.section_intro>`

Use for:

- page headings
- hero copy blocks
- section intros above grouped content

Do not use for:

- tiny subheaders inside compact cards

### `<.surface>`

Base container primitive.

Variants:

- `default`: primary panel for forms, tables, and summary cards
- `soft`: inset panel for supporting details inside a larger card
- `ghost`: lightweight tonal panel for supportive marketing or helper content
- `contrast`: dark or high-contrast spotlight panel
- `interactive`: hover-ready panel for tiles

Padding:

- `lg` is the default
- `md` for nested detail blocks
- `none` for tables or custom inner structure

### `<.metric_card>`

Use for dashboard stats with:

- short label
- prominent numeric value
- one-sentence explanation

### `<.feature_tile>`

Use for:

- quick actions
- workflow steps
- feature summaries

If it navigates, pass `patch`, `navigate`, or `href`.

### `<.status_badge>`

Use for:

- product status
- processing run status
- export/import status

Statuses should stay lowercase in data, but the badge presents them consistently.

### `<.upload_panel>`

Use for all browser uploads.

It standardizes:

- upload label and help text
- file picker placement
- queued file rows
- remove actions
- error rendering

## Screen guidance

### Landing page

- keep the expressive hero
- use shared tiles for workflow explanation
- preserve whitespace and asymmetry

### Auth pages

- one strong form surface
- one supporting narrative column
- helper benefits in muted surfaces, not custom mini-cards

### Workspace pages

- all main work should happen inside standard surfaces
- nested AI details should use `soft` surfaces
- filters and tables stay practical and compact
- seller-managed product tabs should sit above the table filters as a single horizontal strip, with `+ Add tab` living in the same cluster
- lightweight create flows like the product-tab modal should reuse the standard fixed-overlay modal treatment already used for exports
- status should always go through `<.status_badge>`

## Interaction rules

- Buttons should remain rounded and compact unless they are hero CTAs
- Hover motion should be subtle: border shift, slight lift, softer shadow
- Destructive actions should remain visually distinct but not oversized
- Upload and import flows should show progress rows in the same visual format

## Implementation rules

- Prefer `ResellerWeb.UIComponents` over repeating Tailwind panel strings
- Update this file when a new shared UI primitive is introduced
- If a new screen needs a visual pattern three times or more, extract a component
- Keep IDs on important forms, tables, and action triggers for LiveView tests

## Current source of truth

The shared UI layer lives in:

- `lib/reseller_web/components/ui_components.ex`
- `lib/reseller_web/components/layouts.ex`
- `assets/css/app.css`

Screens currently using the shared system:

- `lib/reseller_web/live/home_live.ex`
- `lib/reseller_web/live/auth/sign_in_live.ex`
- `lib/reseller_web/live/auth/sign_up_live.ex`
- `lib/reseller_web/live/workspace_live.ex`
