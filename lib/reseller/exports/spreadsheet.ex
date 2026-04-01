defmodule Reseller.Exports.Spreadsheet do
  @moduledoc """
  Builds an Excel-compatible XML workbook for exported products.
  """

  alias Reseller.Exports.Export

  @spec build_workbook(Export.t(), map()) :: binary()
  def build_workbook(%Export{} = export, %{"products" => products} = manifest) do
    [
      ~s(<?xml version="1.0"?>),
      ~s(<?mso-application progid="Excel.Sheet"?>),
      ~s(<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" ),
      ~s(xmlns:o="urn:schemas-microsoft-com:office:office" ),
      ~s(xmlns:x="urn:schemas-microsoft-com:office:excel" ),
      ~s(xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet" ),
      ~s(xmlns:html="http://www.w3.org/TR/REC-html40">),
      styles_xml(),
      worksheet_xml("Export", export_headers(), [export_row(export, manifest)]),
      worksheet_xml("Products", product_headers(), Enum.map(products, &product_row/1)),
      "</Workbook>"
    ]
    |> IO.iodata_to_binary()
  end

  @spec build_products_workbook([map()]) :: binary()
  def build_products_workbook(product_payloads) do
    [
      ~s(<?xml version="1.0"?>),
      ~s(<?mso-application progid="Excel.Sheet"?>),
      ~s(<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" ),
      ~s(xmlns:o="urn:schemas-microsoft-com:office:office" ),
      ~s(xmlns:x="urn:schemas-microsoft-com:office:excel" ),
      ~s(xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet" ),
      ~s(xmlns:html="http://www.w3.org/TR/REC-html40">),
      styles_xml(),
      worksheet_xml("Products", product_headers(), Enum.map(product_payloads, &product_row/1)),
      "</Workbook>"
    ]
    |> IO.iodata_to_binary()
  end

  defp styles_xml do
    [
      "<Styles>",
      ~s(<Style ss:ID="header"><Font ss:Bold="1"/></Style>),
      "</Styles>"
    ]
  end

  defp export_headers do
    Enum.map(export_columns(), fn {header, _fun} -> header end)
  end

  defp export_row(export, manifest) do
    Enum.map(export_columns(), fn {_header, fun} -> fun.(export, manifest) end)
  end

  defp product_headers do
    Enum.map(product_columns(), fn {header, _fun} -> header end)
  end

  defp product_row(product_payload) do
    Enum.map(product_columns(), fn {_header, fun} -> fun.(product_payload) end)
  end

  defp product_columns do
    [
      {"Product ID", & &1["id"]},
      {"Title", & &1["title"]},
      {"Status", & &1["status"]},
      {"Brand", & &1["brand"]},
      {"Category", & &1["category"]},
      {"Condition", & &1["condition"]},
      {"Color", & &1["color"]},
      {"Size", & &1["size"]},
      {"Material", & &1["material"]},
      {"Price", & &1["price"]},
      {"Cost", & &1["cost"]},
      {"SKU", & &1["sku"]},
      {"Source", & &1["source"]},
      {"Tags", fn payload -> join_values(payload["tags"]) end},
      {"Notes", & &1["notes"]},
      {"AI Summary", & &1["ai_summary"]},
      {"AI Confidence", & &1["ai_confidence"]},
      {"Sold At", & &1["sold_at"]},
      {"Archived At", & &1["archived_at"]},
      {"Created At", & &1["inserted_at"]},
      {"Updated At", & &1["updated_at"]},
      {"Image Names", &image_names/1},
      {"Image Paths", &image_paths/1},
      {"Description Title",
       fn payload -> get_in(payload, ["description_draft", "suggested_title"]) end},
      {"Description Short",
       fn payload -> get_in(payload, ["description_draft", "short_description"]) end},
      {"Description Long",
       fn payload -> get_in(payload, ["description_draft", "long_description"]) end},
      {"Price Currency", fn payload -> get_in(payload, ["price_research", "currency"]) end},
      {"Price Target",
       fn payload -> get_in(payload, ["price_research", "suggested_target_price"]) end},
      {"Price Rationale",
       fn payload -> get_in(payload, ["price_research", "rationale_summary"]) end},
      {"Marketplace Count", fn payload -> length(List.wrap(payload["marketplace_listings"])) end},
      {"Marketplace Listings JSON",
       fn payload -> json_value(payload["marketplace_listings"]) end},
      {"Description Draft JSON", fn payload -> json_value(payload["description_draft"]) end},
      {"Price Research JSON", fn payload -> json_value(payload["price_research"]) end},
      {"Images JSON", fn payload -> json_value(payload["images"]) end}
    ]
  end

  defp export_columns do
    [
      {"Export ID", fn export, _manifest -> export.id end},
      {"Name", fn export, _manifest -> export.name end},
      {"Archive Filename", fn export, _manifest -> export.file_name end},
      {"Requested At",
       fn export, _manifest -> export.requested_at && DateTime.to_iso8601(export.requested_at) end},
      {"Product Count", fn _export, manifest -> get_in(manifest, ["export", "product_count"]) end}
    ]
  end

  defp worksheet_xml(name, headers, rows) do
    [
      ~s(<Worksheet ss:Name="#{xml_escape(name)}"><Table>),
      row_xml(headers, "header"),
      Enum.map(rows, &row_xml(&1, nil)),
      "</Table></Worksheet>"
    ]
  end

  defp row_xml(cells, style_id) do
    [
      "<Row>",
      Enum.map(cells, fn cell -> cell_xml(cell, style_id) end),
      "</Row>"
    ]
  end

  defp cell_xml(value, "header") do
    ~s(<Cell ss:StyleID="header"><Data ss:Type="String">#{xml_escape(to_string(value))}</Data></Cell>)
  end

  defp cell_xml(value, _style_id) when is_integer(value) do
    ~s(<Cell><Data ss:Type="Number">#{value}</Data></Cell>)
  end

  defp cell_xml(value, _style_id) do
    ~s(<Cell><Data ss:Type="String">#{xml_escape(string_value(value))}</Data></Cell>)
  end

  defp image_names(product_payload) do
    product_payload
    |> Map.get("images", [])
    |> Enum.map(&Map.get(&1, "filename"))
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp image_paths(product_payload) do
    product_payload
    |> Map.get("images", [])
    |> Enum.map(&Map.get(&1, "path"))
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp join_values(nil), do: nil
  defp join_values(values) when is_list(values), do: Enum.join(values, ", ")
  defp join_values(value), do: string_value(value)

  defp json_value(nil), do: nil
  defp json_value(value), do: Jason.encode!(value)

  defp string_value(nil), do: ""
  defp string_value(value) when is_binary(value), do: value
  defp string_value(value) when is_integer(value), do: Integer.to_string(value)
  defp string_value(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 4)
  defp string_value(true), do: "true"
  defp string_value(false), do: "false"
  defp string_value(value), do: to_string(value)

  defp xml_escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
