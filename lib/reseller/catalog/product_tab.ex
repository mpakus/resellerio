defmodule Reseller.Catalog.ProductTab do
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_tabs" do
    field :name, :string
    field :position, :integer

    belongs_to :user, Reseller.Accounts.User
    has_many :products, Reseller.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  def create_changeset(product_tab, attrs) do
    attrs = normalize_attrs(attrs)

    product_tab
    |> cast(attrs, [:name, :position])
    |> validate_required([:name, :position])
    |> validate_length(:name, max: 80)
    |> validate_number(:position, greater_than: 0)
    |> unique_constraint(:name, name: :product_tabs_user_id_name_index)
  end

  def update_changeset(product_tab, attrs), do: create_changeset(product_tab, attrs)

  defp normalize_attrs(attrs) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, "name") -> Map.update!(attrs, "name", &normalize_name/1)
      Map.has_key?(attrs, :name) -> Map.update!(attrs, :name, &normalize_name/1)
      true -> attrs
    end
  end

  defp normalize_attrs(attrs), do: attrs

  defp normalize_name(value) when is_binary(value), do: String.trim(value)
  defp normalize_name(value), do: value
end
