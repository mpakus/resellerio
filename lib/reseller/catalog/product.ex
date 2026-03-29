defmodule Reseller.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

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
    field :notes, :string
    field :ai_summary, :string
    field :ai_confidence, :float
    field :sold_at, :utc_datetime
    field :archived_at, :utc_datetime

    belongs_to :user, Reseller.Accounts.User
    has_many :images, Reseller.Media.ProductImage, preload_order: [asc: :position, asc: :id]
    has_one :description_draft, Reseller.AI.ProductDescriptionDraft

    has_many :processing_runs, Reseller.Workers.ProductProcessingRun,
      preload_order: [desc: :inserted_at, desc: :id]

    timestamps(type: :utc_datetime)
  end

  def create_changeset(product, attrs) do
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
      :notes,
      :ai_summary,
      :ai_confidence,
      :sold_at,
      :archived_at
    ])
    |> validate_required([:status, :source])
    |> validate_inclusion(:status, ~w(draft uploading processing review ready sold archived))
    |> validate_inclusion(:source, ~w(manual mobile import ai))
    |> validate_length(:title, max: 160)
    |> validate_length(:brand, max: 120)
    |> validate_length(:category, max: 120)
    |> validate_length(:condition, max: 80)
    |> validate_length(:color, max: 80)
    |> validate_length(:size, max: 80)
    |> validate_length(:material, max: 120)
    |> validate_length(:sku, max: 120)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:cost, greater_than_or_equal_to: 0)
    |> validate_number(:ai_confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> unique_constraint(:sku)
  end

  def update_changeset(product, attrs), do: create_changeset(product, attrs)
end
