defmodule Reseller.Marketplaces do
  @moduledoc """
  Handles marketplace-specific generated listing records.
  """

  import Ecto.Query, warn: false

  alias Reseller.Catalog.Product
  alias Reseller.Marketplaces.MarketplaceListing
  alias Reseller.Repo

  @marketplace_catalog [
    %{id: "ebay", label: "eBay"},
    %{id: "depop", label: "Depop"},
    %{id: "poshmark", label: "Poshmark"},
    %{id: "mercari", label: "Mercari"},
    %{id: "facebook_marketplace", label: "Facebook Marketplace"},
    %{id: "offerup", label: "OfferUp"},
    %{id: "whatnot", label: "Whatnot"},
    %{id: "grailed", label: "Grailed"},
    %{id: "therealreal", label: "The RealReal"},
    %{id: "vestiaire_collective", label: "Vestiaire Collective"},
    %{id: "thredup", label: "thredUp"},
    %{id: "etsy", label: "Etsy"}
  ]

  @all_marketplace_ids Enum.map(@marketplace_catalog, & &1.id)
  @marketplace_labels Map.new(@marketplace_catalog, &{&1.id, &1.label})

  @spec catalog(keyword()) :: [map()]
  def catalog(opts \\ []) do
    supported_ids = supported_marketplaces(opts)
    Enum.filter(@marketplace_catalog, &(&1.id in supported_ids))
  end

  @spec supported_marketplaces(keyword()) :: [String.t()]
  def supported_marketplaces(opts \\ []) do
    opts
    |> Keyword.get(
      :supported_marketplaces,
      Application.fetch_env!(:reseller, __MODULE__)[:supported_marketplaces] ||
        @all_marketplace_ids
    )
    |> normalize_marketplaces(@all_marketplace_ids)
  end

  @spec default_marketplaces(keyword()) :: [String.t()]
  def default_marketplaces(opts \\ []) do
    opts
    |> Keyword.get(
      :default_marketplaces,
      Application.fetch_env!(:reseller, __MODULE__)[:default_marketplaces] ||
        ~w(ebay depop poshmark)
    )
    |> normalize_marketplaces(supported_marketplaces(opts))
  end

  @spec selected_marketplaces(keyword()) :: [String.t()]
  def selected_marketplaces(opts \\ []) do
    marketplaces =
      Keyword.get_lazy(opts, :marketplaces, fn ->
        Keyword.get_lazy(opts, :selected_marketplaces, fn -> default_marketplaces(opts) end)
      end)

    normalize_marketplaces(marketplaces, supported_marketplaces(opts))
  end

  @spec marketplace_label(String.t()) :: String.t()
  def marketplace_label(marketplace) when is_binary(marketplace) do
    Map.get(@marketplace_labels, marketplace, humanize_marketplace(marketplace))
  end

  @spec invalid_marketplaces(term(), [String.t()]) :: [String.t()]
  def invalid_marketplaces(marketplaces, allowed_ids) when is_list(allowed_ids) do
    normalized = normalize_input_marketplaces(marketplaces)
    Enum.reject(normalized, &(&1 in allowed_ids))
  end

  @spec normalize_marketplaces(term(), [String.t()]) :: [String.t()]
  def normalize_marketplaces(marketplaces, allowed_ids \\ @all_marketplace_ids) do
    requested_ids = normalize_input_marketplaces(marketplaces)
    Enum.filter(allowed_ids, &(&1 in requested_ids))
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

  defp normalize_input_marketplaces(nil), do: []

  defp normalize_input_marketplaces(marketplace) when is_binary(marketplace) do
    normalize_input_marketplaces([marketplace])
  end

  defp normalize_input_marketplaces(marketplaces) when is_list(marketplaces) do
    marketplaces
    |> Enum.map(fn
      marketplace when is_binary(marketplace) -> String.trim(marketplace)
      marketplace -> marketplace |> to_string() |> String.trim()
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_input_marketplaces(_marketplaces), do: []

  defp humanize_marketplace(marketplace) do
    marketplace
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
