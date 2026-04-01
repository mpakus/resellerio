defmodule Reseller.Storefronts.ThemePresets do
  @moduledoc """
  Curated storefront theme presets.
  """

  @default_id "desert-clay"

  @spec all() :: [map()]
  def all do
    [
      %{
        id: "desert-clay",
        label: "Desert Clay",
        colors:
          preset_colors(
            "#f6ecdc",
            "#fff9f0",
            "#34261b",
            "#7c6654",
            "#a45d3b",
            "#d4a373",
            "#deccb7",
            "rgba(52, 38, 27, 0.48)"
          )
      },
      %{
        id: "linen-ink",
        label: "Linen Ink",
        colors:
          preset_colors(
            "#f7f2e9",
            "#fffaf4",
            "#1f1f1d",
            "#665b50",
            "#b06c3b",
            "#d29b66",
            "#ded2c4",
            "rgba(31, 31, 29, 0.44)"
          )
      },
      %{
        id: "olive-studio",
        label: "Olive Studio",
        colors:
          preset_colors(
            "#f3f1e8",
            "#fcfaf4",
            "#2e3828",
            "#66715d",
            "#657244",
            "#9ca36d",
            "#d5d2c4",
            "rgba(46, 56, 40, 0.45)"
          )
      },
      %{
        id: "market-blue",
        label: "Market Blue",
        colors:
          preset_colors(
            "#f4efe6",
            "#fff9f0",
            "#21324f",
            "#6c7280",
            "#9b4f32",
            "#cc8962",
            "#ddd3c7",
            "rgba(33, 50, 79, 0.45)"
          )
      },
      %{
        id: "terracotta-paper",
        label: "Terracotta Paper",
        colors:
          preset_colors(
            "#f8efe8",
            "#fffaf5",
            "#3c2418",
            "#7a6256",
            "#b85c38",
            "#df9b7c",
            "#e4d1c6",
            "rgba(60, 36, 24, 0.45)"
          )
      },
      %{
        id: "forest-canvas",
        label: "Forest Canvas",
        colors:
          preset_colors(
            "#eff1ea",
            "#f8fbf4",
            "#1f3528",
            "#627163",
            "#2f6b4f",
            "#7f9b70",
            "#d0d9cf",
            "rgba(31, 53, 40, 0.46)"
          )
      },
      %{
        id: "coastal-sand",
        label: "Coastal Sand",
        colors:
          preset_colors(
            "#eef2f1",
            "#fbf7ef",
            "#29485c",
            "#6b7d86",
            "#8b6f52",
            "#b89a79",
            "#d5d9d8",
            "rgba(41, 72, 92, 0.42)"
          )
      },
      %{
        id: "coral-oat",
        label: "Coral Oat",
        colors:
          preset_colors(
            "#fbf0ea",
            "#fff8f2",
            "#4a2f28",
            "#836960",
            "#cb6c5b",
            "#e7a68b",
            "#ead7ce",
            "rgba(74, 47, 40, 0.42)"
          )
      },
      %{
        id: "denim-pine",
        label: "Denim Pine",
        colors:
          preset_colors(
            "#eef1f5",
            "#f8fbfc",
            "#21384d",
            "#617282",
            "#315547",
            "#709684",
            "#d3dbe3",
            "rgba(33, 56, 77, 0.45)"
          )
      },
      %{
        id: "espresso-cream",
        label: "Espresso Cream",
        colors:
          preset_colors(
            "#f6efe7",
            "#fffbf4",
            "#2b1c16",
            "#6d5a51",
            "#7e4d2f",
            "#b78a53",
            "#ddd0c2",
            "rgba(43, 28, 22, 0.48)"
          )
      },
      %{
        id: "stone-berry",
        label: "Stone Berry",
        colors:
          preset_colors(
            "#f2efeb",
            "#fbf8f3",
            "#332e31",
            "#736a70",
            "#8d4055",
            "#c58a9d",
            "#d8d2d3",
            "rgba(51, 46, 49, 0.46)"
          )
      },
      %{
        id: "slate-gold",
        label: "Slate Gold",
        colors:
          preset_colors(
            "#eef0f2",
            "#faf7ef",
            "#28323c",
            "#69747d",
            "#a8822c",
            "#d1b25a",
            "#d1d7dc",
            "rgba(40, 50, 60, 0.46)"
          )
      },
      %{
        id: "sage-sunlight",
        label: "Sage Sunlight",
        colors:
          preset_colors(
            "#f2f4ea",
            "#fffdf4",
            "#394636",
            "#73806f",
            "#8b9a4a",
            "#d6b94f",
            "#d8dccb",
            "rgba(57, 70, 54, 0.42)"
          )
      },
      %{
        id: "brick-navy",
        label: "Brick Navy",
        colors:
          preset_colors(
            "#f4eee7",
            "#fffaf2",
            "#1f3450",
            "#6b7280",
            "#984b3c",
            "#c98668",
            "#dad1c9",
            "rgba(31, 52, 80, 0.45)"
          )
      },
      %{
        id: "sea-glass",
        label: "Sea Glass",
        colors:
          preset_colors(
            "#ecf3f1",
            "#fbfaf6",
            "#234847",
            "#67807d",
            "#2d8a7c",
            "#8bbeb6",
            "#d0ddda",
            "rgba(35, 72, 71, 0.42)"
          )
      },
      %{
        id: "graphite-mint",
        label: "Graphite Mint",
        colors:
          preset_colors(
            "#eef0f1",
            "#fdfdfc",
            "#20272b",
            "#667075",
            "#57a18d",
            "#9ed5c5",
            "#d2d7da",
            "rgba(32, 39, 43, 0.46)"
          )
      },
      %{
        id: "rust-cedar",
        label: "Rust Cedar",
        colors:
          preset_colors(
            "#f6efe9",
            "#fff9f3",
            "#3a2a24",
            "#786660",
            "#a85532",
            "#c78458",
            "#ddd0c6",
            "rgba(58, 42, 36, 0.45)"
          )
      },
      %{
        id: "meadow-canvas",
        label: "Meadow Canvas",
        colors:
          preset_colors(
            "#eef3eb",
            "#fbfaf4",
            "#2d3c2e",
            "#657465",
            "#5a7f45",
            "#95b072",
            "#d2dbcf",
            "rgba(45, 60, 46, 0.44)"
          )
      },
      %{
        id: "dusk-copper",
        label: "Dusk Copper",
        colors:
          preset_colors(
            "#eef0f5",
            "#fbf9f3",
            "#2e3c5b",
            "#6d768b",
            "#b36844",
            "#d29a75",
            "#d4d9e4",
            "rgba(46, 60, 91, 0.45)"
          )
      },
      %{
        id: "cobalt-paper",
        label: "Cobalt Paper",
        colors:
          preset_colors(
            "#eef2fa",
            "#fffdf7",
            "#1d3f8a",
            "#69758f",
            "#c55a2d",
            "#dd8a5e",
            "#d5dced",
            "rgba(29, 63, 138, 0.42)"
          )
      }
    ]
  end

  @spec ids() :: [String.t()]
  def ids, do: Enum.map(all(), & &1.id)

  @spec default_id() :: String.t()
  def default_id, do: @default_id

  @spec fetch(String.t()) :: {:ok, map()} | :error
  def fetch(theme_id) when is_binary(theme_id) do
    case Enum.find(all(), &(&1.id == theme_id)) do
      nil -> :error
      preset -> {:ok, preset}
    end
  end

  def fetch(_theme_id), do: :error

  @spec valid_id?(term()) :: boolean()
  def valid_id?(theme_id) when is_binary(theme_id), do: match?({:ok, _preset}, fetch(theme_id))
  def valid_id?(_theme_id), do: false

  defp preset_colors(
         page_background,
         surface_background,
         text,
         muted_text,
         primary_button,
         secondary_accent,
         border,
         hero_overlay
       ) do
    %{
      page_background: page_background,
      surface_background: surface_background,
      text: text,
      muted_text: muted_text,
      primary_button: primary_button,
      secondary_accent: secondary_accent,
      border: border,
      hero_overlay: hero_overlay
    }
  end
end
