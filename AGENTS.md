# Resellerio Agent Notes

## Product context

This repository is the backend for a reseller-focused mobile app built on Phoenix and Elixir.

The core experience is:

1. A reseller taps `+Add` in the mobile app.
2. The app uploads one or more photos for a new product.
3. The backend creates the `Product` and `ProductImage` records.
4. An asynchronous AI pipeline analyzes the images, extracts structured product details, and drafts copy.
5. The backend optionally sends images through Photoroom for background removal/replacement.
6. The system generates marketplace-specific listing content for channels like eBay, Depop, and Poshmark.

The backend also needs:

- Email/password authentication.
- Passkey support for fast sign-in.
- S3-compatible media storage using Tigris.
- Product inventory management, including sold/archived states.
- JSON import/export, with export ZIP generation in the background and emailed download links.

## Current repo status

The project is currently a mostly empty Phoenix application with the first API foundation slice implemented:

- LiveView landing page at `/`.
- Browser sign-up and sign-in flows at `/sign-up` and `/sign-in`.
- Authenticated LiveView workspace shell with routed reseller sections at `/app`, `/app/products`, `/app/listings`, `/app/exports`, and `/app/settings`.
- Web workspace product intake now supports browser-side product creation with image uploads.
- Web workspace product management now supports detail editing, tags, seller-managed status changes, plus sold/archive/restore/delete lifecycle actions.
- Web workspace exports screen now supports requesting ZIP exports and uploading ZIP imports directly from LiveView.
- Versioned `/api/v1` namespace.
- `GET /api/v1` and `GET /api/v1/health` endpoints.
- Password-based API auth with register/login endpoints and bearer-token user lookup via `GET /api/v1/me`.
- Stable JSON API error shape.
- `Reseller.Accounts` context with `users` and `api_tokens`.
- `Reseller.Catalog` context with `products`.
- `products` now include seller-managed `tags`.
- `Reseller.Media` context with `product_images` and signed upload intent generation.
- Uploaded-image finalization via `POST /api/v1/products/:id/finalize_uploads`.
- Authenticated product API endpoints now include list/create/show/update/delete plus explicit sold/archive/unarchive lifecycle actions.
- `Reseller.Workers` context with `ProductProcessingRun` records and lightweight async task execution.
- `Reseller.AI` context plus `Reseller.AI.Provider` behaviour.
- `Reseller.Search` context plus `Reseller.Search.Provider` behaviour.
- Req-backed Gemini and SerpApi production clients with test-only fake providers.
- Local `.env` loading is handled in `config/runtime.exs` via `Nvir`; prefer `.env`, `.env.dev`, `.env.local`, and `.env.dev.local` for developer credentials instead of committing secrets.
- Tigris config now supports both bucket-style URLs and endpoint-style URLs. When using a generic endpoint like `https://t3.storage.dev` or `https://fly.storage.tigris.dev`, also set `TIGRIS_BUCKET_NAME` (or `BUCKET_NAME` / `AWS_BUCKET_NAME`).
- Newer Tigris buckets require virtual-hosted bucket URLs when using generic endpoints, so endpoint-style configs should resolve to `https://<bucket>.<endpoint-host>/...` for uploads and public URLs.
- Prefer separate Tigris env vars: `AWS_ENDPOINT_URL_S3` or `TIGRIS_ENDPOINT_URL` for signed uploads, and `TIGRIS_PUBLIC_URL` for public object URLs. `TIGRIS_BUCKET_URL` is now only a backward-compatible fallback.
- `Reseller.AI.ImageSelection`, `Reseller.AI.Normalizer`, and `Reseller.AI.RecognitionPipeline` for confidence-based recognition orchestration.
- Backpex-based admin interface under `/admin` for admin users, including `Users` and `API Tokens`.
- Browser-session admin gating plus LiveView admin gating.
- Security regression coverage for admin boundaries, bearer-token expiry, and privilege-escalation attempts.
- Product and image persistence plus upload finalization foundations now exist.
- Lightweight processing-run and async worker orchestration now exist.
- `Reseller.Workers.AIProductProcessor` now connects finalized uploads to `Reseller.AI.RecognitionPipeline` and persists normalized AI fields back to `products`.
- `product_description_drafts` now store AI-authored base titles and descriptions separately from user-editable product fields.
- `product_price_researches` now store AI-authored pricing guidance and comparable evidence separately from user-entered product pricing.
- `Reseller.Marketplaces` now stores per-marketplace generated listings for eBay, Depop, and Poshmark.
- `Reseller.Media.Processor` and `Reseller.Media.Processors.Photoroom` now generate processed image variants like `background_removed` and `white_background`.
- `Reseller.Exports` now builds ZIP archives, uploads them to storage, and triggers export-ready notifications.
- `Reseller.Imports` now stores uploaded ZIP archives, recreates products and images, restores generated metadata, and records per-product import failures.
- `Reseller.Catalog` now owns explicit product lifecycle mutations for edit, delete, sold, archive, and restore flows.
- The repo now includes release-oriented Docker packaging for production-style container deployment.
- Lightweight async worker orchestration exists today via `Reseller.Workers`, with room to grow into a more durable queue later.
- ExAws-backed Tigris S3 upload signing and object PUT support now live in `Reseller.Media.Storage.Tigris`, but broader storage lifecycle handling is still pending.
- `Reseller.Media.Storage.Tigris.upload_object/3` now intentionally falls back to an ExAws-generated presigned PUT when Tigris rejects the direct signed S3 request with `403 AccessDenied`.
- `docs/ARCHITECTURE.md` now documents the live system architecture, persisted schemas, and core process flows.
- `docs/UIUX.md` now defines the shared web interface design system and component vocabulary.

