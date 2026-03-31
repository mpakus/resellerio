defmodule Reseller.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft uploading processing review ready sold archived)
  @manual_statuses ~w(draft review ready sold archived)

  schema "products" do
    field :status, :string, default: "draft"
    field :source, :string, default: "manual"
    field :title, :string
    field :brand, :string
    field :category, :string
    field :condition, :string
    field :color, :string
    field :size, :string
    field :material, :string
    field :price, :decimal
    field :cost, :decimal
    field :sku, :string
    field :tags, {:array, :string}, default: []
    field :notes, :string
    field :ai_summary, :string
    field :ai_confidence, :float
    field :sold_at, :utc_datetime
    field :archived_at, :utc_datetime

    belongs_to :user, Reseller.Accounts.User
    belongs_to :product_tab, Reseller.Catalog.ProductTab
    has_many :images, Reseller.Media.ProductImage, preload_order: [asc: :position, asc: :id]
    has_one :description_draft, Reseller.AI.ProductDescriptionDraft
    has_one :price_research, Reseller.AI.ProductPriceResearch

    has_many :marketplace_listings, Reseller.Marketplaces.MarketplaceListing,
      preload_order: [asc: :marketplace]

    has_many :processing_runs, Reseller.Workers.ProductProcessingRun,
      preload_order: [desc: :inserted_at, desc: :id]

    has_many :lifestyle_generation_runs, Reseller.AI.ProductLifestyleGenerationRun,
      preload_order: [desc: :inserted_at, desc: :id]

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def manual_statuses, do: @manual_statuses

  def create_changeset(product, attrs) do
    attrs = normalize_attrs(attrs)

    product
    |> cast(attrs, [
      :status,
      :source,
      :title,
      :brand,
      :category,
      :condition,
      :color,
      :size,
      :material,
      :price,
      :cost,
      :sku,
      :tags,
      :notes,
      :ai_summary,
      :ai_confidence,
      :sold_at,
      :archived_at,
      :product_tab_id
    ])
    |> validate_required([:status, :source])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:source, ~w(manual mobile import ai))
    |> validate_length(:title, max: 160)
    |> validate_length(:brand, max: 120)
    |> validate_length(:category, max: 120)
    |> validate_length(:condition, max: 80)
    |> validate_length(:color, max: 80)
    |> validate_length(:size, max: 80)
    |> validate_length(:material, max: 120)
    |> validate_length(:sku, max: 120)
    |> validate_tags()
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:cost, greater_than_or_equal_to: 0)
    |> validate_number(:ai_confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> assoc_constraint(:product_tab)
    |> unique_constraint(:sku)
  end

  def update_changeset(product, attrs), do: create_changeset(product, attrs)

  defp normalize_attrs(attrs) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, "tags") -> Map.update!(attrs, "tags", &normalize_tags/1)
      Map.has_key?(attrs, :tags) -> Map.update!(attrs, :tags, &normalize_tags/1)
      true -> attrs
    end
  end

  defp normalize_attrs(attrs), do: attrs

  defp normalize_tags(nil), do: []

  defp normalize_tags(value) when is_binary(value) do
    value
    |> String.split([",", "\n"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_tags(values) when is_list(values) do
    values
    |> Enum.map(fn
      value when is_binary(value) -> String.trim(value)
      value -> to_string(value) |> String.trim()
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_tags(_value), do: []

  defp validate_tags(changeset) do
    changeset
    |> validate_length(:tags, max: 20)
    |> validate_change(:tags, fn :tags, tags ->
      tags
      |> Enum.with_index()
      |> Enum.flat_map(fn {tag, index} ->
        cond do
          String.length(tag) > 40 ->
            [tags: "tag ##{index + 1} must be at most 40 characters"]

          true ->
            []
        end
      end)
    end)
  end
end
