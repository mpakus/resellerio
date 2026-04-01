defmodule ResellerWeb.ProductsExcelController do
  use ResellerWeb, :controller

  alias Reseller.Catalog
  alias Reseller.Exports
  alias Reseller.Exports.Spreadsheet
  alias Reseller.Exports.ZipBuilder

  def download(conn, params) do
    user = conn.assigns.current_user
    filter_params = Exports.normalize_filter_params(params)
    catalog_opts = Exports.filter_params_to_catalog_opts(filter_params)

    products = Catalog.list_filtered_products_for_user(user, catalog_opts)
    product_payloads = Enum.map(products, &ZipBuilder.export_product_payload/1)
    workbook_xml = Spreadsheet.build_products_workbook(product_payloads)

    filename = "products-#{Date.utc_today() |> Date.to_iso8601()}.xls"

    conn
    |> put_resp_content_type("application/vnd.ms-excel")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, workbook_xml)
  end
end
