# Reseller Web App Plan

## Progress Tracker

- [x] Step W1.1: Replace the generated Phoenix homepage with a reseller-focused LiveView landing page.
- [x] Step W1.2: Add browser sign-in and sign-up LiveViews.
- [x] Step W1.3: Create the authenticated web shell for future product screens.
- [x] Step W1.4: Add a Backpex-based admin interface for users with admin permission.
- [x] Step W2.1: Build the dashboard LiveView.
- [ ] Step W2.2: Build the products index with filters and statuses.
- [ ] Step W3.1: Build the new product upload flow.
- [ ] Step W4.1: Build the product detail and editing flow.
- [ ] Step W5.1: Build export and import screens.

## Latest Web Progress

- Completed: Step W2.1 dashboard LiveView.
- Current homepage route: `live "/"`, `ResellerWeb.HomeLive`
- Current auth routes: `live "/sign-up"`, `POST "/sign-up"`, `live "/sign-in"`, `POST "/sign-in"`, `DELETE "/sign-out"`, protected `live "/app"`, `live "/app/products"`, `live "/app/listings"`, `live "/app/exports"`, `live "/app/settings"`, and protected admin routes under `/admin`
- Next target: Step W2.2 products index refinement with filters and richer actions.

## 1. Current Web Stack Analysis

The repo already has the right technical foundation for a LiveView web app:

- Phoenix LiveView is installed and wired in [assets/js/app.js](/Users/mpak/www/elixir/reseller/assets/js/app.js).
- Tailwind v4 is configured in [assets/css/app.css](/Users/mpak/www/elixir/reseller/assets/css/app.css).
- DaisyUI is already vendored and loaded as a Tailwind plugin.
- The root layout already supports theme switching in [lib/reseller_web/components/layouts/root.html.heex](/Users/mpak/www/elixir/reseller/lib/reseller_web/components/layouts/root.html.heex).
- The shared app layout in [lib/reseller_web/components/layouts.ex](/Users/mpak/www/elixir/reseller/lib/reseller_web/components/layouts.ex) already uses DaisyUI-style primitives such as `navbar`, `btn`, `badge`, and theme toggles.

What is still missing:

- The current homepage is still the generated Phoenix marketing page.
- There are no reseller-focused LiveViews yet.
- There is no browser auth flow yet for the web surface.
- There are no product management screens, uploads, AI review states, or export/import UIs yet.

Conclusion:

The web version should be treated as a new LiveView product layer on top of the backend contexts that already exist or are planned in `docs/PLANS.md`.

## 2. Product Goal For Web

The web app should be the operational dashboard for resellers who want a bigger-screen experience than mobile.

The web version should focus on:

- fast product intake from photos
- batch-friendly inventory management
- AI review and correction
- marketplace content review
- export/import workflows
- account and workspace settings

The web app does not replace the API-first backend. It should reuse the same core contexts and business rules.

## 3. UX Direction

Use LiveView for the entire authenticated app shell and interactive inventory workflows.

Use Tailwind for layout, spacing, responsive behavior, and custom branding.

Use DaisyUI selectively for:

- drawers
- modals
- tabs
- badges
- alerts
- stats
- menus
- cards
- loading indicators

Do not let DaisyUI dictate the whole visual language. The best result here is:

- DaisyUI for consistent interaction primitives
- custom Tailwind composition for page identity and premium polish

## 4. Web Information Architecture

Recommended main surfaces:

- Public landing page
- Sign up
- Sign in
- Password reset
- Dashboard
- Products index
- Product detail
- New product upload flow
- Marketplace listings review
- Exports
- Imports
- Settings

Recommended navigation:

- Left drawer/sidebar on desktop
- Bottom or compact top navigation on mobile
- Persistent quick action for `+ Add Product`
- Search and filters always visible on product-heavy screens

## 5. LiveView Route Plan

Recommended LiveViews:

- `ResellerWeb.HomeLive`
  - marketing landing page or authenticated redirect

- `ResellerWeb.Auth.SignUpLive`
  - email/password registration

- `ResellerWeb.Auth.SignInLive`
  - email/password sign-in

- `ResellerWeb.DashboardLive`
  - top-level metrics, in-progress items, recent exports, and quick actions

- `ResellerWeb.ProductsLive.Index`
  - filters, search, statuses, bulk actions

- `ResellerWeb.ProductsLive.New`
  - new product creation with uploads and AI pipeline kickoff

- `ResellerWeb.ProductsLive.Show`
  - product detail, image variants, AI-extracted metadata, marketplace copy

- `ResellerWeb.ProductsLive.Edit`
  - structured product editing

- `ResellerWeb.ListingsLive`
  - per-marketplace generated content review and regeneration

- `ResellerWeb.ExportsLive`
  - export request history and download status

- `ResellerWeb.ImportsLive`
  - import upload and result summaries

- `ResellerWeb.SettingsLive`
  - background defaults, profile settings, future passkey setup

## 6. App Shell Plan

Create a shared authenticated shell using `<Layouts.app ...>` with:

- brand/header row
- workspace or user identity block
- primary navigation
- global search trigger
- theme toggle
- flash messages
- a clear `+ Add Product` button

