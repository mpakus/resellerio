defmodule Reseller.AI.ProductDescriptionDraft do
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_description_drafts" do
    field :status, :string, default: "generated"
    field :provider, :string
    field :model, :string
    field :suggested_title, :string
    field :short_description, :string
    field :long_description, :string
    field :key_features, {:array, :string}, default: []
    field :seo_keywords, {:array, :string}, default: []
    field :missing_details_warning, :string
    field :raw_payload, :map, default: %{}

    belongs_to :product, Reseller.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  def create_changeset(draft, attrs) do
    draft
    |> cast(attrs, [
      :status,
      :provider,
      :model,
      :suggested_title,
      :short_description,
      :long_description,
      :key_features,
      :seo_keywords,
      :missing_details_warning,
      :raw_payload
    ])
    |> validate_required([:status, :short_description])
    |> validate_inclusion(:status, ~w(generated review failed))
    |> validate_length(:suggested_title, max: 160)
    |> validate_length(:short_description, max: 500)
    |> validate_length(:missing_details_warning, max: 500)
    |> unique_constraint(:product_id)
  end

  def update_changeset(draft, attrs), do: create_changeset(draft, attrs)
end
