defmodule ResellerWeb.API.V1.ExportController do
  use ResellerWeb, :controller

  alias Reseller.Catalog
  alias Reseller.Exports
  alias ResellerWeb.APIError

  def create(conn, %{"export" => export_params}) when is_map(export_params) do
    case Exports.request_export_for_user(
           conn.assigns.current_user,
           name: Map.get(export_params, "name"),
           filters:
             normalize_export_filters(
               conn.assigns.current_user,
               Map.get(export_params, "filters", %{})
             )
         ) do
      {:ok, export} ->
        conn
        |> put_status(:accepted)
        |> json(%{data: %{export: export_json(export)}})

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "export_failed",
          "Could not start export: #{inspect(reason)}"
        )
    end
  end

  def create(conn, _params) do
    case Exports.request_export_for_user(conn.assigns.current_user) do
      {:ok, export} ->
        conn
        |> put_status(:accepted)
        |> json(%{data: %{export: export_json(export)}})

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "export_failed",
          "Could not start export: #{inspect(reason)}"
        )
    end
  end

  def show(conn, %{"id" => id}) do
    case Exports.get_export_for_user(conn.assigns.current_user, id) do
      nil ->
        APIError.render(conn, :not_found, "not_found", "Export not found")

      export ->
        json(conn, %{data: %{export: export_json(export)}})
    end
  end

  defp export_json(export) do
    %{
      id: export.id,
      name: export.name,
      file_name: export.file_name,
      filter_params: export.filter_params || %{},
      product_count: export.product_count,
      status: export.status,
      storage_key: export.storage_key,
      download_url: export_download_url(export),
      expires_at: datetime_to_iso8601(export.expires_at),
      requested_at: datetime_to_iso8601(export.requested_at),
      completed_at: datetime_to_iso8601(export.completed_at),
      error_message: export.error_message,
      inserted_at: datetime_to_iso8601(export.inserted_at),
      updated_at: datetime_to_iso8601(export.updated_at)
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp export_download_url(%{storage_key: nil}), do: nil

  defp export_download_url(export) do
    case Exports.download_url(export) do
      {:ok, download_url} -> download_url
      {:error, _reason} -> nil
    end
  end

  defp normalize_export_filters(current_user, filters) when is_map(filters) do
    case Map.get(filters, "product_tab_id") || Map.get(filters, :product_tab_id) do
      nil ->
        filters

      product_tab_id ->
        case Catalog.get_product_tab_for_user(current_user, product_tab_id) do
          nil ->
            filters

          product_tab ->
            filters
            |> Map.put("product_tab_id", product_tab.id)
            |> Map.put_new("product_tab_name", product_tab.name)
        end
    end
  end

  defp normalize_export_filters(_current_user, filters), do: filters
end
