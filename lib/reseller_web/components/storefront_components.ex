defmodule ResellerWeb.StorefrontComponents do
  @moduledoc false

  use Phoenix.Component

  import ResellerWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: ResellerWeb.Endpoint,
    router: ResellerWeb.Router,
    statics: ResellerWeb.static_paths()

  alias Reseller.Catalog.Product
  alias Reseller.Media
  alias Reseller.Media.ProductImage
  alias Reseller.Marketplaces
  alias Reseller.Marketplaces.MarketplaceListing
  alias Reseller.Slugs
  alias Reseller.Storefronts.Storefront
  alias Reseller.Storefronts.StorefrontAsset
  alias Reseller.Storefronts.StorefrontPage
  alias Reseller.Storefronts.ThemePresets

  attr :storefront, :map, required: true
  attr :product, :map, required: true

  def storefront_product_card(assigns) do
    assigns =
      assigns
      |> assign(:image_url, storefront_primary_image_url(assigns.product))
      |> assign(:price_text, storefront_price_text(assigns.product))
      |> assign(:marketplace_links, storefront_marketplace_links(assigns.product))
      |> assign(:summary, storefront_product_summary(assigns.product))
      |> assign(:highlights, storefront_product_highlights(assigns.product))

    ~H"""
    <article
      id={"storefront-product-#{@product.id}"}
      class="group overflow-hidden rounded-[1.85rem] border border-[var(--storefront-border)] bg-[var(--storefront-surface)] shadow-[0_24px_70px_rgba(15,23,42,0.08)] transition duration-300 hover:-translate-y-1 hover:shadow-[0_28px_80px_rgba(15,23,42,0.12)]"
    >
      <.link href={storefront_product_path(@storefront, @product)} class="block h-full">
        <div class="relative aspect-[4/5] overflow-hidden border-b border-[var(--storefront-border)] bg-white/60">
          <img
            :if={@image_url}
            src={@image_url}
            alt={@product.title || "Storefront product image"}
            class="size-full object-cover transition duration-500 group-hover:scale-[1.02]"
          />
          <div
            :if={!@image_url}
            class="flex size-full items-center justify-center bg-[radial-gradient(circle_at_top,_rgba(255,255,255,0.85),_rgba(255,255,255,0.45)_40%,_rgba(255,255,255,0)_80%)] px-6 text-center text-sm text-[var(--storefront-muted)]"
          >
            Images available on the product detail page.
          </div>
          <div class="pointer-events-none absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-black/10 to-transparent">
          </div>
        </div>

        <div class="flex h-full flex-col gap-4 p-5">
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <p class="text-[11px] uppercase tracking-[0.28em] text-[var(--storefront-muted)]">
                {storefront_product_eyebrow(@product)}
              </p>
              <h2 class="mt-2 line-clamp-2 text-xl font-semibold tracking-[-0.03em] text-[var(--storefront-text)]">
                {@product.title || "Untitled product"}
              </h2>
            </div>

            <span class="shrink-0 rounded-full border border-[var(--storefront-border)] px-3 py-1 text-sm font-semibold text-[var(--storefront-text)]">
              {@price_text}
            </span>
          </div>

          <p :if={@summary} class="line-clamp-3 text-sm leading-6 text-[var(--storefront-muted)]">
            {@summary}
          </p>

          <div :if={@highlights != []} class="flex flex-wrap gap-2">
            <span
              :for={highlight <- @highlights}
              class="rounded-full border border-[var(--storefront-border)] bg-white/55 px-3 py-1 text-xs font-medium text-[var(--storefront-text)]"
            >
              {highlight}
            </span>
          </div>

          <div class="mt-auto flex items-center justify-between gap-4 pt-2">
            <p class="text-xs uppercase tracking-[0.28em] text-[var(--storefront-muted)]">
              {storefront_marketplace_count_copy(@marketplace_links)}
            </p>
            <span class="inline-flex items-center gap-2 text-sm font-semibold text-[var(--storefront-text)]">
              View item <.icon name="hero-arrow-up-right" class="size-4" />
            </span>
          </div>
        </div>
      </.link>
    </article>
    """
  end

  def storefront_theme(%Storefront{theme_id: theme_id}), do: storefront_theme(theme_id)

  def storefront_theme(theme_id) when is_binary(theme_id) do
    case ThemePresets.fetch(theme_id) do
      {:ok, preset} -> preset
      :error -> storefront_theme(ThemePresets.default_id())
    end
  end

  def storefront_theme(_theme_id), do: storefront_theme(ThemePresets.default_id())

  def storefront_theme_style(storefront_or_theme) do
    colors =
      storefront_or_theme
      |> storefront_theme()
      |> Map.fetch!(:colors)

    [
      "--storefront-page-bg: #{colors.page_background}",
      "--storefront-surface: #{colors.surface_background}",
      "--storefront-text: #{colors.text}",
      "--storefront-muted: #{colors.muted_text}",
      "--storefront-primary: #{colors.primary_button}",
      "--storefront-accent: #{colors.secondary_accent}",
      "--storefront-border: #{colors.border}",
      "--storefront-overlay: #{colors.hero_overlay}"
    ]
    |> Enum.join("; ")
  end

  def storefront_nav_pages(%Storefront{pages: pages}) when is_list(pages) do
    Enum.filter(pages, & &1.published)
  end

  def storefront_nav_pages(_storefront), do: []

  def storefront_brand_asset(%Storefront{assets: assets}, kind) when is_list(assets) do
    Enum.find(assets, &(&1.kind == to_string(kind)))
  end

  def storefront_brand_asset(_storefront, _kind), do: nil

  def storefront_logo_url(%Storefront{} = storefront) do
    storefront
    |> storefront_brand_asset("logo")
    |> storefront_asset_url()
  end

  def storefront_logo_url(_storefront), do: nil

  def storefront_header_url(%Storefront{} = storefront) do
    storefront
    |> storefront_brand_asset("header")
    |> storefront_asset_url()
  end

  def storefront_header_url(_storefront), do: nil

  def storefront_asset_url(%StorefrontAsset{storage_key: storage_key})
      when is_binary(storage_key) do
    case Media.public_url_for_storage_key(storage_key) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  def storefront_asset_url(_asset), do: nil

  def storefront_image_url(%ProductImage{} = image) do
    case Media.public_url_for_image(image) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  def storefront_image_url(_image), do: nil

  def storefront_primary_image_url(%Product{} = product) do
    product
    |> storefront_gallery_images()
    |> List.first()
    |> storefront_image_url()
  end

  def storefront_primary_image_url(_product), do: nil

  def storefront_gallery_images(%Product{images: images}) when is_list(images) do
    case Enum.filter(images, &(&1.kind == "original")) do
      [] -> images
      originals -> originals
    end
  end

  def storefront_gallery_images(_product), do: []

  def storefront_marketplace_links(%Product{marketplace_listings: listings})
      when is_list(listings) do
    Enum.filter(listings, fn listing ->
      is_binary(listing.external_url) and String.trim(listing.external_url) != ""
    end)
  end

  def storefront_marketplace_links(_product), do: []

  def storefront_product_ref(%Product{} = product) do
    title_slug = Slugs.slugify(product.title || "", max_length: 80)

    case title_slug do
      "" -> Integer.to_string(product.id)
      slug -> "#{product.id}-#{slug}"
    end
  end

  def storefront_product_path(%Storefront{slug: slug}, %Product{} = product) do
    product_ref = storefront_product_ref(product)
    ~p"/store/#{slug}/products/#{product_ref}"
  end

  def storefront_page_path(%Storefront{slug: slug}, %StorefrontPage{slug: page_slug}) do
    ~p"/store/#{slug}/pages/#{page_slug}"
  end

  def storefront_price_text(%Product{price: %Decimal{} = price}) do
    "$" <> Decimal.to_string(Decimal.round(price, 2), :normal)
  end

  def storefront_price_text(_product), do: "Price on request"

  def storefront_product_summary(%Product{} = product) do
    [product.ai_summary, product.notes]
    |> Enum.find(&present_text?/1)
  end

  def storefront_product_summary(_product), do: nil

  def storefront_product_highlights(%Product{} = product) do
    [
      product.brand,
      product.category,
      product.condition,
      product.size,
      product.material,
      product.color
    ]
    |> Enum.filter(&present_text?/1)
    |> Enum.take(3)
  end

  def storefront_product_highlights(_product), do: []

  def storefront_product_attribute_rows(%Product{} = product) do
    [
      {"Brand", product.brand},
      {"Category", product.category},
      {"Condition", product.condition},
      {"Size", product.size},
      {"Material", product.material},
      {"Color", product.color}
    ]
    |> Enum.filter(fn {_label, value} -> present_text?(value) end)
  end

  def storefront_product_attribute_rows(_product), do: []

  def storefront_plain_text_paragraphs(body) when is_binary(body) do
    body
    |> String.trim()
    |> String.split(~r/\n\s*\n+/, trim: true)
  end

  def storefront_plain_text_paragraphs(_body), do: []

  def storefront_marketplace_count_copy([]), do: "No external marketplace links yet"
  def storefront_marketplace_count_copy([_listing]), do: "1 marketplace link"

  def storefront_marketplace_count_copy(listings) when is_list(listings) do
    "#{length(listings)} marketplace links"
  end

  def storefront_marketplace_label(%MarketplaceListing{marketplace: marketplace}) do
    Marketplaces.marketplace_label(marketplace)
  end

  def storefront_marketplace_label(_listing), do: "Marketplace"

  def storefront_product_eyebrow(%Product{} = product) do
    [product.brand, product.category]
    |> Enum.filter(&present_text?/1)
    |> Enum.join(" / ")
    |> case do
      "" -> "Public storefront"
      label -> label
    end
  end

  def storefront_product_eyebrow(_product), do: "Public storefront"

  defp present_text?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_text?(_value), do: false
end
