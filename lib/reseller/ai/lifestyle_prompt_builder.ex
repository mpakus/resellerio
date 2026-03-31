defmodule Reseller.AI.LifestylePromptBuilder do
  alias Reseller.AI.ScenePlanner

  @default_aspect_ratio "4:5"
  @prompt_version "v1"
  @required_rules [
    "keep the uploaded item as the main subject",
    "preserve visible color, silhouette, logos, and distinctive details",
    "do not add visible text overlays, labels, or price tags",
    "do not invent included accessories unless they are visible in the source images",
    "do not exaggerate condition, material quality, or scale",
    "produce a realistic lifestyle scene appropriate for the product type"
  ]

  @spec build(map(), keyword()) :: [map()]
  def build(attrs, opts \\ []) when is_map(attrs) do
    scene_family = ScenePlanner.scene_family(attrs)
    aspect_ratio = Keyword.get(opts, :aspect_ratio, @default_aspect_ratio)
    scene_count = Keyword.get(opts, :scene_count, 3)

    scene_family
    |> ScenePlanner.scene_templates()
    |> Enum.take(scene_count)
    |> Enum.with_index(1)
    |> Enum.map(fn {scene, index} ->
      %{
        "scene_family" => scene_family,
        "scene_key" => scene.scene_key,
        "scene_brief" => scene.brief,
        "variant_index" => index,
        "prompt_version" => @prompt_version,
        "aspect_ratio" => aspect_ratio,
        "negative_rules" => @required_rules,
        "prompt" => render_prompt(attrs, scene_family, scene.brief)
      }
    end)
  end

  def prompt_version, do: @prompt_version

  defp render_prompt(attrs, scene_family, scene_brief) do
    product_facts =
      attrs
      |> fact_lines()
      |> Enum.map_join("\n", &("- " <> &1))

    category_rules =
      scene_family
      |> category_rules()
      |> Enum.map_join("\n", &("- " <> &1))

    required_rules =
      @required_rules
      |> Enum.map_join("\n", &("- " <> &1))

    """
    Create one photorealistic AI-generated lifestyle preview image for a resale product.
    The image is illustrative marketing media and must stay faithful to the uploaded item.

    Scene family: #{scene_family}
    Scene brief: #{scene_brief}

    Product facts:
    #{product_facts}

    Required rules:
    #{required_rules}

    Category-specific rules:
    #{category_rules}

    Return image output only.
    """
    |> String.trim()
  end

  defp fact_lines(attrs) do
    [
      {"Title", fetch(attrs, "title")},
      {"Brand", fetch(attrs, "brand")},
      {"Category", fetch(attrs, "category")},
      {"Condition", fetch(attrs, "condition")},
      {"Color", fetch(attrs, "color")},
      {"Material", fetch(attrs, "material")},
      {"AI summary", fetch(attrs, "ai_summary")}
    ]
    |> Enum.flat_map(fn
      {label, value} when is_binary(value) and value != "" -> ["#{label}: #{value}"]
      _ -> []
    end)
  end

  defp category_rules("apparel") do
    [
      "place the item on a generic person or model in a believable outfit context",
      "do not cover the product with other garments",
      "keep faces generic and non-identifying"
    ]
  end

  defp category_rules("furniture") do
    [
      "place the item in a realistic room matching the item type",
      "keep surrounding furniture secondary",
      "preserve proportions and dominant materials"
    ]
  end

  defp category_rules("electronics") do
    [
      "place the item in a believable work, home, or desk environment",
      "preserve ports, buttons, screens, and brand marks when visible",
      "do not imply unsupported functionality"
    ]
  end

  defp category_rules(_scene_family) do
    [
      "create a believable real-world scene that keeps the product dominant",
      "use realistic lighting and restrained supporting objects",
      "avoid changing shape, condition, or visible included items"
    ]
  end

  defp fetch(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, existing_atom(key))
  rescue
    ArgumentError -> Map.get(attrs, key)
  end

  defp existing_atom(key), do: String.to_existing_atom(key)
end
