defmodule Reseller.AI.ImageSelectionTest do
  use ExUnit.Case, async: true

  alias Reseller.AI.ImageSelection

  test "selects at most five usable images and keeps an original when available" do
    images = [
      %{
        kind: "original",
        position: 5,
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/5.jpg"
      },
      %{
        kind: "object_crop",
        position: 1,
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/1-crop.jpg"
      },
      %{
        kind: "white_background",
        position: 2,
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/2-white.jpg"
      },
      %{
        kind: "normalized",
        position: 3,
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/3-normalized.jpg"
      },
      %{
        kind: "normalized",
        position: 4,
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/4-normalized.jpg"
      },
      %{
        kind: "object_crop",
        position: 6,
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/6-crop.jpg"
      },
      %{kind: "normalized", position: 7, uri: "https://cdn.example.com/missing-mime.jpg"}
    ]

    selected = ImageSelection.select_inputs(images)

    assert length(selected) == 5
    assert Enum.any?(selected, &((&1.kind || &1["kind"]) == "original"))
    assert Enum.at(selected, 0).kind == "object_crop"
  end

  test "drops unusable images" do
    assert ImageSelection.select_inputs([
             %{kind: "original", mime_type: "image/jpeg"},
             %{kind: "normalized", uri: "https://cdn.example.com/2.jpg"}
           ]) == []
  end
end
