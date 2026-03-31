defmodule Reseller.AI.ScenePlanner do
  @apparel_keywords ~w(
    apparel accessory accessories blazer blouse boots cardigan coat clothing denim dress
    footwear handbag hat heels hoodie jacket jeans jumpsuit loafers outerwear pants purse
    sandals shirt shoes shorts skirt sneakers suit sweater sweatshirt tee top trousers
  )
  @furniture_keywords ~w(
    armchair bench bookshelf cabinet chair coffee decor desk dresser furniture lamp mirror
    ottoman shelf sideboard sofa stool table vase
  )
  @electronics_keywords ~w(
    camera charger console controller earbuds electronics headphone ipad iphone keyboard laptop
    lens monitor mouse phone speaker tablet tv watch
  )

  @spec scene_family(map()) :: String.t()
  def scene_family(attrs) when is_map(attrs) do
    haystack =
      attrs
      |> searchable_text()
      |> String.downcase()

    cond do
      contains_keyword?(haystack, @apparel_keywords) -> "apparel"
      contains_keyword?(haystack, @furniture_keywords) -> "furniture"
      contains_keyword?(haystack, @electronics_keywords) -> "electronics"
      true -> "general"
    end
  end

  @spec scene_templates(String.t()) :: [map()]
  def scene_templates("apparel") do
    [
      %{
        scene_key: "model_studio",
        brief: "clean ecommerce-adjacent model shot in a bright editorial studio"
      },
      %{
        scene_key: "casual_lifestyle",
        brief:
          "believable everyday lifestyle scene with natural daylight and minimal distractions"
      },
      %{
        scene_key: "styled_detail",
        brief: "alternate styling angle that keeps the product dominant and unobstructed"
      }
    ]
  end

  def scene_templates("furniture") do
    [
      %{
        scene_key: "hero_room",
        brief: "realistic hero room placement with the product as the focal furnishing"
      },
      %{
        scene_key: "alternate_room",
        brief: "second believable interior context with restrained supporting decor"
      },
      %{
        scene_key: "styled_detail",
        brief: "closer editorial room styling scene that still preserves scale and proportions"
      }
    ]
  end

  def scene_templates("electronics") do
    [
      %{
        scene_key: "desk_setup",
        brief: "realistic home or studio desk setup showing the item in natural use context"
      },
      %{
        scene_key: "in_use_context",
        brief: "everyday-use scene that keeps visible controls, ports, and branding accurate"
      },
      %{
        scene_key: "premium_editorial",
        brief: "clean premium product-ad style environment without misleading accessories"
      }
    ]
  end

  def scene_templates(_scene_family) do
    [
      %{
        scene_key: "contextual_hero",
        brief: "clean contextual hero scene where the item is the main subject"
      },
      %{
        scene_key: "alternate_context",
        brief: "second believable real-world setting with secondary background elements only"
      },
      %{
        scene_key: "editorial_clean",
        brief: "premium editorial scene with restrained styling and realistic lighting"
      }
    ]
  end

  defp searchable_text(attrs) do
    [
      value(attrs, "title"),
      value(attrs, "brand"),
      value(attrs, "category"),
      value(attrs, "ai_summary"),
      value(attrs, "item_type"),
      get_in(attrs, ["recognition", "category"]),
      get_in(attrs, ["recognition", "subcategory"]),
      get_in(attrs, ["recognition", "item_type"])
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end

  defp value(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, existing_atom(key))
  rescue
    ArgumentError -> Map.get(attrs, key)
  end

  defp existing_atom(key), do: String.to_existing_atom(key)

  defp contains_keyword?(haystack, keywords) do
    Enum.any?(keywords, &String.contains?(haystack, &1))
  end
end
