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
      },
      %{
        id: "mulberry-ash",
        label: "Mulberry Ash",
        colors:
          preset_colors(
            "#f3eef5",
            "#fdf8fe",
            "#2e2035",
            "#7a6e80",
            "#7b3f7e",
            "#b87db8",
            "#ddd4e2",
            "rgba(46, 32, 53, 0.46)"
          )
      },
      %{
        id: "indigo-parchment",
        label: "Indigo Parchment",
        colors:
          preset_colors(
            "#eef0f8",
            "#fdfcf7",
            "#252d5c",
            "#6a6f8a",
            "#8b6a2e",
            "#c9a458",
            "#d4d8ec",
            "rgba(37, 45, 92, 0.44)"
          )
      },
      %{
        id: "amber-slate",
        label: "Amber Slate",
        colors:
          preset_colors(
            "#f5f0e8",
            "#fffcf4",
            "#2c3040",
            "#6d7280",
            "#b87228",
            "#dda84e",
            "#dcd8ce",
            "rgba(44, 48, 64, 0.46)"
          )
      },
      %{
        id: "rose-ivory",
        label: "Rose Ivory",
        colors:
          preset_colors(
            "#faf0f0",
            "#fffaf8",
            "#4a2828",
            "#8a6a6a",
            "#c05060",
            "#e0909a",
            "#eedede",
            "rgba(74, 40, 40, 0.44)"
          )
      },
      %{
        id: "pewter-gold",
        label: "Pewter Gold",
        colors:
          preset_colors(
            "#f0f0ec",
            "#fafaf5",
            "#2a2a28",
            "#707068",
            "#9a8030",
            "#c8b058",
            "#d8d8d0",
            "rgba(42, 42, 40, 0.48)"
          )
      },
      %{
        id: "fern-cream",
        label: "Fern Cream",
        colors:
          preset_colors(
            "#f0f5ec",
            "#fbfdf7",
            "#263020",
            "#68786a",
            "#4a7a38",
            "#88b06a",
            "#d2dece",
            "rgba(38, 48, 32, 0.44)"
          )
      },
      %{
        id: "twilight-sand",
        label: "Twilight Sand",
        colors:
          preset_colors(
            "#f2f0f8",
            "#fdfcfe",
            "#2c2848",
            "#706c88",
            "#8a6848",
            "#c0a078",
            "#dcdae8",
            "rgba(44, 40, 72, 0.44)"
          )
      },
      %{
        id: "tangerine-smoke",
        label: "Tangerine Smoke",
        colors:
          preset_colors(
            "#fdf0e8",
            "#fffaf4",
            "#3a2010",
            "#806050",
            "#d05818",
            "#e8904a",
            "#ead0bc",
            "rgba(58, 32, 16, 0.46)"
          )
      },
      %{
        id: "moss-linen",
        label: "Moss Linen",
        colors:
          preset_colors(
            "#f0f2e8",
            "#fbfcf5",
            "#303828",
            "#6a7260",
            "#607040",
            "#90a060",
            "#d4d8ca",
            "rgba(48, 56, 40, 0.44)"
          )
      },
      %{
        id: "iron-rose",
        label: "Iron Rose",
        colors:
          preset_colors(
            "#f2eef0",
            "#fdfbfc",
            "#302028",
            "#786a70",
            "#904858",
            "#c07880",
            "#dcd4d8",
            "rgba(48, 32, 40, 0.46)"
          )
      },
      %{
        id: "teal-parchment",
        label: "Teal Parchment",
        colors:
          preset_colors(
            "#eaf5f3",
            "#fbfef8",
            "#1a3c38",
            "#5a7870",
            "#207868",
            "#58a898",
            "#cce0dc",
            "rgba(26, 60, 56, 0.44)"
          )
      },
      %{
        id: "navy-wheat",
        label: "Navy Wheat",
        colors:
          preset_colors(
            "#eef1f8",
            "#fffef8",
            "#182040",
            "#5a6278",
            "#a07820",
            "#d0ac50",
            "#d4daec",
            "rgba(24, 32, 64, 0.46)"
          )
      },
      %{
        id: "burgundy-fog",
        label: "Burgundy Fog",
        colors:
          preset_colors(
            "#f5eef0",
            "#fdf8f8",
            "#380c18",
            "#7a606a",
            "#903040",
            "#c07080",
            "#e0d0d4",
            "rgba(56, 12, 24, 0.48)"
          )
      },
      %{
        id: "glacier-oak",
        label: "Glacier Oak",
        colors:
          preset_colors(
            "#eef4f8",
            "#fbfefe",
            "#1c3848",
            "#5a7888",
            "#8a6030",
            "#b89060",
            "#d0dce4",
            "rgba(28, 56, 72, 0.44)"
          )
      },
      %{
        id: "copper-mist",
        label: "Copper Mist",
        colors:
          preset_colors(
            "#f4eeec",
            "#fdfaf8",
            "#362820",
            "#7a6860",
            "#c07040",
            "#d8a070",
            "#ddd4d0",
            "rgba(54, 40, 32, 0.46)"
          )
      },
      %{
        id: "plum-grain",
        label: "Plum Grain",
        colors:
          preset_colors(
            "#f2ecf5",
            "#fdf8fe",
            "#2c1838",
            "#7a6080",
            "#6a2870",
            "#a868b0",
            "#ddd0e4",
            "rgba(44, 24, 56, 0.46)"
          )
      },
      %{
        id: "cedar-frost",
        label: "Cedar Frost",
        colors:
          preset_colors(
            "#f0f4f4",
            "#fbfeff",
            "#1e3038",
            "#607078",
            "#8a5028",
            "#b88058",
            "#d0dce0",
            "rgba(30, 48, 56, 0.44)"
          )
      },
      %{
        id: "warm-concrete",
        label: "Warm Concrete",
        colors:
          preset_colors(
            "#f0ece8",
            "#faf8f4",
            "#282420",
            "#706a64",
            "#a87848",
            "#d0a870",
            "#dcd8d0",
            "rgba(40, 36, 32, 0.48)"
          )
      },
      %{
        id: "citrus-dusk",
        label: "Citrus Dusk",
        colors:
          preset_colors(
            "#fdf4e8",
            "#fffdf5",
            "#302008",
            "#807060",
            "#c87808",
            "#e8b040",
            "#eadcc8",
            "rgba(48, 32, 8, 0.46)"
          )
      },
      %{
        id: "storm-clay",
        label: "Storm Clay",
        colors:
          preset_colors(
            "#eef0f4",
            "#fbfcfe",
            "#202838",
            "#606870",
            "#8a6850",
            "#b89878",
            "#d4d8e0",
            "rgba(32, 40, 56, 0.46)"
          )
      },
      %{
        id: "pine-amber",
        label: "Pine Amber",
        colors:
          preset_colors(
            "#edf2e8",
            "#fbfdf5",
            "#1e2e18",
            "#5c6c58",
            "#a07018",
            "#d0a840",
            "#ccd8c8",
            "rgba(30, 46, 24, 0.46)"
          )
      },
      %{
        id: "charcoal-blush",
        label: "Charcoal Blush",
        colors:
          preset_colors(
            "#f0eeed",
            "#fdfcfb",
            "#202020",
            "#706868",
            "#b05870",
            "#d898a0",
            "#ddd8d8",
            "rgba(32, 32, 32, 0.48)"
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
