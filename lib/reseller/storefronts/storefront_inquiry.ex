defmodule Reseller.Storefronts.StorefrontInquiry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "storefront_inquiries" do
    field :full_name, :string
    field :contact, :string
    field :message, :string
    field :source_path, :string
    field :requester_ip, :string
    field :user_agent, :string

    belongs_to :storefront, Reseller.Storefronts.Storefront
    belongs_to :product, Reseller.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  def create_changeset(inquiry, attrs), do: changeset(inquiry, attrs)
  def update_changeset(inquiry, attrs), do: changeset(inquiry, attrs)

  defp changeset(inquiry, attrs) do
    inquiry
    |> cast(attrs, [
      :product_id,
      :full_name,
      :contact,
      :message,
      :source_path,
      :requester_ip,
      :user_agent
    ])
    |> update_change(:full_name, &normalize_text/1)
    |> update_change(:contact, &normalize_text/1)
    |> update_change(:message, &normalize_text/1)
    |> update_change(:source_path, &normalize_text/1)
    |> update_change(:requester_ip, &normalize_text/1)
    |> update_change(:user_agent, &normalize_text/1)
    |> validate_required([:full_name, :contact, :message, :source_path])
    |> validate_length(:full_name, max: 120)
    |> validate_length(:contact, max: 200)
    |> validate_length(:message, max: 5000)
    |> validate_length(:source_path, max: 500)
    |> validate_length(:requester_ip, max: 64)
    |> validate_length(:user_agent, max: 500)
    |> assoc_constraint(:storefront)
    |> assoc_constraint(:product)
  end

  defp normalize_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_text(value), do: value
end