Plan and implementation work should assume we are building the backend foundation from scratch.

## Canonical domain language

Use these names consistently in code and docs:

- `User`: authenticated reseller.
- `Product`: inventory item the reseller is managing.
- `ProductImage`: an original or processed image attached to a product.
- `MarketplaceListing`: marketplace-specific generated content for one product and one marketplace.
- `Export`: background-generated archive of product data and images.
- `Import`: uploaded archive used to recreate product data and media.

Avoid introducing both `asset` and `product` as first-class inventory concepts unless there is a clear distinction. In this project, `Product` should be the primary record, and images/files are supporting assets.

## Architecture direction

- Treat this app as an API-first backend for a mobile client.
- Prefer JSON APIs under a versioned `/api/v1` namespace for core product features.
- Update `docs/API.md` whenever API routes or payloads change.
- Keep browser-rendered Phoenix pages minimal unless they serve admin or operational needs.
- Put business logic in contexts, not controllers.
- Use background jobs for all long-running work: AI recognition, image processing, ZIP export generation, email delivery fan-out, and large imports.
- Prefer direct-to-object-storage uploads via signed URLs for mobile clients whenever possible.
- Store both original and processed image variants; never overwrite the original upload.
- Processed image variants should be stored as additional `product_images`, not as replacements for the original upload.
- AI output should be reviewable and editable by the user. Do not design flows that assume AI is always correct.
- Keep generated base copy in dedicated draft records instead of overwriting user-edited product fields.
- Keep generated pricing guidance in dedicated research records instead of overwriting any user-entered `products.price`.
- Keep generated marketplace copy in dedicated listing records instead of storing marketplace blobs directly on `products`.
- Keep processed Photoroom outputs as separate `product_images` and allow variant-generation failures to leave the product otherwise usable.

## Suggested context boundaries

- `Reseller.Accounts`
  Handles users, password auth, sessions/tokens, passkeys, and auth auditing.

- `Reseller.Catalog`
  Handles products, seller-managed statuses, tags, notes, pricing, sold state, and product-level lifecycle rules.

- `Reseller.Media`
  Handles upload intents, object keys, image variants, storage metadata, and media processing orchestration.

- `Reseller.AI`
  Handles image recognition prompts, extraction normalization, confidence flags, and marketplace copy generation.

- `Reseller.Search`
  Handles external search providers such as SerpApi for Lens and shopping enrichment.

- `Reseller.Marketplaces`
  Handles marketplace-specific listing payloads, formatting constraints, and export adapters if those arrive later.

