# Reseller Backend Plan

## Progress Tracker

- [x] Step 1: API foundation with versioned `/api/v1`, health check endpoint, and stable JSON error shape.
- [x] Step 2: Accounts foundation with `users`, password auth, and mobile session tokens.
- [ ] Step 3: Product and image schemas with signed upload flow.
- [ ] Step 4: Background job system and product processing runs.
- [ ] Step 5: AI recognition and marketplace listing generation.
- [ ] Step 6: Photoroom-powered image processing variants.
- [ ] Step 7: ZIP export generation and export-ready email flow.
- [ ] Step 8: ZIP import flow.

## Latest Progress

- Completed: Step 2 accounts foundation.
- Current API endpoints: `GET /api/v1`, `GET /api/v1/health`, `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, and `GET /api/v1/me`
- API reference: `docs/API.md`
- Next target: Step 3 product and image schemas with signed upload flow.

## Working Rules

- Update this file before creating each feature commit.
- Keep one feature per git commit.
- Run `mix precommit` before finishing the feature branch or checkpoint.

## 1. Current State

This repository is a Phoenix 1.8 application with early API foundation already in place:

- Phoenix, Ecto, Bandit, Swoosh, Req, LiveView, and Tailwind already present.
- A default browser pipeline and landing page.
- A versioned `/api/v1` namespace.
- A health endpoint at `GET /api/v1/health`.
- A stable JSON error response shape for API requests.
- No authentication.
- No Ecto schemas beyond the repo itself.
- No background job infrastructure.
- No storage or AI integrations.

That means we should treat this as a greenfield backend project, not an iteration on an existing product domain.

## 2. Product Goal

Build a mobile-app backend for resellers that can:

- Sign users up and sign them in with email/password.
- Support fast passkey-based authentication.
- Let users create a product by uploading photos.
- Store original and processed images in Tigris S3-compatible storage.
- Recognize what is in the photos using an AI API.
- Generate product metadata and listing descriptions automatically.
- Generate marketplace-specific content for eBay, Depop, Poshmark, and future channels.
- Let users manage product lifecycle states such as draft, ready, sold, and archived.
- Export products and images as a ZIP archive containing `index.json` and `images/*`.
- Import the same archive format back into the system.
- Generate exports asynchronously and email a download link when ready.

## 3. Recommended Backend Shape

Use Phoenix as an API-first backend with versioned JSON endpoints under `/api/v1`.

Recommended major building blocks:

- `Reseller.Accounts`
- `Reseller.Catalog`
- `Reseller.Media`
- `Reseller.AI`
- `Reseller.Marketplaces`
- `Reseller.Exports`
- `Reseller.Workers`

Recommended infrastructure additions:

- PostgreSQL as the primary system of record.
- An S3-compatible storage integration for Tigris.
- A background job system for image processing, AI calls, ZIP creation, and email follow-up.
- Structured logging and tracing around every external integration.

## 4. Core Domain Model

### Accounts

- `users`
  - email
  - hashed_password
  - confirmed_at
  - default_background_style
  - onboarding_state

- `passkey_credentials`
  - user_id
  - credential_id
  - public_key
  - sign_count
  - transports
  - aaguid
  - label
  - last_used_at

- `api_tokens` or equivalent mobile-session records
  - user_id
  - token_hash
  - expires_at
  - device_name
  - last_used_at

### Catalog

- `products`
  - user_id
  - status
  - source
  - title
  - brand
  - category
  - condition
  - color
  - size
  - material
  - price
  - cost
  - sku
  - notes
  - ai_summary
  - ai_confidence
  - sold_at
  - archived_at

- `product_images`
  - product_id
  - kind (`original`, `background_removed`, `background_replaced`, `thumbnail`)
  - position
  - storage_key
  - content_type
  - width
  - height
  - byte_size
  - checksum
  - background_style
  - processing_status

- `product_processing_runs`
  - product_id
  - status
  - step
  - started_at
  - finished_at
  - error_code
  - error_message
  - payload

### Marketplace Content

- `marketplace_listings`
  - product_id
  - marketplace
  - status
  - generated_title
  - generated_description
  - generated_tags
  - generated_price_suggestion
  - generation_version
  - last_generated_at

### Import / Export

- `exports`
  - user_id
  - status
  - storage_key
  - expires_at
  - requested_at
  - completed_at
  - error_message

- `imports`
  - user_id
  - status
  - storage_key
  - summary
  - requested_at
  - completed_at
  - error_message

## 5. Key Workflows

### A. Sign up / Sign in

1. User signs up with email and password.
2. Backend confirms email.
3. Mobile app creates a device session token.
4. User can later register a passkey.
5. Future sign-ins may use either password or passkey.

Recommendation:

- Build email/password first.
- Add passkeys once session/token flows are stable.
- Keep mobile API auth separate from browser session auth.

### B. Create Product From Photos

Recommended flow:

1. Mobile app calls `POST /api/v1/products` with minimal metadata.
2. Backend creates a `Product` in `draft` or `uploading` state.
3. Backend returns upload instructions for one or more images.
4. Mobile app uploads originals directly to Tigris using signed URLs.
5. Mobile app calls a finalize endpoint when uploads complete.
6. Backend enqueues the processing pipeline.
7. Workers create normalized image records, call AI recognition, call Photoroom if enabled, and generate marketplace copy.
8. Product transitions to `review` or `ready`.

Why this shape:

- Mobile uploads do not bottleneck the Phoenix app.
- Retries are easier.
- The backend owns the authoritative product state machine.

### C. AI Recognition Pipeline

Suggested steps:

1. Validate uploaded images and extract metadata.
2. Generate thumbnails.
3. Send one or more images to the AI recognition provider.
4. Normalize extracted attributes into product fields.
5. Mark low-confidence results for review.
6. Generate generalized product copy.
7. Generate marketplace-specific listing variants.
8. Persist a processing summary and final state.

Important rule:

AI should assist, not silently overwrite trusted user edits. Once a user manually updates a field, future regeneration should respect that unless explicitly requested.

### D. Background Removal / Replacement

Suggested behavior:

- Keep the original image permanently.
- Create additional processed variants.
- Support user defaults such as white background, black background, or no replacement.
- Record which provider and settings created each variant.

### E. Manage Product Inventory

Core actions:

- List products with filters.
- View product details.
- Edit generated fields.
- Delete or archive products.
- Mark as sold.
- Regenerate AI or marketplace copy.
- Reorder images.

### F. Export to ZIP

Requested archive shape:

- `index.json`
- `images/<filename>`

Recommended export flow:

1. User requests export.
2. Backend creates an `Export` record and enqueues a job.
3. Worker fetches product data and referenced images.
4. Worker builds the ZIP archive.
5. Archive is uploaded to Tigris.
6. Backend emails a signed download link to the user.
7. Export record tracks expiry and status.

### G. Import From ZIP

Recommended import flow:

1. User uploads a ZIP archive.
2. Backend stores the uploaded file and creates an `Import` record.
3. Worker validates the archive structure.
4. Worker reads `index.json`.
5. Worker recreates products and attaches images.
6. Worker records per-record failures without crashing the entire import.

## 6. API Design Direction

Recommended initial endpoints:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `POST /api/v1/passkeys/register/options`
- `POST /api/v1/passkeys/register/verify`
- `POST /api/v1/passkeys/authenticate/options`
- `POST /api/v1/passkeys/authenticate/verify`
- `GET /api/v1/products`
- `POST /api/v1/products`
- `GET /api/v1/products/:id`
- `PATCH /api/v1/products/:id`
- `DELETE /api/v1/products/:id`
- `POST /api/v1/products/:id/finalize_uploads`
- `POST /api/v1/products/:id/regenerate`
- `POST /api/v1/products/:id/mark_sold`
- `POST /api/v1/exports`
- `GET /api/v1/exports/:id`
- `POST /api/v1/imports`
- `GET /api/v1/imports/:id`

Response design guidelines:

- Include explicit processing statuses.
- Return stable IDs and timestamps everywhere.
- Make creation/finalization endpoints idempotent where possible.
- Return machine-readable error codes for mobile handling.

## 7. External Integrations

### Tigris

Use Tigris as S3-compatible object storage for:

- Original uploads
- Processed images
- Thumbnails
- ZIP exports
- Optional import upload staging

Need configuration for:

- bucket name
- region / endpoint
- access key
- secret key
- signed URL expiration

### AI Provider

Use an image-capable AI API to:

- identify product type
- extract structured attributes
- propose title and description
- create marketplace-specific copy

Implementation guidance:

- Wrap provider calls behind a behaviour.
- Persist raw provider payloads only when useful for debugging and compliant with privacy goals.
- Normalize provider output before it reaches the `products` table.

### Photoroom

Use Photoroom for:

- background removal
- optional background replacement

Guidance:

- Treat Photoroom as optional per user or per product.
- Fail gracefully and keep original images available.

### Email Delivery

Use email for:

- account confirmation
- export-ready notifications
- future operational notifications

## 8. Background Jobs

A job system is strongly recommended before building the AI/media features.

Workers likely needed:

- `FinalizeProductUploadsWorker`
- `AnalyzeProductImagesWorker`
- `GenerateMarketplaceListingsWorker`
- `ProcessImageBackgroundWorker`
- `BuildExportArchiveWorker`
- `SendExportReadyEmailWorker`
- `RunImportWorker`

Job requirements:

- retries with backoff
- deduplication where possible
- visibility into failures
- admin tooling for manual replay

## 9. Security and Reliability

- Store passwords with a modern password hashing approach.
- Hash API tokens at rest.
- Keep signed URLs short-lived.
- Validate all uploaded MIME types, byte sizes, and extensions.
- Enforce per-user object ownership checks on every product and image operation.
- Add rate limiting for auth and AI-triggering endpoints.
- Log integration failures with enough metadata to debug without leaking secrets.
- Make background jobs idempotent.

## 10. Delivery Phases

### Phase 0: Foundation

- Add API router structure and JSON error format.
- Add environment configuration strategy.
- Add background jobs.
- Add storage abstraction for Tigris.
- Add integration behaviour modules.

### Phase 1: Accounts

- Implement user schema and password auth.
- Add mobile session/token auth.
- Add email confirmation and password reset.
- Add passkey support after the base auth flow works.

### Phase 2: Product CRUD + Uploads

- Implement products and product images.
- Add signed upload URL flow.
- Add finalize-upload endpoint.
- Add list/detail/update/sold/archive flows.

### Phase 3: AI + Image Processing

- Add AI recognition job.
- Add normalized extraction mapping.
- Add Photoroom processing.
- Add processing status tracking.

### Phase 4: Marketplace Listings

- Add marketplace listing records.
- Generate eBay, Depop, and Poshmark-specific copy.
- Add regeneration and manual editing support.

### Phase 5: Import / Export

- Build ZIP export pipeline.
- Add email download notifications.
- Build ZIP import processing.
- Add audit logs and summaries.

### Phase 6: Hardening

- Add observability dashboards.
- Add rate limiting and quotas.
- Add better retry/recovery tooling.
- Add performance profiling and load testing for upload-heavy flows.

## 11. Testing Plan

Cover these layers:

- Context tests for `Accounts`, `Catalog`, `Media`, `AI`, and `Exports`.
- Controller tests for JSON APIs.
- Worker tests for async orchestration and retry-safe behavior.
- Integration tests for signed-upload finalization.
- Import/export format tests using real ZIP fixtures.

High-value scenarios:

- user can create product and finalize uploads
- AI pipeline failure does not lose uploaded images
- background-removed variant failure still leaves product usable
- marketplace copy can be regenerated without overwriting manual edits
- export email is only sent once the archive exists
- import continues when one product entry is malformed

## 12. Recommended Near-Term Decisions

These should be settled early because they affect schema and auth design:

- Will users ever belong to teams/workspaces, or is ownership strictly one user per inventory set for now?
- Do mobile clients use long-lived refresh tokens, rotating session tokens, or both?
- Should AI output be regenerated automatically after every image change, or only on explicit request?
- Do we need draft/private/public listing states beyond internal inventory states?
- Will exports contain only the requesting user’s products, or support filtered exports by status/date/marketplace?

## 13. First Practical Build Order

If implementation starts immediately, this is the best sequence:

1. Add API versioning, JSON fallback/error handling, and auth plugs.
2. Add users plus password-based auth and mobile tokens.
3. Add products and product images with signed Tigris upload URLs.
4. Add product-processing job records and a background job system.
5. Add AI extraction and marketplace listing generation behind behaviours.
6. Add Photoroom processing for image variants.
7. Add export ZIP generation and email notification flow.
8. Add import ZIP handling.

Implementation notes:

- Step 1 is now complete in the codebase.
- Each completed feature should update this tracker before its commit is created.
- The next implementation milestone is Step 2: accounts foundation.

## 14. Working Assumptions

These assumptions were used to shape this plan:

- The primary client is a mobile app, not a browser dashboard.
- `Product` is the canonical inventory record.
- AI generation is asynchronous and reviewable.
- Tigris is used for all binary artifact storage.
- Export generation happens in the background and delivery is via email link.

If any of those assumptions change, update this plan before building too far on top of it.
