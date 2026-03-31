defmodule Reseller.Media.Processors.Photoroom do
  @moduledoc """
  Photoroom Image Editing API client backed by `Req`.
  """

  @behaviour Reseller.Media.Processor

  @type request_data :: %{
          method: :get,
          url: String.t(),
          headers: [{String.t(), String.t()}],
          params: map(),
          receive_timeout: pos_integer()
        }

  @impl true
  def process_image(image_url, profile, opts \\ [])
      when is_binary(image_url) and is_map(profile) do
    with {:ok, request} <- build_edit_request(image_url, profile, opts),
         {:ok, response} <- execute_request(request, opts) do
      parse_response(profile, response)
    end
  end

  @spec build_edit_request(String.t(), map(), keyword()) ::
          {:ok, request_data()} | {:error, term()}
  def build_edit_request(image_url, profile, opts) do
    with {:ok, api_key} <- fetch_api_key(opts) do
      config = config(opts)

      {:ok,
       %{
         method: :get,
         url: config[:base_url],
         headers: [{"x-api-key", api_key}],
         params:
           %{
             "imageUrl" => image_url,
             "removeBackground" => "true",
             "padding" => Float.to_string(Keyword.get(opts, :padding, config[:padding]))
           }
           |> maybe_put_background_color(profile)
           |> maybe_put_output_format(config),
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
    Req.get(
      url: request.url,
      headers: request.headers,
      params: request.params,
      receive_timeout: request.receive_timeout
    )
  end

  defp parse_response(profile, response) do
    status = response_field(response, :status) || 200
    body = response_field(response, :body)

    if status in 200..299 and is_binary(body) do
      {:ok,
       %{
         kind: profile.kind,
         background_style: profile.background_style,
         body: body,
         content_type: response_header(response, "content-type") || "image/png",
         byte_size: byte_size(body)
       }}
    else
      {:error, {:http_error, status, response_field(response, :body)}}
    end
  end

  defp maybe_put_background_color(params, %{kind: "white_background"}),
    do: Map.put(params, "background.color", "FFFFFF")

  defp maybe_put_background_color(params, _profile), do: params

  defp maybe_put_output_format(params, config) do
    case config[:output_format] do
      format when is_binary(format) and format != "" -> Map.put(params, "export.format", format)
      _ -> params
    end
  end

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
      {^header_name, value} ->
        normalize_header_value(value)

      {name, value} when is_binary(name) ->
        if String.downcase(name) == header_name, do: normalize_header_value(value)

      _ ->
        nil
    end)
  end

  defp normalize_header_value([value | _rest]) when is_binary(value), do: value
  defp normalize_header_value(value) when is_binary(value), do: value
  defp normalize_header_value(_value), do: nil

  defp fetch_api_key(opts) do
    case config(opts)[:api_key] do
      api_key when is_binary(api_key) and api_key != "" -> {:ok, api_key}
      _ -> {:error, :missing_api_key}
    end
  end

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
    |> Keyword.take([:base_url, :timeout, :padding, :output_format])
  end
end
