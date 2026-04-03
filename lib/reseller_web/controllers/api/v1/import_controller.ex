defmodule ResellerWeb.API.V1.ImportController do
  use ResellerWeb, :controller

  alias Reseller.Imports
  alias ResellerWeb.APIError

  def create(conn, %{"import" => import_params}) do
    case Imports.request_import_for_user(conn.assigns.current_user, import_params) do
      {:ok, import_record} ->
        conn
        |> put_status(:accepted)
        |> json(%{data: %{import: import_json(import_record)}})

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "import_failed",
          import_failed_detail(reason)
        )
    end
  end

  def create(conn, _params) do
    APIError.render(conn, :unprocessable_entity, "import_failed", "Import payload is required")
  end

  def show(conn, %{"id" => id}) do
    case Imports.get_import_for_user(conn.assigns.current_user, id) do
      nil ->
        APIError.render(conn, :not_found, "not_found", "Import not found")

      import_record ->
        json(conn, %{data: %{import: import_json(import_record)}})
    end
  end

  defp import_json(import_record) do
    %{
      id: import_record.id,
      status: import_record.status,
      source_filename: import_record.source_filename,
      source_storage_key: import_record.source_storage_key,
      requested_at: datetime_to_iso8601(import_record.requested_at),
      started_at: datetime_to_iso8601(import_record.started_at),
      finished_at: datetime_to_iso8601(import_record.finished_at),
      total_products: import_record.total_products,
      imported_products: import_record.imported_products,
      failed_products: import_record.failed_products,
      error_message: import_record.error_message,
      failure_details: import_record.failure_details || %{},
      payload: import_record.payload || %{},
      inserted_at: datetime_to_iso8601(import_record.inserted_at),
      updated_at: datetime_to_iso8601(import_record.updated_at)
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp import_failed_detail(:archive_too_many_entries),
    do: "Could not start import: archive contains too many files"

  defp import_failed_detail(:invalid_archive_entry_path),
    do: "Could not start import: archive contains an invalid file path"

  defp import_failed_detail(:archive_entry_too_large),
    do: "Could not start import: archive contains a file that exceeds the allowed size"

  defp import_failed_detail(:archive_uncompressed_size_exceeded),
    do: "Could not start import: archive is too large after extraction"

  defp import_failed_detail(_reason), do: "Could not start import"
end
