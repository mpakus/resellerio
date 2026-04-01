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
    field :external_url, :string
    field :external_url_added_at, :utc_datetime

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
      :last_generated_at,
      :external_url,
      :external_url_added_at
    ])
    |> update_change(:external_url, &normalize_external_url/1)
    |> maybe_put_external_url_added_at()
    |> validate_required([:marketplace, :status, :generated_title, :generated_description])
    |> validate_inclusion(:marketplace, Marketplaces.supported_marketplaces())
    |> validate_inclusion(:status, ~w(generated review failed))
    |> validate_length(:generated_title, max: 160)
    |> validate_length(:external_url, max: 2000)
    |> validate_external_url()
    |> validate_number(:generated_price_suggestion, greater_than_or_equal_to: 0)
    |> unique_constraint([:product_id, :marketplace])
  end

  def update_changeset(listing, attrs), do: create_changeset(listing, attrs)

  defp maybe_put_external_url_added_at(changeset) do
    case fetch_change(changeset, :external_url) do
      {:ok, nil} ->
        put_change(changeset, :external_url_added_at, nil)

      {:ok, _external_url} ->
        case get_change(changeset, :external_url_added_at) || changeset.data.external_url_added_at do
          nil ->
            put_change(
              changeset,
              :external_url_added_at,
              DateTime.utc_now() |> DateTime.truncate(:second)
            )

          _timestamp ->
            changeset
        end

      :error ->
        changeset
    end
  end

  defp validate_external_url(changeset) do
    validate_change(changeset, :external_url, fn :external_url, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host}
        when scheme in ["http", "https"] and is_binary(host) and host != "" ->
          []

        _other ->
          [external_url: "must be a valid http or https URL"]
      end
    end)
  end

  defp normalize_external_url(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_external_url(value), do: value
end
