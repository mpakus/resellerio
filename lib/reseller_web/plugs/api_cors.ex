defmodule ResellerWeb.Plugs.APICORS do
  @moduledoc false

  import Plug.Conn

  @api_prefix "/api/"
  @allowed_methods "GET, POST, PATCH, PUT, DELETE, OPTIONS"
  @default_allowed_headers "authorization, content-type, accept"
  @max_age "86400"

  def init(opts), do: opts

  def call(conn, _opts) do
    if String.starts_with?(conn.request_path, @api_prefix) do
      case cors_origin(conn) do
        {:ok, origin} ->
          conn = register_before_send(conn, &put_cors_headers(&1, origin))

          if conn.method == "OPTIONS" do
            conn
            |> put_cors_headers(origin)
            |> send_resp(:no_content, "")
            |> halt()
          else
            conn
          end

        {:error, :origin_required} ->
          if conn.method == "OPTIONS" do
            conn
            |> merge_vary_header("Origin")
            |> send_resp(:bad_request, "")
            |> halt()
          else
            conn
          end

        {:error, :origin_not_allowed} ->
          if conn.method == "OPTIONS" do
            conn
            |> merge_vary_header("Origin")
            |> send_resp(:forbidden, "")
            |> halt()
          else
            conn
          end
      end
    else
      conn
    end
  end

  defp put_cors_headers(conn, origin) do
    conn
    |> put_resp_header("access-control-allow-origin", origin)
    |> put_resp_header("access-control-allow-methods", @allowed_methods)
    |> put_resp_header("access-control-allow-headers", requested_headers(conn))
    |> put_resp_header("access-control-max-age", @max_age)
    |> merge_vary_header("Origin")
    |> merge_vary_header("Access-Control-Request-Headers")
    |> merge_vary_header("Access-Control-Request-Method")
  end

  defp cors_origin(conn) do
    case get_req_header(conn, "origin") do
      [origin | _] -> allow_origin(origin)
      [] -> {:error, :origin_required}
    end
  end

  defp allow_origin(origin) when is_binary(origin) do
    allowed_origins = Application.get_env(:reseller, __MODULE__, [])[:allowed_origins] || []

    cond do
      origin in allowed_origins ->
        {:ok, origin}

      "*" in allowed_origins ->
        {:ok, origin}

      true ->
        {:error, :origin_not_allowed}
    end
  end

  defp requested_headers(conn) do
    case get_req_header(conn, "access-control-request-headers") do
      [headers | _] -> headers
      [] -> @default_allowed_headers
    end
  end

  defp merge_vary_header(conn, value) do
    vary =
      conn
      |> get_resp_header("vary")
      |> Enum.flat_map(&String.split(&1, ","))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Kernel.++([value])
      |> Enum.uniq()
      |> Enum.join(", ")

    put_resp_header(conn, "vary", vary)
  end
end
