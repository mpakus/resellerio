defmodule Reseller.Media.Processors.PhotoroomTest do
  use ExUnit.Case, async: true

  alias Reseller.Media.Processors.Photoroom

  @config [
    api_key: "photoroom-key",
    base_url: "https://image-api.example.test/v2/edit",
    timeout: 4_000,
    padding: 0.2,
    output_format: "png"
  ]

  test "builds a background removal request" do
    request_fun = fn request ->
      assert request.method == :get
      assert request.url == "https://image-api.example.test/v2/edit"
      assert request.headers == [{"x-api-key", "photoroom-key"}]
      assert request.params["imageUrl"] == "https://cdn.example.com/source.jpg"
      assert request.params["removeBackground"] == "true"
      assert request.params["padding"] == "0.2"
      assert request.params["export.format"] == "png"
      refute Map.has_key?(request.params, "background.color")

      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "image/png"}],
         body: <<137, 80, 78, 71>>
       }}
    end

    assert {:ok, result} =
             Photoroom.process_image(
               "https://cdn.example.com/source.jpg",
               %{kind: "background_removed", background_style: "transparent"},
               config: @config,
               request_fun: request_fun
             )

    assert result.kind == "background_removed"
    assert result.content_type == "image/png"
    assert result.byte_size == 4
  end

  test "adds white background color when generating white-background variants" do
    request_fun = fn request ->
      assert request.params["background.color"] == "FFFFFF"

      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "image/png"}],
         body: "png-body"
       }}
    end

    assert {:ok, result} =
             Photoroom.process_image(
               "https://cdn.example.com/source.jpg",
               %{kind: "white_background", background_style: "white"},
               config: @config,
               request_fun: request_fun
             )

    assert result.background_style == "white"
    assert result.byte_size == 8
  end

  test "normalizes Req list-style content-type response headers" do
    request_fun = fn _request ->
      {:ok,
       %{
         status: 200,
         headers: [{"content-type", ["image/png"]}],
         body: "png-body"
       }}
    end

    assert {:ok, result} =
             Photoroom.process_image(
               "https://cdn.example.com/source.jpg",
               %{kind: "background_removed", background_style: "transparent"},
               config: @config,
               request_fun: request_fun
             )

    assert result.content_type == "image/png"
  end
end
