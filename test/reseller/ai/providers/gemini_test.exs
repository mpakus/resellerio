defmodule Reseller.AI.Providers.GeminiTest do
  use ExUnit.Case, async: true

  alias Reseller.AI.Providers.Gemini

  @config [
    api_key: "gemini-key",
    base_url: "https://gemini.example.test/v1beta",
    timeout: 4_000,
    models: %{
      recognition: "gemini-recognition",
      description: "gemini-description",
      price_research: "gemini-pricing",
      reconciliation: "gemini-reconciliation"
    }
  ]

  test "recognize_images/3 builds a multimodal JSON request and parses the result" do
    images = [%{mime_type: "image/jpeg", data_base64: "abc123"}]
    attrs = %{"brand_hint" => "Nike"}

    request_fun = fn request ->
      assert request.method == :post

      assert request.url ==
               "https://gemini.example.test/v1beta/models/gemini-recognition:generateContent"

      assert request.headers == [{"x-goog-api-key", "gemini-key"}]
      assert request.receive_timeout == 4_000
      assert get_in(request.body, ["generationConfig", "responseMimeType"]) == "application/json"
      refute Map.has_key?(request.body, "tools")

      parts = get_in(request.body, ["contents", Access.at(0), "parts"])

      assert [
               %{"text" => prompt},
               %{"inline_data" => %{"mime_type" => "image/jpeg", "data" => "abc123"}}
             ] = parts

      assert prompt =~ "brand_hint"

      {:ok,
       %{
         status: 200,
         headers: [{"x-request-id", "gemini-request-1"}],
         body: %{
           "candidates" => [
             %{
               "content" => %{
                 "parts" => [
                   %{
                     "text" =>
                       Jason.encode!(%{
                         "brand" => "Nike",
                         "category" => "Sneakers",
                         "confidence_score" => 0.93,
                         "needs_review" => false
                       })
                   }
                 ]
               }
             }
           ],
           "usageMetadata" => %{"promptTokenCount" => 123}
         }
       }}
    end

    assert {:ok, result} =
             Gemini.recognize_images(images, attrs, config: @config, request_fun: request_fun)

    assert result.provider == :gemini
    assert result.operation == :recognition
    assert result.model == "gemini-recognition"
    assert result.output["brand"] == "Nike"
    assert result.usage == %{"promptTokenCount" => 123}
    assert result.request_id == "gemini-request-1"
  end

  test "research_price/3 enables Google Search grounding" do
    request_fun = fn request ->
      assert request.url ==
               "https://gemini.example.test/v1beta/models/gemini-pricing:generateContent"

      assert request.body["tools"] == [%{"google_search" => %{}}]

      {:ok,
       %{
         status: 200,
         body: %{
           "candidates" => [
             %{
               "content" => %{
                 "parts" => [
                   %{
                     "text" =>
                       Jason.encode!(%{
                         "currency" => "USD",
                         "suggested_target_price" => 120,
                         "pricing_confidence" => 0.81
                       })
                   }
                 ]
               }
             }
           ]
         }
       }}
    end

    assert {:ok, result} =
             Gemini.research_price(
               %{"brand" => "Nike", "possible_model" => "Air Max 90"},
               %{"matches" => [%{"title" => "Nike Air Max 90"}]},
               config: @config,
               request_fun: request_fun
             )

    assert result.model == "gemini-pricing"
    assert result.output["currency"] == "USD"
  end

  test "returns an error when structured output is not valid JSON" do
    request_fun = fn _request ->
      {:ok,
       %{
         status: 200,
         body: %{
           "candidates" => [
             %{
               "content" => %{
                 "parts" => [
                   %{"text" => "not-json"}
                 ]
               }
             }
           ]
         }
       }}
    end

    assert {:error, {:invalid_json, "not-json"}} =
             Gemini.generate_description(
               %{"brand" => "Nike", "category" => "Sneakers"},
               config: @config,
               request_fun: request_fun
             )
  end

  test "returns an error for unsupported image input" do
    assert {:error, {:unsupported_image_input, %{id: 1}}} =
             Gemini.recognize_images([%{id: 1}], %{},
               config: @config,
               request_fun: fn _ -> :ok end
             )
  end
end
