defmodule ResellerWeb.PageTitle do
  @moduledoc """
  Shared browser-title helpers for the web interface.
  """

  @app_title "Resellio - AI Inventory for Resellers"

  def default_title, do: @app_title

  def build(section, breadcrumbs) do
    [section, breadcrumbs, @app_title]
    |> Enum.reject(&blank?/1)
    |> Enum.join(" - ")
  end

  defp blank?(value), do: value in [nil, ""]
end
