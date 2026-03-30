defmodule Reseller.Seeds do
  alias Reseller.Accounts
  alias Reseller.AI
  alias Reseller.Catalog
  alias Reseller.Catalog.Product
  alias Reseller.Marketplaces
  alias Reseller.Media.ProductImage
  alias Reseller.Repo

  def run do
    password = "very-secure-password"

    _admin =
      ensure_user!(%{
        email: "admin@reseller.local",
        password: password,
        admin?: true
      })

    seller =
      ensure_user!(%{
        email: "seller@reseller.local",
        password: password,
        admin?: false
      })

    ready_product =
      ensure_product!(
        seller,
        %{
          "status" => "ready",
          "source" => "manual",
          "title" => "Levi's Vintage Denim Jacket",
          "brand" => "Levi's",
          "category" => "Outerwear",
          "condition" => "Used - Good",
          "color" => "Blue",
          "size" => "M",
          "material" => "Denim",
          "price" => "89.00",
          "cost" => "18.00",
          "sku" => "DEMO-READY-1",
          "notes" => "Starter seed product with AI draft and image variants.",
          "ai_summary" => "Vintage blue denim jacket with classic trucker fit.",
          "ai_confidence" => 0.93
        },
        images: [
          %{
            kind: "original",
            position: 1,
            storage_key: "seed/products/demo-ready-1/original.jpg",
            content_type: "image/jpeg",
            processing_status: "ready",
            original_filename: "demo-ready-1.jpg"
          },
          %{
            kind: "white_background",
            position: 1,
            storage_key: "seed/products/demo-ready-1/white-background.png",
            content_type: "image/png",
            processing_status: "ready",
            background_style: "white",
            original_filename: "demo-ready-1-white.png"
          }
        ],
        description_draft: %{
          provider: :gemini,
          model: "seed",
          output: %{
            "suggested_title" => "Levi's Vintage Denim Jacket",
            "short_description" => "Classic blue Levi's denim jacket in a versatile medium fit.",
            "long_description" =>
              "Vintage Levi's trucker jacket with a structured denim body and everyday wearability.",
            "key_features" => ["Button front", "Chest pockets", "Classic blue wash"],
            "seo_keywords" => ["levis jacket", "vintage denim", "trucker jacket"]
          }
        },
        price_research: %{
          provider: :gemini,
          model: "seed",
          output: %{
            "currency" => "USD",
            "suggested_min_price" => 75,
            "suggested_target_price" => 89,
            "suggested_max_price" => 110,
            "suggested_median_price" => 90,
            "pricing_confidence" => 0.82,
            "rationale_summary" => "Comparable resale listings cluster around the high 80s.",
            "market_signals" => ["Steady demand"],
            "comparable_results" => [%{"title" => "Levi's denim jacket", "price" => 92.0}]
          }
        },
        marketplace_listings: [
          {"ebay",
           %{
             provider: :gemini,
             model: "seed",
             output: %{
               "generated_title" => "Levi's Vintage Denim Jacket Medium Blue Trucker",
               "generated_description" =>
                 "Classic Levi's denim jacket with blue wash and trucker styling.",
               "generated_tags" => ["levis", "denim", "vintage"],
               "generated_price_suggestion" => 92
             }
           }},
          {"depop",
           %{
             provider: :gemini,
             model: "seed",
             output: %{
               "generated_title" => "Vintage Levi's denim jacket",
               "generated_description" =>
                 "Depop-ready vintage denim piece with timeless blue wash.",
               "generated_tags" => ["vintage", "denim", "streetwear"],
               "generated_price_suggestion" => 90
             }
           }}
        ]
      )

    _sold_product =
      ensure_product!(
        seller,
        %{
          "status" => "sold",
          "source" => "manual",
          "title" => "Nike Air Max 90",
          "brand" => "Nike",
          "category" => "Sneakers",
          "condition" => "Used - Good",
          "color" => "White",
          "size" => "10",
          "material" => "Mesh",
          "price" => "125.00",
          "cost" => "35.00",
          "sku" => "DEMO-SOLD-1",
          "notes" => "Example sold item.",
          "ai_summary" => "White Nike Air Max 90 sneakers.",
          "ai_confidence" => 0.91,
          "sold_at" =>
            DateTime.utc_now() |> DateTime.add(-86_400 * 2, :second) |> DateTime.truncate(:second)
        },
        images: [
          %{
            kind: "original",
            position: 1,
            storage_key: "seed/products/demo-sold-1/original.jpg",
            content_type: "image/jpeg",
            processing_status: "ready",
            original_filename: "demo-sold-1.jpg"
          }
        ]
      )

    _archived_product =
      ensure_product!(
        seller,
        %{
          "status" => "archived",
          "source" => "manual",
          "title" => "Coach Leather Tote",
          "brand" => "Coach",
          "category" => "Bags",
          "condition" => "Used - Fair",
          "color" => "Brown",
          "material" => "Leather",
          "price" => "65.00",
          "cost" => "12.00",
          "sku" => "DEMO-ARCHIVE-1",
          "notes" => "Archived example for local UI state coverage.",
          "archived_at" =>
            DateTime.utc_now() |> DateTime.add(-86_400, :second) |> DateTime.truncate(:second)
        }
      )

    _draft_product =
      ensure_product!(
        seller,
        %{
          "status" => "draft",
          "source" => "manual",
          "title" => "Madewell Sweater",
          "brand" => "Madewell",
          "category" => "Knitwear",
          "condition" => "Used - Good",
          "color" => "Cream",
          "size" => "S",
          "material" => "Wool Blend",
          "price" => "48.00",
          "cost" => "9.00",
          "sku" => "DEMO-DRAFT-1",
          "notes" => "Draft example ready for manual edits."
        }
      )

    IO.puts("""

    Seed data is ready.

    Local credentials:
      Admin:  admin@reseller.local / #{password}
      Seller: seller@reseller.local / #{password}

    Starter products created for seller:
      - #{ready_product.title} (ready)
      - Nike Air Max 90 (sold)
      - Coach Leather Tote (archived)
      - Madewell Sweater (draft)
    """)
  end

  defp ensure_user!(attrs) do
    email = attrs.email

    user =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, user} =
            Accounts.register_user(%{
              "email" => email,
              "password" => attrs.password
            })

          user

        user ->
          user
      end

    if attrs.admin? and not Accounts.admin?(user) do
      {:ok, user} = Accounts.grant_admin(user)
      user
    else
      user
    end
  end

  defp ensure_product!(user, attrs, opts \\ []) do
    sku = attrs["sku"]

    product =
      case Repo.get_by(Product, user_id: user.id, sku: sku) do
        nil ->
          {:ok, %{product: product}} = Catalog.create_product_for_user(user, attrs)
          product

        product ->
          {:ok, product} = Catalog.update_product_for_user(user, product.id, attrs)

          if product.status != attrs["status"] or product.sold_at != attrs["sold_at"] or
               product.archived_at != attrs["archived_at"] do
            {:ok, updated_product} =
              product
              |> Ecto.Changeset.change(
                status: attrs["status"],
                sold_at: attrs["sold_at"],
                archived_at: attrs["archived_at"],
                source: attrs["source"],
                ai_summary: attrs["ai_summary"],
                ai_confidence: attrs["ai_confidence"]
              )
              |> Repo.update()

            updated_product
          else
            product
          end
      end

    product =
      Repo.preload(product, [:images, :description_draft, :price_research, :marketplace_listings])

    Enum.each(Keyword.get(opts, :images, []), fn image_attrs ->
      ensure_product_image!(product, image_attrs)
    end)

    if draft = Keyword.get(opts, :description_draft) do
      {:ok, _draft} = AI.upsert_product_description_draft(product, draft)
    end

    if price_research = Keyword.get(opts, :price_research) do
      {:ok, _price_research} = AI.upsert_product_price_research(product, price_research)
    end

    Enum.each(Keyword.get(opts, :marketplace_listings, []), fn {marketplace, listing_result} ->
      {:ok, _listing} =
        Marketplaces.upsert_marketplace_listing(product, marketplace, listing_result)
    end)

    Repo.preload(product, [:images, :description_draft, :price_research, :marketplace_listings],
      force: true
    )
  end

  defp ensure_product_image!(product, attrs) do
    existing_image =
      Repo.get_by(ProductImage,
        product_id: product.id,
        kind: attrs.kind,
        position: attrs.position
      )

    changeset_attrs = %{
      "kind" => attrs.kind,
      "position" => attrs.position,
      "storage_key" => attrs.storage_key,
      "content_type" => attrs.content_type,
      "processing_status" => attrs.processing_status,
      "background_style" => Map.get(attrs, :background_style),
      "original_filename" => Map.get(attrs, :original_filename)
    }

    case existing_image do
      nil ->
        %ProductImage{}
        |> ProductImage.create_changeset(changeset_attrs)
        |> Ecto.Changeset.put_assoc(:product, product)
        |> Repo.insert!()

      image ->
        image
        |> ProductImage.update_changeset(changeset_attrs)
        |> Repo.update!()
    end
  end
end

Reseller.Seeds.run()
