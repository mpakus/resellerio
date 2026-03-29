defmodule Reseller.CatalogFixtures do
  alias Reseller.Catalog

  def product_fixture(user, attrs \\ %{}, uploads \\ []) do
    attrs =
      Enum.into(attrs, %{
        "title" => "Vintage jacket",
        "brand" => "Levi's",
        "category" => "Outerwear"
      })

    case Catalog.create_product_for_user(user, attrs, uploads) do
      {:ok, %{product: product}} ->
        product

      {:error, changeset} ->
        raise "could not create product fixture: #{inspect(changeset.errors)}"
    end
  end
end
