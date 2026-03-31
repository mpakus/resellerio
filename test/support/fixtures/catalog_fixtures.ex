defmodule Reseller.CatalogFixtures do
  alias Reseller.Catalog

  def product_tab_fixture(user, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "name" => "Default tab"
      })

    case Catalog.create_product_tab_for_user(user, attrs) do
      {:ok, product_tab} ->
        product_tab

      {:error, changeset} ->
        raise "could not create product tab fixture: #{inspect(changeset.errors)}"
    end
  end

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
