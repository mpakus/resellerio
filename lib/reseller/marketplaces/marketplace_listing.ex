defmodule Reseller.Marketplaces.MarketplaceListing do
  use Ecto.Schema
  import Ecto.Changeset

  alias Reseller.Marketplaces

  schema "marketplace_listings" do
    field :marketplace, :string
    field :status, :string, default: "generated"
    field :generated_title, :string
    field :generated_description, :string
    field :generated_tags, {:array, :string}, default: []
    field :generated_price_suggestion, :decimal
    field :generation_version, :string
    field :compliance_warnings, {:array, :string}, default: []
    field :raw_payload, :map, default: %{}
    field :last_generated_at, :utc_datetime

    belongs_to :product, Reseller.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  def create_changeset(listing, attrs) do
    listing
    |> cast(attrs, [
      :marketplace,
      :status,
      :generated_title,
      :generated_description,
      :generated_tags,
      :generated_price_suggestion,
      :generation_version,
      :compliance_warnings,
      :raw_payload,
      :last_generated_at
    ])
    |> validate_required([:marketplace, :status, :generated_title, :generated_description])
    |> validate_inclusion(:marketplace, Marketplaces.supported_marketplaces())
    |> validate_inclusion(:status, ~w(generated review failed))
    |> validate_length(:generated_title, max: 160)
    |> validate_number(:generated_price_suggestion, greater_than_or_equal_to: 0)
    |> unique_constraint([:product_id, :marketplace])
  end

  def update_changeset(listing, attrs), do: create_changeset(listing, attrs)
end
