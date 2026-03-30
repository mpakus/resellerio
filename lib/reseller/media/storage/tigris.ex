defmodule Reseller.Media.Storage.Tigris do
  @moduledoc """
  ExAws-backed S3 storage integration for Tigris-compatible object storage.
  """

  @behaviour Reseller.Media.Storage

  alias ExAws.Config, as: ExAwsConfig
  alias ExAws.S3

  @generic_endpoint_hosts ["t3.storage.dev", "fly.storage.tigris.dev"]

  @impl true
  def sign_upload(storage_key, opts \\ []) when is_binary(storage_key) do
    config = config(opts)

    with {:ok, target} <- storage_target(config) do
      expires_in = Keyword.get(opts, :expires_in, config[:expires_in])
      content_type = Keyword.get(opts, :content_type, "application/octet-stream")

      request_time =
        Keyword.get(opts, :request_time, DateTime.utc_now())
        |> DateTime.truncate(:second)

      presign_opts =
        [
          expires_in: expires_in,
          start_datetime: request_time
        ] ++ target.presign_opts

      case S3.presigned_url(
             ex_aws_config(target),
             :put,
             target.bucket,
             storage_key,
             presign_opts
           ) do
        {:ok, upload_url} ->
          {:ok,
           %{
             method: "PUT",
             upload_url: upload_url,
             headers: %{"content-type" => content_type},
             expires_at: DateTime.add(request_time, expires_in, :second) |> DateTime.to_iso8601()
           }}

        {:error, reason} ->
          {:error, {:presign_failed, reason}}
      end
    end
  end

  @impl true
  def upload_object(storage_key, body, opts \\ [])
      when is_binary(storage_key) and is_binary(body) do
    config = config(opts)

    with {:ok, target} <- storage_target(config) do
      content_type = Keyword.get(opts, :content_type, "application/octet-stream")
      request_fun = Keyword.get(opts, :ex_aws_request_fun, &ExAws.request/2)

      operation = S3.put_object(target.bucket, storage_key, body, content_type: content_type)

      case request_fun.(operation, target.ex_aws_overrides) do
        {:ok, _result} ->
          {:ok,
           %{
             storage_key: storage_key,
             content_type: content_type,
             byte_size: byte_size(body)
           }}

        {:error, %{reason: reason}} ->
          maybe_fallback_to_presigned_upload(storage_key, body, content_type, reason, opts)

        {:error, reason} ->
          maybe_fallback_to_presigned_upload(storage_key, body, content_type, reason, opts)
      end
    end
  end

  def public_base_url(config) when is_list(config) do
    with {:ok, base_url} <- fetch_required(config, :base_url),
         {:ok, %URI{} = uri} <- parse_base_uri(base_url) do
      bucket_name = normalized_bucket_name(config[:bucket_name])

      cond do
        bucket_name != nil and generic_endpoint_host?(uri.host) ->
          {:ok, normalize_virtual_host_public_url(uri, bucket_name)}

        bucket_name != nil ->
          {:ok, normalize_public_url(uri, bucket_name)}

        true ->
          {:ok, normalize_public_url(uri, nil)}
      end
    end
  end

  defp config(opts) do
    app_config = Application.fetch_env!(:reseller, __MODULE__)
    Keyword.merge(app_config, Keyword.get(opts, :config, []))
  end

  defp storage_target(config) do
    with {:ok, access_key_id} <- fetch_required(config, :access_key_id),
         {:ok, secret_access_key} <- fetch_required(config, :secret_access_key),
         {:ok, base_url} <- fetch_required(config, :base_url),
         {:ok, %URI{} = uri} <- parse_base_uri(base_url) do
      build_target(uri, access_key_id, secret_access_key, config)
    end
  end

  defp build_target(uri, access_key_id, secret_access_key, config) do
    scheme = uri.scheme <> "://"
    port = uri.port || default_port(uri.scheme)
    region = config[:region]
    bucket_name = normalized_bucket_name(config[:bucket_name])

    base_overrides = [
      access_key_id: access_key_id,
      secret_access_key: secret_access_key,
      region: region,
      scheme: scheme,
      host: uri.host,
      port: port
    ]

    cond do
      bucket_name != nil and generic_endpoint_host?(uri.host) ->
        {:ok,
         %{
           bucket: bucket_name,
           ex_aws_overrides: base_overrides ++ [virtual_host: true],
           presign_opts: [virtual_host: true],
           public_base_url: normalize_virtual_host_public_url(uri, bucket_name)
         }}

      bucket_name != nil ->
        {:ok,
         %{
           bucket: bucket_name,
           ex_aws_overrides: base_overrides,
           presign_opts: [],
           public_base_url: normalize_public_url(uri, bucket_name)
         }}

      generic_endpoint_host?(uri.host) ->
        {:error, {:missing_config, :bucket_name}}

      true ->
        {:ok,
         %{
           bucket: uri.host,
           ex_aws_overrides: base_overrides ++ [virtual_host: true, bucket_as_host: true],
           presign_opts: [virtual_host: true, bucket_as_host: true],
           public_base_url: normalize_public_url(uri, nil)
         }}
    end
  end

  defp ex_aws_config(target) do
    ExAwsConfig.new(:s3, target.ex_aws_overrides)
  end

  defp maybe_fallback_to_presigned_upload(storage_key, body, content_type, reason, opts) do
    if access_denied?(reason) do
      with {:ok, upload} <-
             sign_upload(storage_key, Keyword.put(opts, :content_type, content_type)),
           {:ok, _response} <- execute_presigned_upload(upload, body, opts) do
        {:ok,
         %{
           storage_key: storage_key,
           content_type: content_type,
           byte_size: byte_size(body)
         }}
      end
    else
      {:error, normalize_upload_error(reason)}
    end
  end

  defp execute_presigned_upload(upload, body, opts) do
    request_fun = Keyword.get(opts, :upload_request_fun, &default_upload_request/2)

    case request_fun.(upload, body) do
      {:ok, response} ->
        status = Map.get(response, :status, Map.get(response, :status_code, 200))

        if status in 200..299 do
          {:ok, response}
        else
          {:error, {:http_error, status, response}}
        end

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp default_upload_request(upload, body) do
    Req.put(url: upload.upload_url, headers: upload.headers, body: body)
  end

  defp access_denied?({:http_error, 403, %{body: body}}) when is_binary(body) do
    String.contains?(body, "<Code>AccessDenied</Code>")
  end

  defp access_denied?({:http_error, 403, body}) when is_binary(body) do
    String.contains?(body, "<Code>AccessDenied</Code>")
  end

  defp access_denied?(_reason), do: false

  defp normalize_upload_error(%{reason: reason}), do: {:request_failed, reason}
  defp normalize_upload_error(reason), do: reason

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

  defp normalize_public_url(%URI{} = uri, nil) do
    %URI{uri | path: normalize_path(uri.path || "/"), query: nil}
    |> URI.to_string()
  end

  defp normalize_public_url(%URI{} = uri, bucket_name) do
    path =
      [uri.path || "/", bucket_name]
      |> Enum.join("/")
      |> normalize_path()

    %URI{uri | path: path, query: nil}
    |> URI.to_string()
  end

  defp normalize_virtual_host_public_url(%URI{} = uri, bucket_name) do
    %URI{
      uri
      | host: "#{bucket_name}.#{uri.host}",
        path: normalize_path(uri.path || "/"),
        query: nil
    }
    |> URI.to_string()
  end

  defp normalize_path(path) do
    normalized = String.replace(path, ~r{/+}, "/")

    cond do
      normalized == "" -> "/"
      String.starts_with?(normalized, "/") -> normalized
      true -> "/" <> normalized
    end
  end

  defp normalized_bucket_name(bucket_name) when is_binary(bucket_name) do
    bucket_name
    |> String.trim()
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp normalized_bucket_name(_bucket_name), do: nil

  defp generic_endpoint_host?(host) when is_binary(host), do: host in @generic_endpoint_hosts
  defp generic_endpoint_host?(_host), do: false

  defp default_port("http"), do: 80
  defp default_port("https"), do: 443
  defp default_port(_scheme), do: nil
end