Recommended shell patterns:

- desktop: `drawer drawer-open`
- mobile: collapsible drawer with top bar
- content: generous spacing, `max-w-7xl`, clear section headers, sticky filter bars where useful

## 7. Product Management UX

### Products Index

Show:

- photo thumbnail
- title
- status
- price
- marketplace readiness
- processing state
- updated time

Filters:

- all
- processing
- review needed
- ready
- sold
- archived

Bulk actions:

- mark sold
- archive
- regenerate AI
- export selected

### Product Detail

Show:

- image gallery with original and processed variants
- structured metadata fields
- AI confidence and review flags
- marketplace tabs for eBay / Depop / Poshmark
- activity/status timeline

Actions:

- edit fields
- regenerate description
- regenerate marketplace copy
- request background removal/replacement
- mark sold

### New Product Flow

Recommended LiveView UX:

1. User opens `New Product`.
2. User drops or selects photos.
3. Upload begins immediately.
4. UI shows staged thumbnails and upload progress.
5. Product draft is created.
6. AI processing status streams into the page.
7. User lands on a review screen instead of a blank detail page.

## 8. Upload Strategy

For the web version, prefer LiveView external uploads to Tigris rather than sending all binaries through the Phoenix app.

Recommended approach:

- use `allow_upload/3`
- use external uploads with presigned Tigris URLs
- persist upload metadata into `ProductImage`
- enqueue processing once uploads are finalized

Why:

- consistent with mobile architecture
- less server bandwidth pressure
- cleaner retry story
- simpler path to large-image handling

## 9. AI Review UX

AI should never feel like a black box.

The web UI should surface:

- processing step labels
- success/failure states
- confidence warnings
- fields AI inferred
- fields user changed manually

Recommended UI treatments:

- `steps` or progress timeline for pipeline state
- `alert` for failures or review-required items
- badges like `AI Draft`, `Needs Review`, `Ready`
- side-by-side or tabbed marketplace copy review

## 10. DaisyUI Theme Strategy

The current repo already has light and dark DaisyUI themes configured. Build on that instead of replacing it immediately.

Recommended visual direction:

- keep DaisyUI theme tokens as the base system
- tune colors toward commerce/editorial inventory tooling rather than Phoenix defaults
- add stronger typography, surface hierarchy, and spacing rhythm with custom Tailwind classes

Recommended custom theme accents:

- warm neutral backgrounds for catalog-heavy screens
- strong success/warning colors for inventory states
- vivid accent color for AI-generated or in-progress states

## 11. Component Plan

Create reusable function components for:

- app sidebar navigation
- top command bar
- page header with actions
- product status badge
- processing state badge
- marketplace tabs
- image gallery
- AI review panel
- empty states
- import/export status cards

Use DaisyUI building blocks underneath where appropriate, but expose project-specific components from `ResellerWeb.CoreComponents` or adjacent component modules.

## 12. Auth Plan For Web

The backend already has API registration, login, and bearer-token auth.

For the LiveView web app, we should add browser-oriented auth next:

- browser sign-in form
- browser session handling
- sign-out flow
- route protection for authenticated LiveViews

Important note:

Do not duplicate account rules. Reuse `Reseller.Accounts` for credential validation and token/session creation, even if browser session storage is separate from API bearer tokens.

## 13. Recommended Delivery Phases

### Phase W1: App Shell And Auth

- replace the generated homepage
- add sign-in and sign-up LiveViews
- create authenticated app shell
- add route protection for LiveViews

### Phase W2: Product Dashboard

- add dashboard LiveView
- add products index
- add statuses, filters, and empty states

### Phase W3: New Product Flow

- add upload LiveView
- connect uploads to Tigris
- show in-progress AI state

### Phase W4: Product Detail And Editing

- product detail view
- image variant gallery
- editable metadata fields
- marketplace content tabs

### Phase W5: Export / Import Screens

- export history
- import upload and summaries
- downloadable export status UI

### Phase W6: Polish

- keyboard shortcuts
- batch actions
- richer loading states
- optimistic updates where safe
- better empty and error states

## 14. LiveView Testing Plan

Cover the web version with:

- route access tests
- LiveView render tests
- form validation tests
- upload flow tests
- auth redirect tests
- empty-state and status rendering tests

High-value tests:

- unauthenticated user is redirected away from protected LiveViews
- product creation upload screen shows progress and validation
- AI processing state is rendered correctly
- product status badges and filters behave correctly
- export request UI reflects queued and completed states

## 15. Implementation Notes

- Every LiveView template should start with `<Layouts.app flash={@flash} ...>`.
- Prefer streams for large product lists.
- Keep product list filters and counts server-driven.
- Avoid putting business logic in LiveViews; keep it in contexts.
- When the web UI needs background updates, use PubSub or re-polling sparingly and intentionally.
- Keep `docs/API.md`, `docs/PLANS.md`, and this file aligned as backend and web features evolve.

## 16. Recommended Next Web Step

The best first implementation step for the web app is:

1. replace the generated homepage with a reseller-focused landing page
2. add browser sign-in and sign-up LiveViews
3. create the authenticated app shell for future product screens

That gives the project a real web identity and creates the base needed for all later LiveView work.
