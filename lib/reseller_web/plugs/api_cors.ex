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
      conn = register_before_send(conn, &put_cors_headers/1)

      if conn.method == "OPTIONS" do
        conn
        |> put_cors_headers()
        |> send_resp(:no_content, "")
        |> halt()
      else
        conn
      end
    else
      conn
    end
  end

  defp put_cors_headers(conn) do
    conn
    |> put_resp_header("access-control-allow-origin", cors_origin(conn))
    |> put_resp_header("access-control-allow-methods", @allowed_methods)
    |> put_resp_header("access-control-allow-headers", requested_headers(conn))
    |> put_resp_header("access-control-max-age", @max_age)
    |> merge_vary_header("Origin")
    |> merge_vary_header("Access-Control-Request-Headers")
    |> merge_vary_header("Access-Control-Request-Method")
  end

  defp cors_origin(conn) do
    case get_req_header(conn, "origin") do
      [origin | _] -> origin
      [] -> "*"
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
