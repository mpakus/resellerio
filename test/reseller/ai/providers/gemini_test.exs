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
      marketplace_listing: "gemini-marketplace",
      price_research: "gemini-pricing",
      reconciliation: "gemini-reconciliation",
      lifestyle_image: "gemini-lifestyle-image"
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

  test "recognize_images/3 downloads external image URLs and sends inline image bytes" do
    images = [%{mime_type: "image/jpeg", external_url: "https://cdn.example.test/images/1.jpg"}]
    attrs = %{"brand_hint" => "Nike"}

    download_request_fun = fn url ->
      assert url == "https://cdn.example.test/images/1.jpg"

      {:ok,
       %{
         status: 200,
         body: "jpeg-binary"
       }}
    end

    request_fun = fn request ->
      parts = get_in(request.body, ["contents", Access.at(0), "parts"])

      assert [
               %{"text" => _prompt},
               %{
                 "inline_data" => %{
                   "mime_type" => "image/jpeg",
                   "data" => encoded_image
                 }
               }
             ] = parts

      assert Base.decode64!(encoded_image) == "jpeg-binary"

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
                         "brand" => "Nike",
                         "category" => "Sneakers",
                         "confidence_score" => 0.93,
                         "needs_review" => false
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
             Gemini.recognize_images(images, attrs,
               config: @config,
               download_request_fun: download_request_fun,
               request_fun: request_fun
             )

    assert result.output["brand"] == "Nike"
  end

  test "recognize_images/3 returns a storage download error when an external image fetch fails" do
    images = [%{mime_type: "image/jpeg", external_url: "https://cdn.example.test/images/1.jpg"}]

    download_request_fun = fn _url ->
      {:ok,
       %{
         status: 403,
         body: %{"error" => "access denied"}
       }}
    end

    assert {:error, {:image_download_failed, {:http_error, 403, %{"error" => "access denied"}}}} =
             Gemini.recognize_images(images, %{},
               config: @config,
               download_request_fun: download_request_fun
             )
  end

  test "research_price/3 separates grounded search from structured output" do
    request_fun = fn request ->
      attempt = Process.get(:price_research_request_attempt, 0) + 1
      Process.put(:price_research_request_attempt, attempt)

      assert request.url ==
               "https://gemini.example.test/v1beta/models/gemini-pricing:generateContent"

      case attempt do
        1 ->
          assert request.body["tools"] == [%{"google_search" => %{}}]
          refute get_in(request.body, ["generationConfig", "responseMimeType"])

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
                           "GOAT and StockX comparables cluster around 120 USD with steady demand."
                       }
                     ]
                   }
                 }
               ]
             }
           }}

        2 ->
          refute Map.has_key?(request.body, "tools")

          assert get_in(request.body, ["generationConfig", "responseMimeType"]) ==
                   "application/json"

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
    assert result.grounded_findings =~ "120 USD"
  end

  test "generate_marketplace_listing/2 builds a marketplace-specific JSON request" do
    request_fun = fn request ->
      assert request.url ==
               "https://gemini.example.test/v1beta/models/gemini-marketplace:generateContent"

      parts = get_in(request.body, ["contents", Access.at(0), "parts"])
      assert [%{"text" => prompt}] = parts
      assert prompt =~ "marketplace"
      assert prompt =~ "ebay"

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
                         "generated_title" => "Nike Air Max 90 Sneakers",
                         "generated_description" => "Marketplace-ready copy",
                         "generated_tags" => ["nike", "sneakers"],
                         "generated_price_suggestion" => 125,
                         "generation_version" => "gemini-marketplace-v1",
                         "compliance_warnings" => []
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
             Gemini.generate_marketplace_listing(
               %{
                 "marketplace" => "ebay",
                 "product" => %{"brand" => "Nike", "title" => "Air Max 90"}
               },
               config: @config,
               request_fun: request_fun
             )

    assert result.operation == :marketplace_listing
    assert result.output["generated_title"] == "Nike Air Max 90 Sneakers"
  end

  test "generate_lifestyle_image/3 builds an image-only generation request and parses image parts" do
    request_fun = fn request ->
      assert request.url ==
               "https://gemini.example.test/v1beta/models/gemini-lifestyle-image:generateContent"

      assert get_in(request.body, ["generationConfig", "responseModalities"]) == ["Image"]

      assert get_in(request.body, ["generationConfig", "imageConfig", "aspectRatio"]) == "4:5"

      parts = get_in(request.body, ["contents", Access.at(0), "parts"])

      assert [
               %{"text" => prompt},
               %{"inline_data" => %{"mime_type" => "image/png", "data" => "base64-image"}}
             ] = parts

      assert prompt =~ "Create one photorealistic lifestyle preview image."

      {:ok,
       %{
         status: 200,
         body: %{
           "candidates" => [
             %{
               "content" => %{
                 "parts" => [
                   %{"text" => "Generated image"},
                   %{
                     "inline_data" => %{
                       "mime_type" => "image/png",
                       "data" => Base.encode64("png-bytes")
                     }
                   }
                 ]
               }
             }
           ],
           "usageMetadata" => %{"promptTokenCount" => 77}
         }
       }}
    end

    assert {:ok, result} =
             Gemini.generate_lifestyle_image(
               %{
                 "scene_key" => "model_studio",
                 "scene_family" => "apparel",
                 "aspect_ratio" => "4:5",
                 "prompt" => "Create one photorealistic lifestyle preview image."
               },
               [%{mime_type: "image/png", data_base64: "base64-image"}],
               config: @config,
               request_fun: request_fun
             )

    assert result.operation == :lifestyle_image
    assert result.model == "gemini-lifestyle-image"
    assert result.output["scene_key"] == "model_studio"
    assert result.output["image_count"] == 1

    assert result.generated_images == [
             %{mime_type: "image/png", data_base64: Base.encode64("png-bytes")}
           ]
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

  test "retries retryable 429 responses before succeeding" do
    parent = self()

    request_fun = fn _request ->
      attempt = Process.get(:gemini_attempt, 0) + 1
      Process.put(:gemini_attempt, attempt)
      send(parent, {:gemini_attempt, attempt})

      case attempt do
        1 ->
          {:ok,
           %{
             status: 429,
             body: %{
               "error" => %{
                 "status" => "RESOURCE_EXHAUSTED",
                 "message" => "Resource has been exhausted (e.g. check quota)."
               }
             }
           }}

        2 ->
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
                             "suggested_title" => "Nike Air Max 90",
                             "short_description" => "Recovered after retry"
                           })
                       }
                     ]
                   }
                 }
               ]
             }
           }}
      end
    end

    sleep_fun = fn milliseconds -> send(parent, {:gemini_sleep, milliseconds}) end

    assert {:ok, result} =
             Gemini.generate_description(
               %{"brand" => "Nike", "category" => "Sneakers"},
               config: @config,
               request_fun: request_fun,
               sleep_fun: sleep_fun,
               max_retries: 1,
               retry_backoff_ms: 25
             )

    assert result.output["suggested_title"] == "Nike Air Max 90"
    assert_received {:gemini_attempt, 1}
    assert_received {:gemini_sleep, 25}
    assert_received {:gemini_attempt, 2}
  end

  test "retries request timeouts before succeeding" do
    parent = self()

    request_fun = fn _request ->
      attempt = Process.get(:gemini_timeout_attempt, 0) + 1
      Process.put(:gemini_timeout_attempt, attempt)
      send(parent, {:gemini_timeout_attempt, attempt})

      case attempt do
        1 ->
          {:error, %Req.TransportError{reason: :timeout}}

        2 ->
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
                             "suggested_title" => "Recovered after timeout",
                             "short_description" => "Recovered request"
                           })
                       }
                     ]
                   }
                 }
               ]
             }
           }}
      end
    end

    sleep_fun = fn milliseconds -> send(parent, {:gemini_timeout_sleep, milliseconds}) end

    assert {:ok, result} =
             Gemini.generate_description(
               %{"brand" => "Nike", "category" => "Sneakers"},
               config: @config,
               request_fun: request_fun,
               sleep_fun: sleep_fun,
               max_retries: 1,
               retry_backoff_ms: 25
             )

    assert result.output["suggested_title"] == "Recovered after timeout"
    assert_received {:gemini_timeout_attempt, 1}
    assert_received {:gemini_timeout_sleep, 25}
    assert_received {:gemini_timeout_attempt, 2}
  end

  test "returns an error for unsupported image input" do
    assert {:error, {:unsupported_image_input, %{id: 1}}} =
             Gemini.recognize_images([%{id: 1}], %{},
               config: @config,
               request_fun: fn _ -> :ok end
             )
  end
end
