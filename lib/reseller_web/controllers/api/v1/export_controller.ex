defmodule ResellerWeb.API.V1.ExportController do
  use ResellerWeb, :controller

  alias Reseller.Exports
  alias ResellerWeb.APIError

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
      status: export.status,
      storage_key: export.storage_key,
      download_url:
        export.storage_key && Reseller.Media.public_url_for_storage_key!(export.storage_key),
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
end
