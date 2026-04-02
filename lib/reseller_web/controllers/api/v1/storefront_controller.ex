defmodule ResellerWeb.API.V1.StorefrontController do
  use ResellerWeb, :controller

  alias Reseller.Storefronts
  alias ResellerWeb.APIError

  def show(conn, _params) do
    storefront = Storefronts.get_or_build_storefront_for_user(conn.assigns.current_user)
    json(conn, %{data: %{storefront: storefront_json(storefront)}})
  end

  def upsert(conn, %{"storefront" => storefront_params}) when is_map(storefront_params) do
    case Storefronts.upsert_storefront_for_user(conn.assigns.current_user, storefront_params) do
      {:ok, storefront} ->
        json(conn, %{data: %{storefront: storefront_json(storefront)}})

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "storefront_upsert_failed",
          "Could not save storefront: #{inspect(reason)}"
        )
    end
  end

  def upsert(conn, _params) do
    APIError.render(conn, :bad_request, "invalid_request", "storefront payload is required")
  end

  def list_pages(conn, _params) do
    pages = Storefronts.list_storefront_pages_for_user(conn.assigns.current_user)
    json(conn, %{data: %{pages: Enum.map(pages, &page_json/1)}})
  end

  def create_page(conn, %{"page" => page_params}) when is_map(page_params) do
    case Storefronts.create_storefront_page_for_user(conn.assigns.current_user, page_params) do
      {:ok, page} ->
        conn
        |> put_status(:created)
        |> json(%{data: %{page: page_json(page)}})

      {:error, :storefront_not_found} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "storefront_not_found",
          "Save storefront details before creating pages"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "page_create_failed",
          "Could not create page: #{inspect(reason)}"
        )
    end
  end

  def create_page(conn, _params) do
    APIError.render(conn, :bad_request, "invalid_request", "page payload is required")
  end

  def update_page(conn, %{"page_id" => page_id, "page" => page_params})
      when is_map(page_params) do
    case Storefronts.update_storefront_page_for_user(
           conn.assigns.current_user,
           page_id,
           page_params
         ) do
      {:ok, page} ->
        json(conn, %{data: %{page: page_json(page)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Storefront page not found")

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "page_update_failed",
          "Could not update page: #{inspect(reason)}"
        )
    end
  end

  def update_page(conn, _params) do
    APIError.render(conn, :bad_request, "invalid_request", "page payload is required")
  end

  def delete_page(conn, %{"page_id" => page_id}) do
    case Storefronts.delete_storefront_page_for_user(conn.assigns.current_user, page_id) do
      {:ok, _page} ->
        json(conn, %{data: %{deleted: true}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Storefront page not found")

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "page_delete_failed",
          "Could not delete page: #{inspect(reason)}"
        )
    end
  end

  def reorder_pages(conn, %{"page_ids" => page_ids}) when is_list(page_ids) do
    parsed_ids = Enum.map(page_ids, &parse_integer/1) |> Enum.reject(&is_nil/1)

    case Storefronts.reorder_storefront_pages_for_user(conn.assigns.current_user, parsed_ids) do
      {:ok, pages} ->
        json(conn, %{data: %{pages: Enum.map(pages, &page_json/1)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Storefront page not found")

      {:error, :invalid_ids} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "reorder_failed",
          "page_ids contains duplicate values"
        )

      {:error, reason} ->
        APIError.render(conn, :unprocessable_entity, "reorder_failed", inspect(reason))
    end
  end

  def reorder_pages(conn, _params) do
    APIError.render(conn, :bad_request, "bad_request", "page_ids must be a list")
  end

  def prepare_asset_upload(conn, %{"kind" => kind, "asset" => asset_params})
      when is_map(asset_params) do
    case Storefronts.prepare_storefront_asset_upload_for_user(
           conn.assigns.current_user,
           kind,
           asset_params
         ) do
      {:ok, %{asset: asset, upload_instruction: upload_instruction}} ->
        json(conn, %{data: %{asset: asset_json(asset), upload_instruction: upload_instruction}})

      {:error, :storefront_not_found} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "storefront_not_found",
          "Save storefront details before uploading branding assets"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, {:missing_config, config_key}} ->
        APIError.render(
          conn,
          :bad_gateway,
          "storage_unavailable",
          "Storage upload signing is not configured: #{humanize_config_key(config_key)}"
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

  def prepare_asset_upload(conn, _params) do
    APIError.render(conn, :bad_request, "invalid_request", "asset payload is required")
  end

  def delete_asset(conn, %{"kind" => kind}) do
    case Storefronts.delete_storefront_asset_for_user(conn.assigns.current_user, kind) do
      {:ok, _asset} ->
        json(conn, %{data: %{deleted: true}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Storefront asset not found")

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "asset_delete_failed",
          "Could not delete asset: #{inspect(reason)}"
        )
    end
  end

  defp storefront_json(storefront) do
    %{
      id: storefront.id,
      slug: storefront.slug,
      title: storefront.title,
      tagline: storefront.tagline,
      description: storefront.description,
      theme_id: storefront.theme_id,
      enabled: storefront.enabled,
      assets: Enum.map(storefront.assets || [], &asset_json/1),
      pages: Enum.map(storefront.pages || [], &page_json/1),
      inserted_at: datetime_to_iso8601(storefront.inserted_at),
      updated_at: datetime_to_iso8601(storefront.updated_at)
    }
  end

  defp page_json(page) do
    %{
      id: page.id,
      title: page.title,
      slug: page.slug,
      menu_label: page.menu_label,
      body: page.body,
      position: page.position,
      published: page.published,
      inserted_at: datetime_to_iso8601(page.inserted_at),
      updated_at: datetime_to_iso8601(page.updated_at)
    }
  end

  defp asset_json(asset) do
    %{
      id: asset.id,
      kind: asset.kind,
      storage_key: asset.storage_key,
      content_type: asset.content_type,
      original_filename: asset.original_filename,
      width: asset.width,
      height: asset.height,
      byte_size: asset.byte_size,
      inserted_at: datetime_to_iso8601(asset.inserted_at),
      updated_at: datetime_to_iso8601(asset.updated_at)
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp humanize_config_key(:access_key_id), do: "TIGRIS_ACCESS_KEY_ID"
  defp humanize_config_key(:secret_access_key), do: "TIGRIS_SECRET_ACCESS_KEY"
  defp humanize_config_key(:base_url), do: "TIGRIS_BUCKET_URL"
  defp humanize_config_key(:bucket_name), do: "TIGRIS_BUCKET_NAME"
  defp humanize_config_key(config_key), do: to_string(config_key)

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_value), do: nil
end
