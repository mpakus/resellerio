defmodule Reseller.Search.Providers.SerpApi do
  @moduledoc """
  SerpApi client backed by `Req`.
  """

  @behaviour Reseller.Search.Provider

  @type request_data :: %{
          method: :get,
          url: String.t(),
          params: map(),
          receive_timeout: pos_integer()
        }

  @impl true
  def lens_matches(image_url, opts \\ []) when is_binary(image_url) do
    with {:ok, request} <- build_lens_request(image_url, opts),
         {:ok, response} <- execute_request(request, opts) do
      parse_lens_response(response)
    end
  end

  @impl true
  def shopping_matches(query, opts \\ []) when is_binary(query) do
    with {:ok, request} <- build_shopping_request(query, opts),
         {:ok, response} <- execute_request(request, opts) do
      parse_shopping_response(response)
    end
  end

  @spec build_lens_request(String.t(), keyword()) :: {:ok, request_data()} | {:error, term()}
  def build_lens_request(image_url, opts) when is_binary(image_url) do
    with {:ok, api_key} <- fetch_api_key(opts) do
      config = config(opts)

      params =
        %{
          "api_key" => api_key,
          "engine" => "google_lens",
          "url" => image_url,
          "hl" => Keyword.get(opts, :hl, config[:default_language]),
          "gl" => Keyword.get(opts, :gl, config[:default_country])
        }
        |> maybe_put_param("q", Keyword.get(opts, :query))

      {:ok,
       %{
         method: :get,
         url: config[:base_url],
         params: params,
         receive_timeout: config[:timeout]
       }}
    end
  end

  @spec build_shopping_request(String.t(), keyword()) :: {:ok, request_data()} | {:error, term()}
  def build_shopping_request(query, opts) when is_binary(query) do
    with {:ok, api_key} <- fetch_api_key(opts) do
      config = config(opts)

      {:ok,
       %{
         method: :get,
         url: config[:base_url],
         params: %{
           "api_key" => api_key,
           "engine" => config[:shopping_engine],
           "q" => query,
           "hl" => Keyword.get(opts, :hl, config[:default_language]),
           "gl" => Keyword.get(opts, :gl, config[:default_country])
         },
         receive_timeout: config[:timeout]
       }}
    end
  end

  defp execute_request(request, opts) do
    request_fun = Keyword.get(opts, :request_fun, &default_request/1)

    case request_fun.(request) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, {:request_failed, reason}}
    end
  end

  defp default_request(request) do
    Req.get(url: request.url, params: request.params, receive_timeout: request.receive_timeout)
  end

  defp parse_lens_response(response) do
    status = response_field(response, :status) || 200
    body = response_field(response, :body) || %{}

    if status in 200..299 do
      {:ok,
       %{
         provider: :serp_api,
         search_type: :lens,
         matches: normalize_lens_matches(body),
         raw_response: body
       }}
    else
      {:error, {:http_error, status, body}}
    end
  end

  defp parse_shopping_response(response) do
    status = response_field(response, :status) || 200
    body = response_field(response, :body) || %{}

    if status in 200..299 do
      {:ok,
       %{
         provider: :serp_api,
         search_type: :shopping,
         matches: normalize_shopping_matches(body),
         raw_response: body
       }}
    else
      {:error, {:http_error, status, body}}
    end
  end

  defp normalize_lens_matches(body) do
    [
      {"visual_matches", "visual_match"},
      {"exact_matches", "exact_match"},
      {"products", "product"}
    ]
    |> Enum.flat_map(fn {key, match_type} ->
      body
      |> Map.get(key, [])
      |> Enum.map(&normalize_match(&1, match_type))
    end)
  end

  defp normalize_shopping_matches(body) do
    body
    |> Map.get("shopping_results", [])
    |> Enum.map(&normalize_match(&1, "shopping"))
  end

  defp normalize_match(item, match_type) do
    url = item["link"] || item["product_link"] || item["source_link"]

    %{
      "title" => item["title"],
      "brand" => item["brand"] || item["source"],
      "price" => extracted_price(item),
      "source" => item["source"] || item["merchant"] || item["seller"],
      "source_domain" => extract_host(url),
      "url" => url,
      "thumbnail_url" => item["thumbnail"],
      "match_type" => match_type
    }
  end

  defp extracted_price(%{"extracted_price" => price}) when is_number(price), do: price
  defp extracted_price(%{"price" => price}) when is_number(price), do: price

  defp extracted_price(%{"price" => price}) when is_binary(price) do
    price
    |> String.replace(~r/[^0-9.,]/u, "")
    |> String.replace(",", "")
    |> case do
      "" ->
        nil

      normalized ->
        case Float.parse(normalized) do
          {value, _rest} -> value
          :error -> nil
        end
    end
  end

  defp extracted_price(_item), do: nil

  defp extract_host(nil), do: nil

  defp extract_host(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} -> host
      _ -> nil
    end
  end

  defp response_field(%Req.Response{} = response, field), do: Map.get(response, field)
  defp response_field(response, field) when is_map(response), do: Map.get(response, field)
  defp response_field(_response, _field), do: nil

  defp fetch_api_key(opts) do
    case config(opts)[:api_key] do
      api_key when is_binary(api_key) and api_key != "" -> {:ok, api_key}
      _ -> {:error, :missing_api_key}
    end
  end

  defp maybe_put_param(params, _key, nil), do: params
  defp maybe_put_param(params, _key, ""), do: params
  defp maybe_put_param(params, key, value), do: Map.put(params, key, value)

  defp config(opts) do
    case Keyword.fetch(opts, :config) do
      {:ok, override_config} ->
        Keyword.merge(default_config(), override_config)

      :error ->
        Application.fetch_env!(:reseller, __MODULE__)
    end
  end

  defp default_config do
    Application.fetch_env!(:reseller, __MODULE__)
    |> Keyword.take([:base_url, :shopping_engine, :default_language, :default_country, :timeout])
  end
end
