defmodule ResellerWeb.WorkspaceNavigation do
  @moduledoc false

  def items(active_section, opts \\ []) do
    default_mode = Keyword.get(opts, :mode, :navigate)
    item_modes = Keyword.get(opts, :item_modes, %{})

    [
      nav_item(:dashboard, "Dashboard", "/app", active_section, default_mode, item_modes),
      nav_item(:products, "Products", "/app/products", active_section, default_mode, item_modes),
      nav_item(:exports, "Exports", "/app/exports", active_section, default_mode, item_modes),
      nav_item(
        :inquiries,
        "Inquiries",
        "/app/inquiries",
        active_section,
        default_mode,
        item_modes
      ),
      nav_item(:settings, "Settings", "/app/settings", active_section, default_mode, item_modes)
    ]
  end

  defp nav_item(section, label, path, active_section, default_mode, item_modes) do
    %{
      label: label,
      path: path,
      active: active_section == section,
      mode: Map.get(item_modes, section, default_mode)
    }
  end
end