- `Reseller.Exports`
  Handles ZIP assembly, export artifact retention, and emailing download links.

- `Reseller.Imports`
  Handles source ZIP intake, archive parsing, import run bookkeeping, and product recreation from archives.

- `Reseller.Workers`
  Houses background workers and job orchestration modules.

## Data and workflow guidance

- Model product creation as an asynchronous pipeline with explicit statuses such as `draft`, `uploading`, `processing`, `review`, `ready`, `sold`, and `archived`.
- Keep product lifecycle changes explicit. Seller-facing edits go through `Reseller.Catalog.update_product_for_user/3`, which may change manual statuses only for `draft`, `review`, `ready`, `sold`, and `archived`; pipeline/system statuses should still be managed through dedicated lifecycle functions and workers.
- Track processing runs or job events so failures are debuggable and retryable.
- Marketplace-specific copy should live in separate records keyed by product and marketplace, not as one giant blob on `products`.
- Export archives should contain `index.json` plus an `images/` directory exactly as described in the product plan.
- Download links for exports should be time-limited and revocable.
- Export-ready notifications should be sent only after the archive upload succeeds and a download URL is available.

## Integration guidance

- Use `Req` for external HTTP APIs such as AI services, Photoroom, and email-provider REST APIs.
- For Tigris object storage, prefer the shared ExAws-backed S3 integration in `Reseller.Media.Storage.Tigris` instead of rolling custom signing or ad hoc HTTP uploads.
- Wrap external integrations behind behaviour-based modules so they can be mocked in tests and swapped later.
- Capture external request IDs and normalized error payloads for observability.
- Gemini and SerpApi foundations now exist. Reuse `Reseller.AI` and `Reseller.Search` instead of adding ad hoc API calls from controllers or workers.
- Base description drafts should go through `Reseller.AI.upsert_product_description_draft/2` so generated copy stays separate from the core product record.
- Price guidance should go through `Reseller.AI.upsert_product_price_research/2` so grounded pricing stays separate from the core product record.
- Keep API keys in runtime env vars such as `GEMINI_API_KEY` and `SERPAPI_API_KEY`, not compile-time literals.
- Gemini runtime config now also supports `GEMINI_MAX_RETRIES` and `GEMINI_RETRY_BACKOFF_MS` for retryable `429` handling.
- Gemini runtime config also supports `GEMINI_TIMEOUT_MS`; prefer increasing timeout and using bounded retries before adding custom worker-side retry loops.
- Tigris upload signing should go through `Reseller.Media.Storage`. Do not construct upload URLs ad hoc in controllers.
- External AI/media fetches should go through `Reseller.Media.Storage.sign_download/2` so Gemini and Photoroom receive signed object URLs instead of assuming the bucket is public.
- The current AI worker builds public object URLs from `TIGRIS_PUBLIC_URL` (or the backward-compatible `TIGRIS_BUCKET_URL`). Keep that path centralized through `Reseller.Media` rather than duplicating URL assembly in workers or controllers.
- Upload finalization should go through `Reseller.Media.finalize_product_uploads/3` or `Reseller.Catalog.finalize_product_uploads_for_user/3`, not custom controller logic.
- Product processing should be queued through `Reseller.Workers.start_product_processing/2`, not by spawning ad hoc tasks from controllers.
- Retrying an AI run should go through `Reseller.Catalog.retry_product_processing_for_user/3` so image state resets and run bookkeeping stay consistent.
- ZIP imports should go through `Reseller.Imports.request_import_for_user/3`. Keep archive validation, storage, parsing, and recreation out of controllers.

## Testing guidance

