defmodule Reseller.AI.LifestylePromptBuilderTest do
  use ExUnit.Case, async: true

  alias Reseller.AI.LifestylePromptBuilder

  test "builds three apparel scene prompts with required rules" do
    prompts =
      LifestylePromptBuilder.build(%{
        "title" => "Nike Air Max 90",
        "brand" => "Nike",
        "category" => "Sneakers",
        "color" => "White",
        "material" => "Mesh"
      })

    assert Enum.map(prompts, & &1["scene_key"]) == [
             "model_studio",
             "casual_lifestyle",
             "styled_detail"
           ]

    assert Enum.all?(prompts, &(&1["scene_family"] == "apparel"))
    assert Enum.all?(prompts, &(&1["prompt_version"] == "v1"))
    assert Enum.all?(prompts, &(&1["aspect_ratio"] == "4:5"))
    assert hd(prompts)["prompt"] =~ "keep the uploaded item as the main subject"
    assert hd(prompts)["prompt"] =~ "generic person or model"
  end

  test "respects a custom scene count" do
    prompts = LifestylePromptBuilder.build(%{"category" => "Lamp"}, scene_count: 2)

    assert length(prompts) == 2
    assert Enum.map(prompts, & &1["scene_key"]) == ["hero_room", "alternate_room"]
  end
end
