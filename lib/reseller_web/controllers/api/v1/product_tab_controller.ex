defmodule ResellerWeb.API.V1.ProductTabController do
  use ResellerWeb, :controller

  alias Reseller.Catalog
  alias ResellerWeb.APIError

  def index(conn, _params) do
    product_tabs = Catalog.list_product_tabs_for_user(conn.assigns.current_user)
    json(conn, %{data: %{product_tabs: Enum.map(product_tabs, &product_tab_json/1)}})
  end

  def create(conn, %{"product_tab" => product_tab_params}) when is_map(product_tab_params) do
    case Catalog.create_product_tab_for_user(conn.assigns.current_user, product_tab_params) do
      {:ok, product_tab} ->
        conn
        |> put_status(:created)
        |> json(%{data: %{product_tab: product_tab_json(product_tab)}})

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "product_tab_create_failed",
          "Could not create product tab: #{inspect(reason)}"
        )
    end
  end

  def create(conn, _params) do
    APIError.render(conn, :bad_request, "invalid_request", "product_tab payload is required")
  end

  def update(conn, %{"id" => id, "product_tab" => product_tab_params})
      when is_map(product_tab_params) do
    case Catalog.update_product_tab_for_user(conn.assigns.current_user, id, product_tab_params) do
      {:ok, product_tab} ->
        json(conn, %{data: %{product_tab: product_tab_json(product_tab)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product tab not found")

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "product_tab_update_failed",
          "Could not update product tab: #{inspect(reason)}"
        )
    end
  end

  def update(conn, _params) do
    APIError.render(conn, :bad_request, "invalid_request", "product_tab payload is required")
  end

  defp product_tab_json(product_tab) do
    %{
      id: product_tab.id,
      name: product_tab.name,
      position: product_tab.position,
      inserted_at: datetime_to_iso8601(product_tab.inserted_at),
      updated_at: datetime_to_iso8601(product_tab.updated_at)
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
end
