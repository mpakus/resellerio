defmodule Reseller.AI.Providers.Gemini do
  @moduledoc """
  Gemini Developer API client backed by `Req`.
  """

  @behaviour Reseller.AI.Provider

  @type request_data :: %{
          method: :post,
          url: String.t(),
          headers: [{String.t(), String.t()}],
          body: map(),
          receive_timeout: pos_integer()
        }

  @impl true
  def recognize_images(images, attrs, opts \\ []) do
    with {:ok, request} <- build_generate_content_request(:recognition, images, attrs, opts),
         {:ok, response} <- execute_request(request, opts) do
      parse_structured_response(:recognition, response, request.model)
    end
  end

  @impl true
  def generate_description(product_attrs, opts \\ []) do
    with {:ok, request} <- build_generate_content_request(:description, [], product_attrs, opts),
         {:ok, response} <- execute_request(request, opts) do
      parse_structured_response(:description, response, request.model)
    end
  end

  @impl true
  def research_price(product_attrs, search_results, opts \\ []) do
    with {:ok, grounded_request} <-
           build_grounded_price_request(product_attrs, search_results, opts),
         {:ok, grounded_response} <- execute_request(grounded_request, opts),
         {:ok, grounded_text} <- parse_text_response(grounded_response),
         {:ok, request} <-
           build_generate_content_request(
             :price_research,
             [],
             %{
               product: product_attrs,
               search_results: search_results,
               grounded_findings: grounded_text
             },
             opts
           ),
         {:ok, response} <- execute_request(request, opts),
         {:ok, result} <- parse_structured_response(:price_research, response, request.model) do
      {:ok, Map.put(result, :grounded_findings, grounded_text)}
    end
  end

  @impl true
  def generate_marketplace_listing(attrs, opts \\ []) do
    with {:ok, request} <-
           build_generate_content_request(:marketplace_listing, [], attrs, opts),
         {:ok, response} <- execute_request(request, opts) do
      parse_structured_response(:marketplace_listing, response, request.model)
    end
  end

  @impl true
  def reconcile_product(recognition_result, search_results, opts \\ []) do
    with {:ok, request} <-
           build_generate_content_request(
             :reconciliation,
             [],
             %{
               recognition: recognition_result,
               search_results: search_results
             },
             opts
           ),
         {:ok, response} <- execute_request(request, opts) do
      parse_structured_response(:reconciliation, response, request.model)
    end
  end

  @spec build_generate_content_request(atom(), [map()], map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def build_generate_content_request(operation, images, payload, opts)
      when is_atom(operation) and is_list(images) and is_map(payload) do
    with {:ok, api_key} <- fetch_api_key(opts),
         {:ok, model} <- fetch_model(operation, opts),
         {:ok, image_parts} <- build_image_parts(images) do
      config = config(opts)
      prompt = prompt_for(operation, payload)

      body =
        %{
          "contents" => [
            %{
              "role" => "user",
              "parts" => [%{"text" => prompt} | image_parts]
            }
          ],
          "generationConfig" => %{
            "responseMimeType" => "application/json",
            "responseSchema" => response_schema(operation)
          }
        }
        |> maybe_put_tools(operation)

      {:ok,
       %{
         method: :post,
         operation: operation,
         model: model,
         url: "#{String.trim_trailing(config[:base_url], "/")}/models/#{model}:generateContent",
         headers: [{"x-goog-api-key", api_key}],
         body: body,
         receive_timeout: config[:timeout]
       }}
    end
  end

  defp execute_request(request, opts) do
    request_fun = Keyword.get(opts, :request_fun, &default_request/1)
    sleep_fun = Keyword.get(opts, :sleep_fun, &Process.sleep/1)
    max_retries = Keyword.get(opts, :max_retries, config(opts)[:max_retries] || 0)

    retry_backoff_ms =
      Keyword.get(opts, :retry_backoff_ms, config(opts)[:retry_backoff_ms] || 500)

    execute_request(request, request_fun, sleep_fun, max_retries, retry_backoff_ms, 0)
  end

  defp execute_request(request, request_fun, sleep_fun, max_retries, retry_backoff_ms, attempt) do
    case request_fun.(request) do
      {:ok, response} ->
        if attempt < max_retries and retryable_response?(response) do
          sleep_fun.(backoff_ms(retry_backoff_ms, attempt))

          execute_request(
            request,
            request_fun,
            sleep_fun,
            max_retries,
            retry_backoff_ms,
            attempt + 1
          )
        else
          {:ok, response}
        end

      {:error, reason} ->
        if attempt < max_retries and retryable_transport_reason?(reason) do
          sleep_fun.(backoff_ms(retry_backoff_ms, attempt))

          execute_request(
            request,
            request_fun,
            sleep_fun,
            max_retries,
            retry_backoff_ms,
            attempt + 1
          )
        else
          {:error, {:request_failed, reason}}
        end
    end
  end

  defp default_request(request) do
    Req.post(
      url: request.url,
      headers: request.headers,
      json: request.body,
      receive_timeout: request.receive_timeout
    )
  end

  defp parse_structured_response(operation, response, model) do
    status = response_field(response, :status) || 200
    body = response_field(response, :body) || %{}

    if status in 200..299 do
      text = extract_candidate_text(body)

      case Jason.decode(text) do
        {:ok, output} ->
          {:ok,
           %{
             provider: :gemini,
             operation: operation,
             model: model,
             output: output,
             raw_text: text,
             usage: Map.get(body, "usageMetadata"),
             raw_response: body,
             request_id: response_header(response, "x-request-id")
           }}

        {:error, _reason} ->
          {:error, {:invalid_json, text}}
      end
    else
      {:error, {:http_error, status, body}}
    end
  end

  defp parse_text_response(response) do
    status = response_field(response, :status) || 200
    body = response_field(response, :body) || %{}

    if status in 200..299 do
      {:ok, extract_candidate_text(body)}
    else
      {:error, {:http_error, status, body}}
    end
  end

  defp retryable_response?(response) do
    status = response_field(response, :status)
    body = response_field(response, :body) || %{}

    status in [429, 503] and retryable_api_error?(body)
  end

  defp retryable_api_error?(%{"error" => %{"status" => status}})
       when status in ["RESOURCE_EXHAUSTED", "UNAVAILABLE"],
       do: true

  defp retryable_api_error?(%{"error" => %{"message" => message}}) when is_binary(message) do
    message_downcase = String.downcase(message)

    String.contains?(message_downcase, "rate limit") or
      String.contains?(message_downcase, "resource has been exhausted") or
      String.contains?(message_downcase, "temporarily unavailable")
  end

  defp retryable_api_error?(_body), do: false

  defp retryable_transport_reason?(%Req.TransportError{reason: reason})
       when reason in [:timeout, :connect_timeout, :closed],
       do: true

  defp retryable_transport_reason?(_reason), do: false

  defp backoff_ms(base_backoff_ms, attempt) do
    round(base_backoff_ms * :math.pow(2, attempt))
  end

  defp extract_candidate_text(%{"candidates" => [%{"content" => %{"parts" => parts}} | _]}) do
    parts
    |> Enum.find_value("", fn
      %{"text" => text} when is_binary(text) -> text
      _ -> nil
    end)
  end

  defp extract_candidate_text(_body), do: ""

  defp response_field(%Req.Response{} = response, field), do: Map.get(response, field)
  defp response_field(response, field) when is_map(response), do: Map.get(response, field)
  defp response_field(_response, _field), do: nil

  defp response_header(response, header_name) do
    headers =
      case response do
        %Req.Response{headers: headers} -> headers
        %{headers: headers} -> headers
        _ -> []
      end

    Enum.find_value(headers, fn
      {^header_name, value} -> value
      {name, value} when is_binary(name) -> if String.downcase(name) == header_name, do: value
      _ -> nil
    end)
  end

  defp fetch_api_key(opts) do
    case config(opts)[:api_key] do
      api_key when is_binary(api_key) and api_key != "" -> {:ok, api_key}
      _ -> {:error, :missing_api_key}
    end
  end

  defp fetch_model(operation, opts) do
    model_override = Keyword.get(opts, :model)

    model =
      model_override ||
        config(opts)
        |> Keyword.fetch!(:models)
        |> Map.get(operation)

    if is_binary(model) and model != "" do
      {:ok, model}
    else
      {:error, {:missing_model, operation}}
    end
  end

  defp build_image_parts(images) do
    images
    |> Enum.map(&image_part/1)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, part}, {:ok, parts} -> {:cont, {:ok, parts ++ [part]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
  end

  defp image_part(%{"inline_data" => %{"mime_type" => _mime_type, "data" => _data} = inline_data}) do
    {:ok, %{"inline_data" => inline_data}}
  end

  defp image_part(%{
         "file_data" => %{"mime_type" => _mime_type, "file_uri" => _file_uri} = file_data
       }) do
    {:ok, %{"file_data" => file_data}}
  end

  defp image_part(%{inline_data: %{mime_type: _mime_type, data: _data} = inline_data}) do
    {:ok, %{"inline_data" => stringify_keys(inline_data)}}
  end

  defp image_part(%{file_data: %{mime_type: _mime_type, file_uri: _file_uri} = file_data}) do
    {:ok, %{"file_data" => stringify_keys(file_data)}}
  end

  defp image_part(%{"mime_type" => mime_type, "data" => data})
       when is_binary(mime_type) and is_binary(data) do
    {:ok, %{"inline_data" => %{"mime_type" => mime_type, "data" => data}}}
  end

  defp image_part(%{"mime_type" => mime_type, "data_base64" => data})
       when is_binary(mime_type) and is_binary(data) do
    {:ok, %{"inline_data" => %{"mime_type" => mime_type, "data" => data}}}
  end

  defp image_part(%{"mime_type" => mime_type, "file_uri" => file_uri})
       when is_binary(mime_type) and is_binary(file_uri) do
    {:ok, %{"file_data" => %{"mime_type" => mime_type, "file_uri" => file_uri}}}
  end

  defp image_part(%{"mime_type" => mime_type, "uri" => file_uri})
       when is_binary(mime_type) and is_binary(file_uri) do
    {:ok, %{"file_data" => %{"mime_type" => mime_type, "file_uri" => file_uri}}}
  end

  defp image_part(%{mime_type: mime_type, data: data})
       when is_binary(mime_type) and is_binary(data) do
    {:ok, %{"inline_data" => %{"mime_type" => mime_type, "data" => data}}}
  end

  defp image_part(%{mime_type: mime_type, data_base64: data})
       when is_binary(mime_type) and is_binary(data) do
    {:ok, %{"inline_data" => %{"mime_type" => mime_type, "data" => data}}}
  end

  defp image_part(%{mime_type: mime_type, file_uri: file_uri})
       when is_binary(mime_type) and is_binary(file_uri) do
    {:ok, %{"file_data" => %{"mime_type" => mime_type, "file_uri" => file_uri}}}
  end

  defp image_part(%{mime_type: mime_type, uri: file_uri})
       when is_binary(mime_type) and is_binary(file_uri) do
    {:ok, %{"file_data" => %{"mime_type" => mime_type, "file_uri" => file_uri}}}
  end

  defp image_part(image), do: {:error, {:unsupported_image_input, image}}

  defp maybe_put_tools(body, :price_research) do
    body
  end

  defp maybe_put_tools(body, _operation), do: body

  defp build_grounded_price_request(product_attrs, search_results, opts) do
    with {:ok, api_key} <- fetch_api_key(opts),
         {:ok, model} <- fetch_model(:price_research, opts) do
      config = config(opts)

      prompt = grounded_price_prompt(%{product: product_attrs, search_results: search_results})

      {:ok,
       %{
         method: :post,
         operation: :price_research_grounded,
         model: model,
         url: "#{String.trim_trailing(config[:base_url], "/")}/models/#{model}:generateContent",
         headers: [{"x-goog-api-key", api_key}],
         body: %{
           "contents" => [
             %{
               "role" => "user",
               "parts" => [%{"text" => prompt}]
             }
           ],
           "tools" => [%{"google_search" => %{}}]
         },
         receive_timeout: config[:timeout]
       }}
    end
  end

  defp prompt_for(:recognition, attrs) do
    """
    Analyze the provided resale product images and return structured JSON only.
    Focus on visible facts, not speculation.
    Return brand, category, possible_model, color, material, logo_text,
    distinguishing_features, confidence_score, field_confidence, needs_review,
    and missing_information.
    Known metadata: #{Jason.encode!(attrs)}
    """
  end

  defp prompt_for(:description, attrs) do
    """
    Generate a concise structured resale listing draft as JSON only.
    Use the normalized product attributes as the source of truth.
    Do not invent missing details. Product attributes: #{Jason.encode!(attrs)}
    """
  end

  defp prompt_for(:price_research, attrs) do
    """
    Use the grounded findings and the provided comparable data to estimate
    secondhand resale pricing. Return JSON only with min, target, max, median,
    confidence, rationale, and comparable_results. Do not call tools.
    Product and external evidence: #{Jason.encode!(attrs)}
    """
  end

  defp prompt_for(:marketplace_listing, attrs) do
    """
    Generate marketplace-specific resale listing content as JSON only.
    Respect the target marketplace tone and constraints.
    Return generated_title, generated_description, generated_tags,
    generated_price_suggestion, generation_version, and compliance_warnings.
    Input: #{Jason.encode!(attrs)}
    """
  end

  defp prompt_for(:reconciliation, attrs) do
    """
    Reconcile the recognition result and external match evidence.
    Return JSON only describing the most likely model, whether the matches refer
    to the same product family, a short card description, and review guidance.
    Evidence: #{Jason.encode!(attrs)}
    """
  end

  defp grounded_price_prompt(attrs) do
    """
    Use Google Search grounding to find current resale pricing signals for this product.
    Summarize the strongest comparable matches, likely price range, and market signals
    in plain text. Do not return JSON.
    Product and external evidence: #{Jason.encode!(attrs)}
    """
  end

  defp response_schema(:recognition) do
    %{
      "type" => "OBJECT",
      "properties" => %{
        "brand" => %{"type" => "STRING"},
        "category" => %{"type" => "STRING"},
        "possible_model" => %{"type" => "STRING"},
        "color" => %{"type" => "STRING"},
        "material" => %{"type" => "STRING"},
        "logo_text" => %{"type" => "STRING"},
        "distinguishing_features" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}},
        "confidence_score" => %{"type" => "NUMBER"},
        "field_confidence" => %{"type" => "OBJECT"},
        "needs_review" => %{"type" => "BOOLEAN"},
        "missing_information" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}}
      },
      "required" => ["category", "confidence_score", "needs_review"]
    }
  end

  defp response_schema(:description) do
    %{
      "type" => "OBJECT",
      "properties" => %{
        "suggested_title" => %{"type" => "STRING"},
        "short_description" => %{"type" => "STRING"},
        "long_description" => %{"type" => "STRING"},
        "key_features" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}},
        "seo_keywords" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}},
        "missing_details_warning" => %{"type" => "STRING"}
      },
      "required" => ["suggested_title", "short_description"]
    }
  end

  defp response_schema(:price_research) do
    %{
      "type" => "OBJECT",
      "properties" => %{
        "currency" => %{"type" => "STRING"},
        "suggested_min_price" => %{"type" => "NUMBER"},
        "suggested_target_price" => %{"type" => "NUMBER"},
        "suggested_max_price" => %{"type" => "NUMBER"},
        "suggested_median_price" => %{"type" => "NUMBER"},
        "pricing_confidence" => %{"type" => "NUMBER"},
        "rationale_summary" => %{"type" => "STRING"},
        "market_signals" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}},
        "comparable_results" => %{"type" => "ARRAY", "items" => %{"type" => "OBJECT"}}
      },
      "required" => ["currency", "suggested_target_price", "pricing_confidence"]
    }
  end

  defp response_schema(:marketplace_listing) do
    %{
      "type" => "OBJECT",
      "properties" => %{
        "generated_title" => %{"type" => "STRING"},
        "generated_description" => %{"type" => "STRING"},
        "generated_tags" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}},
        "generated_price_suggestion" => %{"type" => "NUMBER"},
        "generation_version" => %{"type" => "STRING"},
        "compliance_warnings" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}}
      },
      "required" => ["generated_title", "generated_description", "generated_price_suggestion"]
    }
  end

  defp response_schema(:reconciliation) do
    %{
      "type" => "OBJECT",
      "properties" => %{
        "most_likely_model" => %{"type" => "STRING"},
        "same_model_family" => %{"type" => "BOOLEAN"},
        "short_card_description" => %{"type" => "STRING"},
        "review_notes" => %{"type" => "ARRAY", "items" => %{"type" => "STRING"}}
      },
      "required" => ["same_model_family", "short_card_description"]
    }
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp config(opts) do
    app_config = Application.fetch_env!(:reseller, __MODULE__)
    Keyword.merge(app_config, Keyword.get(opts, :config, []))
  end
end
