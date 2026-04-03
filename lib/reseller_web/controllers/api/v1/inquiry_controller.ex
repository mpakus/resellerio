defmodule ResellerWeb.API.V1.InquiryController do
  use ResellerWeb, :controller

  alias Reseller.Storefronts
  alias ResellerWeb.APIError

  def index(conn, params) do
    page = normalize_positive_integer(Map.get(params, "page"), 1)
    page_size = normalize_positive_integer(Map.get(params, "page_size"), 20)
    query = normalize_query(Map.get(params, "q"))

    result =
      Storefronts.list_inquiries_for_user(conn.assigns.current_user,
        page: page,
        page_size: min(page_size, 100),
        query: query
      )

    json(conn, %{
      data: %{
        inquiries: Enum.map(result.entries, &inquiry_json/1),
        pagination: %{
          page: result.page,
          page_size: result.page_size,
          total_count: result.total_count,
          total_pages: result.total_pages
        }
      }
    })
  end

  def delete(conn, %{"id" => id}) do
    case Storefronts.delete_inquiry_for_user(conn.assigns.current_user, id) do
      {:ok, _inquiry} ->
        json(conn, %{data: %{deleted: true}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Inquiry not found")

      {:error, reason} ->
        _ = reason

        APIError.render(
          conn,
          :unprocessable_entity,
          "inquiry_delete_failed",
          "Could not delete inquiry"
        )
    end
  end

  defp inquiry_json(inquiry) do
    %{
      id: inquiry.id,
      full_name: inquiry.full_name,
      contact: inquiry.contact,
      message: inquiry.message,
      source_path: inquiry.source_path,
      product_id: inquiry.product_id,
      inserted_at: datetime_to_iso8601(inquiry.inserted_at)
    }
  end

  defp normalize_positive_integer(nil, default), do: default
  defp normalize_positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp normalize_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> n
      _ -> default
    end
  end

  defp normalize_positive_integer(_, default), do: default

  defp normalize_query(nil), do: nil
  defp normalize_query(""), do: nil
  defp normalize_query(q) when is_binary(q), do: String.trim(q)
  defp normalize_query(_), do: nil

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
end
