# UI / UX System

This file captures the shared UI rules visible in the current LiveView code.

## Design Direction

- warm, light operational surfaces
- editorial display typography for major headings
- restrained motion
- shared rounded geometry
- practical density for workflow screens

The product intentionally separates three visual surfaces:

- marketing pages via `Layouts.app`
- seller storefront pages via `Layouts.storefront`
- authenticated workspace screens via the workspace shell

## Shared UI Primitives

Current reusable primitives live in:

- `lib/reseller_web/components/layouts.ex`
- `lib/reseller_web/components/ui_components.ex`
- `lib/reseller_web/components/core_components.ex`
- `lib/reseller_web/components/storefront_components.ex`

Important patterns:

- `surface`
- `metric_card`
- `feature_tile`
- `status_badge`
- upload and modal treatments

## Page Rules

Marketing:

- expressive hero sections are acceptable
- section anchors are homepage-specific
- marketing pages should still reuse shared buttons and surface language

Workspace:

- operational screens should prefer stable surfaces over decorative layouts
- repeated patterns should be extracted into shared components
- filters, tables, and review panels should stay compact and predictable

Storefront:

- storefront theme colors come from `ThemePresets`
- the authenticated storefront API returns the same preset catalog for mobile theme selection
- storefront branding assets and gallery images come from shared storefront helpers
- public product cards should use the storefront gallery selection helpers, not ad hoc image picking

## Testing Rule

Important forms, tables, and primary actions should keep stable ids/selectors for LiveView tests.

## Source of Truth

- home: `lib/reseller_web/live/home_live.ex`
- pricing: `lib/reseller_web/live/pricing_live.ex`
- workspace: `lib/reseller_web/live/workspace_live.ex`
- storefront rendering: `lib/reseller_web/components/storefront_components.ex`