- Treat auth, admin authorization, and token validation as security-sensitive surfaces. Add or update tests whenever those flows change.
- Keep both behavior tests and attacker-style regression tests. Public registration and browser sign-up must never allow `is_admin` escalation.
- Bearer-token tests should cover valid, missing, malformed, and expired token cases.
- Admin route tests should cover unauthenticated, authenticated non-admin, and admin access paths.
- Prefer shared fixtures from `Reseller.AccountsFixtures` instead of hand-rolling users and tokens in every test file.
- When Backpex resources change, update tests for the routed surfaces under `/admin/...`, especially index, show, and edit flows that are actually reachable.
- For AI/search providers, prefer pure request builders plus provider behaviours so request payloads can be tested without live network calls.
- Keep test-only fake providers under `test/support` and use provider overrides or test config instead of real external requests.
- For AI pipeline logic, keep orchestration in small, composable modules like image selection, normalization, and pipeline runners so worker integration stays thin later.
- For product/upload work, test both the context transaction and the authenticated API response shape, especially image placeholders and upload instructions.
- For finalize-upload work, also test ownership checks, duplicate image IDs, and product/image status transitions.
- For worker foundations, test both the success and failure run states, and keep processors behind a behaviour so the real AI pipeline can be swapped in later.

## Delivery priorities

Build in this order unless a task explicitly says otherwise:

1. API foundation, auth, and background jobs.
2. Product creation with uploads and manual CRUD.
3. AI recognition and image-processing pipeline.
4. Marketplace-specific listing generation.
5. Import/export workflows.
6. Hardening, observability, rate limiting, and operational tooling.

## Implementation notes for future agents

- Update `docs/PLANS.md` before or during each feature so progress stays visible in-repo.
- Update `docs/API.md` in the same commit whenever API routes, params, or response payloads change.
- Update `docs/ARCHITECTURE.md` whenever schemas, context boundaries, runtime integrations, or end-to-end process flows change.
- Update `docs/UIUX.md` whenever shared web patterns, reusable components, or major interface direction changes.
- Update `docs/PLAN-AI.md` when AI/search milestones are completed or the pipeline shape changes.
- Update `docs/PLAN-WEB.md` when web/admin LiveView milestones are completed.
- Update `docs/PLANS.md` when Step 3 substeps like upload intents or finalize-upload flow are completed.
- Keep one feature per git commit whenever practical.
- Run `mix precommit` before closing out a feature.
- When changing runtime env vars or deployment assumptions, update `README.md`, `Dockerfile`, and `docker-compose.yml` together.
- Run `mix test --cover` when making significant auth/admin changes so coverage regressions are visible, even if the global threshold is currently held down by unused scaffold/generated modules.
- Backpex is now part of the stack. Prefer adding admin-only management screens there instead of building custom admin CRUD screens unless a task explicitly needs a custom experience.
- Prefer additive, well-scoped migrations. This project will likely evolve quickly as product requirements settle.
- When naming things, use `Product`, not `Production`, unless you are touching a user-facing string that explicitly requires different wording.
- Design APIs for mobile reliability: idempotent creation endpoints, resumable upload flows where possible, and explicit processing states.
- Add tests alongside each new context and endpoint. For async pipelines, test both the synchronous enqueue step and the worker behavior. Security-facing changes should also get explicit regression tests.
- For AI worker changes, cover both `ready` and `review` success paths plus failure recovery that marks runs and images correctly.
- For retryable AI failures like Gemini quota exhaustion, prefer structured `error_code`s and keep original images retryable instead of treating them as broken uploads.
- When product payloads change, update `docs/API.md` and the authenticated product controller tests so the API shape stays intentional.
- When introducing auth, keep API and browser auth concerns separate so mobile clients are not forced through browser-centric flows.
- If passkeys are implemented, document both registration and authentication ceremonies and keep the server challenge flow small and explicit.
- Treat the reseller web workspace as a first-class surface now. New core product workflows should land in both the API and LiveView unless there is a clear reason to keep them mobile/API-only.
- Prefer `ResellerWeb.UIComponents` for shared surfaces, badges, tiles, and upload panels instead of repeating large Tailwind class bundles in every LiveView.

This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
<!-- phoenix:ecto-end -->

<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`
- Remember anytime you use `phx-hook="MyHook"` and that js hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Never** write embedded `<script>` tags in HEEx. Instead always write your scripts and hooks in the `assets/js` directory and integrate them with the `assets/js/app.js` file

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
        socket
        |> assign(:messages_empty?, messages == [])
        # reset the stream with the new messages
        |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @stream.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset
<!-- phoenix:liveview-end -->

<!-- usage-rules-end -->
