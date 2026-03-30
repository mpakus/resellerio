defmodule Reseller.Media.Storage.Tigris do
  @moduledoc """
  Minimal S3-compatible presigned PUT URL generator for Tigris-style storage.
  """

  @behaviour Reseller.Media.Storage

  @service "s3"
  @algorithm "AWS4-HMAC-SHA256"

  @impl true
  def sign_upload(storage_key, opts \\ []) when is_binary(storage_key) do
    config = config(opts)

    with {:ok, access_key_id} <- fetch_required(config, :access_key_id),
         {:ok, secret_access_key} <- fetch_required(config, :secret_access_key),
         {:ok, base_url} <- fetch_required(config, :base_url),
         {:ok, uri} <- parse_base_uri(base_url) do
      expires_in = Keyword.get(opts, :expires_in, config[:expires_in])
      content_type = Keyword.get(opts, :content_type, "application/octet-stream")

      request_time =
        Keyword.get(opts, :request_time, DateTime.utc_now()) |> DateTime.truncate(:second)

      amz_date = format_amz_date(request_time)
      date_stamp = Calendar.strftime(request_time, "%Y%m%d")
      credential_scope = "#{date_stamp}/#{config[:region]}/#{@service}/aws4_request"
      canonical_uri = join_uri_path(uri.path || "/", storage_key)

      query_params = %{
        "X-Amz-Algorithm" => @algorithm,
        "X-Amz-Credential" => "#{access_key_id}/#{credential_scope}",
        "X-Amz-Date" => amz_date,
        "X-Amz-Expires" => Integer.to_string(expires_in),
        "X-Amz-SignedHeaders" => "content-type;host"
      }

      canonical_request =
        [
          "PUT",
          canonical_uri,
          canonical_query_string(query_params),
          "content-type:#{content_type}\nhost:#{uri.host}\n",
          "content-type;host",
          "UNSIGNED-PAYLOAD"
        ]
        |> Enum.join("\n")

      string_to_sign =
        [
          @algorithm,
          amz_date,
          credential_scope,
          hex_encode(:crypto.hash(:sha256, canonical_request))
        ]
        |> Enum.join("\n")

      signing_key =
        secret_access_key
        |> signing_key(date_stamp, config[:region])

      signature = :crypto.mac(:hmac, :sha256, signing_key, string_to_sign) |> hex_encode()
      signed_query = Map.put(query_params, "X-Amz-Signature", signature)
      upload_url = build_signed_url(uri, canonical_uri, signed_query)

      {:ok,
       %{
         method: "PUT",
         upload_url: upload_url,
         headers: %{"content-type" => content_type},
         expires_at: DateTime.add(request_time, expires_in, :second) |> DateTime.to_iso8601()
       }}
    end
  end

  @impl true
  def upload_object(storage_key, body, opts \\ [])
      when is_binary(storage_key) and is_binary(body) do
    with {:ok, upload} <- sign_upload(storage_key, opts),
         {:ok, response} <- execute_upload(upload, body, opts) do
      status = Map.get(response, :status, 200)

      if status in 200..299 do
        {:ok,
         %{
           storage_key: storage_key,
           content_type: upload.headers["content-type"],
           byte_size: byte_size(body)
         }}
      else
        {:error, {:http_error, status, Map.get(response, :body)}}
      end
    end
  end

  defp config(opts) do
    app_config = Application.fetch_env!(:reseller, __MODULE__)
    Keyword.merge(app_config, Keyword.get(opts, :config, []))
  end

  defp execute_upload(upload, body, opts) do
    request_fun = Keyword.get(opts, :upload_request_fun, &default_upload_request/2)

    case request_fun.(upload, body) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, {:request_failed, reason}}
    end
  end

  defp default_upload_request(upload, body) do
    Req.put(url: upload.upload_url, headers: upload.headers, body: body)
  end

  defp fetch_required(config, key) do
    case config[key] do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:missing_config, key}}
    end
  end

  defp parse_base_uri(base_url) do
    case URI.parse(base_url) do
      %URI{scheme: scheme, host: host} = uri when is_binary(scheme) and is_binary(host) ->
        {:ok, uri}

      _ ->
        {:error, :invalid_base_url}
    end
  end

  defp join_uri_path(base_path, storage_key) do
    [base_path, storage_key]
    |> Enum.join("/")
    |> String.replace(~r{/+}, "/")
    |> uri_encode_path()
  end

  defp uri_encode_path(path) do
    path
    |> String.split("/", trim: false)
    |> Enum.map_join("/", fn segment ->
      URI.encode(segment, fn char -> URI.char_unreserved?(char) end)
    end)
    |> normalize_encoded_path()
  end

  defp normalize_encoded_path(""), do: "/"

  defp normalize_encoded_path(encoded) do
    if String.starts_with?(encoded, "/") do
      encoded
    else
      "/" <> encoded
    end
  end

  defp canonical_query_string(params) do
    params
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map_join("&", fn {key, value} ->
      "#{URI.encode_www_form(key)}=#{URI.encode_www_form(value)}"
    end)
  end

  defp build_signed_url(%URI{} = uri, canonical_uri, params) do
    %URI{uri | path: canonical_uri, query: canonical_query_string(params)}
    |> URI.to_string()
  end

  defp format_amz_date(datetime), do: Calendar.strftime(datetime, "%Y%m%dT%H%M%SZ")

  defp signing_key(secret_access_key, date_stamp, region) do
    ("AWS4" <> secret_access_key)
    |> hmac(date_stamp)
    |> hmac(region)
    |> hmac(@service)
    |> hmac("aws4_request")
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)

  defp hex_encode(binary), do: Base.encode16(binary, case: :lower)
end
