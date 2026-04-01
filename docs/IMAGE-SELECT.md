# IMAGE-SELECT Plan

## Goal

Add three tightly coupled features that improve the image management UX in the workspace and
the image display in the public storefront:

1. **Image lightbox + download** — clicking any thumbnail in the workspace product Images panel
   opens a full-size overlay with a download-to-local-machine button.

2. **Storefront visibility toggle** — each image group card in the workspace gains a checkbox
   (or toggle) that lets the seller mark individual images as `storefront_visible`.  The control
   is only shown when the seller's storefront is enabled.

3. **Storefront image ordering** — the seller can drag-and-drop (or use up/down buttons) to set
   a per-image `storefront_position` that controls the display order on the public storefront.

4. **Storefront gallery upgrade** — the public storefront product page shows images in
   `storefront_position` order, renders only the `storefront_visible` ones (or falls back to all
   originals when none are explicitly visible), and lets visitors click a thumbnail to see it
   full-size in an accessible lightbox.

---

## Current state (what exists today)

| Layer | Relevant file | Notes |
|---|---|---|
| Schema | `Reseller.Media.ProductImage` | `position`, `kind`, `processing_status`, `seller_approved` — no storefront-specific fields |
| Context | `Reseller.Storefronts` | `storefront_gallery_images/1` returns all originals ordered by `position + id` |
| StorefrontComponents | `storefront_gallery_images/1` filters for `kind == "original"` | used by both card and product page |
| Workspace Show LV | `ResellerWeb.ProductsLive.Show` | renders image groups; no lightbox or per-image storefront control |
| Storefront product page | `storefront_html/product.html.heex` | static thumbnail grid; no click-to-enlarge |

---

## Schema changes

### Migration: `add_storefront_fields_to_product_images`

Add two columns to `product_images`:

| Column | Type | Default | Purpose |
|---|---|---|---|
| `storefront_visible` | `boolean` | `false` | seller opts this image into storefront gallery |
| `storefront_position` | `integer` | `nil` | explicit display order for storefront; `nil` means use `position` as tiebreaker |

```sql
ALTER TABLE product_images
  ADD COLUMN storefront_visible boolean NOT NULL DEFAULT false,
  ADD COLUMN storefront_position integer;

CREATE INDEX product_images_storefront_position_index
  ON product_images (product_id, storefront_position NULLS LAST);
```

### `Reseller.Media.ProductImage` schema update

- Add `storefront_visible` and `storefront_position` fields.
- Add `storefront_update_changeset/2` that only casts these two fields; validate `storefront_position > 0` when present.

---

## Context changes

### `Reseller.Media` (or `Reseller.Catalog`)

Add a public API function:

```elixir
@spec update_image_storefront_settings(
        User.t(),
        product_id :: integer(),
        image_id :: integer(),
        attrs :: map()
      ) :: {:ok, Product.t()} | {:error, :not_found | Ecto.Changeset.t()}
```

- Ownership-scope: product must belong to `user`.
- Apply `ProductImage.storefront_update_changeset/2` with `storefront_visible` and/or `storefront_position`.
- Return the reloaded product (same preload as the rest of the Show LiveView).

Add a batch reorder function:

```elixir
@spec reorder_storefront_images(
        User.t(),
        product_id :: integer(),
        ordered_image_ids :: [integer()]
      ) :: {:ok, Product.t()} | {:error, :not_found | Ecto.Changeset.t()}
```

- Sets `storefront_position` to the list index (1-based) for each image id.
- All updates run inside a single `Ecto.Multi` transaction.
- Return the reloaded product.

### `Reseller.Storefronts`

Update `storefront_gallery_images/1` (and the corresponding query in `public_product_preload`):

- **Preferred behaviour**: return images where `storefront_visible == true` ordered by
  `storefront_position NULLS LAST, position, id`.
- **Fallback**: if no image has `storefront_visible == true`:
  1. Show approved `lifestyle_generated` images (`seller_approved == true`), sorted by `position, id`.
  2. Then `background_removed` images, sorted by `position, id`.
  3. If neither category exists, fall back to all `original` images sorted by `position, id`.
- Filter: only images with `processing_status == "ready"` are shown publicly.
- **Status**: ✅ Implemented in `ResellerWeb.StorefrontComponents.storefront_gallery_images/1`.

---

## API changes

### New endpoints

```
PATCH /api/v1/products/:id/images/:image_id/storefront
```

Body:
```json
{
  "storefront_visible": true,
  "storefront_position": 2
}
```

Returns `200` with updated product JSON (existing product shape).

```
PUT /api/v1/products/:id/images/storefront_order
```

Body:
```json
{ "image_ids": [42, 17, 99] }
```

Returns `200` with updated product JSON.

Update `docs/API.md` with these two routes.

---

