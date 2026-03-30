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
