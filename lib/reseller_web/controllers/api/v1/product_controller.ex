defmodule ResellerWeb.API.V1.ProductController do
  use ResellerWeb, :controller

  alias Reseller.Catalog
  alias ResellerWeb.APIError

  def index(conn, _params) do
    products = Catalog.list_products_for_user(conn.assigns.current_user)
    json(conn, %{data: %{products: Enum.map(products, &product_json/1)}})
  end

  def show(conn, %{"id" => id}) do
    case Catalog.get_product_for_user(conn.assigns.current_user, id) do
      nil ->
        APIError.render(conn, :not_found, "not_found", "Product not found")

      product ->
        json(conn, %{data: %{product: product_json(product)}})
    end
  end

  def create(conn, params) do
    product_attrs = Map.get(params, "product", %{})
    uploads = Map.get(params, "uploads", [])

    case Catalog.create_product_for_user(conn.assigns.current_user, product_attrs, uploads) do
      {:ok, %{product: product, upload_bundle: upload_bundle}} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            product: product_json(product),
            upload_instructions: upload_bundle.upload_instructions
          }
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, {:missing_config, config_key}} ->
        APIError.render(
          conn,
          :bad_gateway,
          "storage_unavailable",
          "Storage upload signing is not configured: #{config_key}"
        )

      {:error, reason} ->
        APIError.render(
          conn,
          :bad_gateway,
          "upload_signing_failed",
          "Upload signing failed: #{inspect(reason)}"
        )
    end
  end

  defp product_json(product) do
    %{
      id: product.id,
      status: product.status,
      source: product.source,
      title: product.title,
      brand: product.brand,
      category: product.category,
      condition: product.condition,
      color: product.color,
      size: product.size,
      material: product.material,
      price: decimal_to_string(product.price),
      cost: decimal_to_string(product.cost),
      sku: product.sku,
      notes: product.notes,
      ai_summary: product.ai_summary,
      ai_confidence: product.ai_confidence,
      sold_at: datetime_to_iso8601(product.sold_at),
      archived_at: datetime_to_iso8601(product.archived_at),
      inserted_at: datetime_to_iso8601(product.inserted_at),
      updated_at: datetime_to_iso8601(product.updated_at),
      images: Enum.map(product.images || [], &image_json/1)
    }
  end

  defp image_json(image) do
    %{
      id: image.id,
      kind: image.kind,
      position: image.position,
      storage_key: image.storage_key,
      content_type: image.content_type,
      width: image.width,
      height: image.height,
      byte_size: image.byte_size,
      checksum: image.checksum,
      background_style: image.background_style,
      processing_status: image.processing_status,
      original_filename: image.original_filename,
      inserted_at: datetime_to_iso8601(image.inserted_at),
      updated_at: datetime_to_iso8601(image.updated_at)
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)
end
