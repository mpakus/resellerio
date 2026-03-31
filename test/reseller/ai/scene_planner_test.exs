defmodule Reseller.AI.ScenePlannerTest do
  use ExUnit.Case, async: true

  alias Reseller.AI.ScenePlanner

  test "detects apparel categories" do
    assert ScenePlanner.scene_family(%{"category" => "Sneakers", "title" => "Nike runners"}) ==
             "apparel"
  end

  test "detects furniture categories" do
    assert ScenePlanner.scene_family(%{"category" => "Coffee Table"}) == "furniture"
  end

  test "falls back to general when no category keywords match" do
    assert ScenePlanner.scene_family(%{"category" => "Collectible Figure"}) == "general"
  end
end