## LiveView workspace changes (`ResellerWeb.ProductsLive.Show`)

### Lightbox overlay

- Add a `lightbox_image` assign (default `nil`).
- Clicking any `<img>` with `phx-click="open_lightbox"` and `phx-value-image-id` sets
  `lightbox_image` to the matching `ProductImage`.
- The overlay renders as a full-viewport `<div>` with:
  - the full-resolution image centered
  - a **Download** `<a href=... download>` link (signed URL from `Reseller.Media.Storage`)
  - a close button (`phx-click="close_lightbox"`) and `Escape` keydown hook
- `open_lightbox` and `close_lightbox` are `handle_event` clauses.
- Lightbox works for both original and background-removed variants (each `<img>` in the gallery
  gets its own click target with the image id).

### Per-image storefront controls

- In each image group card, below the original/bg-removed pair, add (when `@storefront` is
  not `nil`):
  - A toggle/checkbox: **Show on storefront** bound to
    `phx-click="toggle_storefront_visible"` + `phx-value-image-id`.
  - A small drag handle icon (or up/down arrows) for reordering.  Start with up/down arrow
    buttons (`phx-click="move_storefront_image_up"` / `"move_storefront_image_down"` +
    `phx-value-image-id`) as the drag-free fallback.
- Handle events:
  - `toggle_storefront_visible` → calls `update_image_storefront_settings/4` and
    `assign_product`.
  - `move_storefront_image_up` / `move_storefront_image_down` → derives new ordering from
    current `storefront_position` values; calls `reorder_storefront_images/3` and
    `assign_product`.

### Drag-and-drop ordering (stretch, JS hook)

- Wrap the image group list in a `phx-hook="SortableImages"` container.
- On `end` event from SortJS / Sortable.js, push a `"reorder_storefront_images"` event with
  the new `image_ids` ordering.
- Handle that event identically to the up/down arrow path.

---

## Helpers changes (`ResellerWeb.ProductsLive.Helpers`)

- `storefront_image_visible?/1` — returns `image.storefront_visible`.
- `storefront_visible_count/1` — count of images with `storefront_visible == true` for the
  badge.
- Keep `product_image_groups/1` unchanged; add `storefront_display_images/1` that returns
  the ordered visible subset for the storefront preview badge in the workspace.

---

## Storefront product page changes

### `storefront_html/product.html.heex`

Replace the static thumbnail grid with an interactive gallery:

1. **Primary image** — remains the first image in `storefront_gallery_images/1`.
2. **Thumbnail strip** — all gallery images rendered as small clickable thumbnails.
   - Clicking a thumbnail swaps the primary image via JS `phx-hook="StorefrontGallery"` or
     pure `data-src` + a tiny Alpine/JS hook (no LiveView round-trip required for display).
3. **Lightbox** — clicking the primary image opens a full-size overlay with a close button.
   - Implemented with a minimal pure-JS/CSS dialog approach (no extra library) or the same
     hook used in the workspace.

### `ResellerWeb.StorefrontComponents`

- Update `storefront_gallery_images/1` to consume the new ordering/visibility fields.
- Add `storefront_primary_image/1` returning the first gallery image struct (for use in the
  lightbox `alt` and `src`).

---

## Migration checklist

- [ ] Write migration `add_storefront_fields_to_product_images`
- [ ] Update `Reseller.Media.ProductImage` schema and changeset
- [ ] Add `update_image_storefront_settings/4` to `Reseller.Media` (or `Reseller.Catalog`)
- [ ] Add `reorder_storefront_images/3` to `Reseller.Media` (or `Reseller.Catalog`)
- [ ] Update `storefront_gallery_images/1` in `Reseller.Storefronts` + `StorefrontComponents`
- [ ] Update `public_product_preload` in `Reseller.Storefronts` to order by storefront fields
- [ ] Add `PATCH .../images/:image_id/storefront` API endpoint + controller + tests
- [ ] Add `PUT .../images/storefront_order` API endpoint + controller + tests
- [ ] Update `docs/API.md`
- [ ] Add lightbox overlay to `ProductsLive.Show` (assigns, events, render)
- [ ] Add per-image storefront toggle + move buttons to image group cards
- [ ] Add `storefront_image_visible?/1` and `storefront_visible_count/1` to `Helpers`
- [ ] Upgrade storefront product page thumbnail strip + lightbox
- [ ] Update `StorefrontComponents` helpers
- [ ] Add LiveView tests: lightbox open/close, toggle visible, reorder
- [ ] Add storefront controller/context tests: gallery ordering, visibility fallback
- [ ] Run `mix precommit`

---

## Non-goals for this plan

- Dedicated mobile drag-and-drop API endpoint (can reuse the `PUT .../storefront_order` shape)
- Paid/gated storefront image slots
- AI-suggested image ordering
- Video or 360° media support
