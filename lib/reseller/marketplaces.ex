defmodule Reseller.Marketplaces do
  @moduledoc """
  Handles marketplace-specific generated listing records.
  """

  import Ecto.Query, warn: false

  alias Reseller.Catalog.Product
  alias Reseller.Marketplaces.MarketplaceListing
  alias Reseller.Repo

  @spec supported_marketplaces(keyword()) :: [String.t()]
  def supported_marketplaces(opts \\ []) do
    Keyword.get(
      opts,
      :marketplaces,
      Application.fetch_env!(:reseller, __MODULE__)[:marketplaces]
    )
  end

  @spec list_product_marketplace_listings(pos_integer()) :: [MarketplaceListing.t()]
  def list_product_marketplace_listings(product_id) when is_integer(product_id) do
    MarketplaceListing
    |> where([listing], listing.product_id == ^product_id)
    |> order_by([listing], asc: listing.marketplace)
    |> Repo.all()
  end

  @spec upsert_marketplace_listing(Product.t(), String.t(), map()) ::
          {:ok, MarketplaceListing.t()} | {:error, Ecto.Changeset.t()}
  def upsert_marketplace_listing(%Product{} = product, marketplace, result)
      when is_binary(marketplace) and is_map(result) do
    attrs = listing_attrs(marketplace, result)

    case Repo.get_by(MarketplaceListing, product_id: product.id, marketplace: marketplace) do
      nil ->
        %MarketplaceListing{}
        |> MarketplaceListing.create_changeset(attrs)
        |> Ecto.Changeset.put_assoc(:product, product)
        |> Repo.insert()

      listing ->
        listing
        |> MarketplaceListing.update_changeset(attrs)
        |> Repo.update()
    end
  end

  defp listing_attrs(marketplace, result) do
    output =
      case result do
        %{output: output} when is_map(output) -> output
        %{"output" => output} when is_map(output) -> output
        output when is_map(output) -> output
      end

    %{
      "marketplace" => marketplace,
      "status" =>
        if((output["compliance_warnings"] || []) == [], do: "generated", else: "review"),
      "generated_title" => output["generated_title"],
      "generated_description" => output["generated_description"],
      "generated_tags" => output["generated_tags"] || [],
      "generated_price_suggestion" => output["generated_price_suggestion"],
      "generation_version" => output["generation_version"] || model_name(result),
      "compliance_warnings" => output["compliance_warnings"] || [],
      "raw_payload" => stringify_keys(output),
      "last_generated_at" => DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp model_name(%{model: model}) when is_binary(model), do: model
  defp model_name(%{"model" => model}) when is_binary(model), do: model
  defp model_name(_result), do: nil

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) -> {to_string(key), stringify_keys(value)}
      {key, value} when is_list(value) -> {to_string(key), Enum.map(value, &stringify_value/1)}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp stringify_value(value) when is_map(value), do: stringify_keys(value)
  defp stringify_value(value), do: value
end
