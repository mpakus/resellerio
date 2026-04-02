defmodule ResellerWeb.Webhooks.LemonSqueezyController do
  use ResellerWeb, :controller

  require Logger

  alias Reseller.Billing.WebhookHandler

  @doc """
  Receives a LemonSqueezy webhook POST, verifies the HMAC-SHA256 signature,
  and dispatches to the appropriate event handler.

  LemonSqueezy signs each payload using the webhook secret configured in the
  dashboard. The signature is delivered in the `X-Signature` header as a
  hex-encoded HMAC-SHA256 of the raw request body.
  """
  def handle(conn, _params) do
    {raw_body, conn} = get_raw_body(conn)
    signature = get_req_header(conn, "x-signature") |> List.first()

    case verify_signature(raw_body, signature) do
      :ok ->
        dispatch(conn, raw_body)

      :error ->
        Logger.warning("[LemonSqueezy webhook] Invalid signature")
        send_resp(conn, 401, "Invalid signature")
    end
  end

  defp get_raw_body(conn) do
    case conn.assigns[:raw_body] do
      body when is_binary(body) and body != "" ->
        {body, conn}

      _ ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        {body, conn}
    end
  end

  defp dispatch(conn, raw_body) do
    case Jason.decode(raw_body) do
      {:ok, payload} ->
        event_name = get_in(payload, ["meta", "event_name"])
        parent = self()

        Task.start(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Reseller.Repo, parent, self())
          WebhookHandler.handle(event_name, payload)
        end)

        send_resp(conn, 200, "ok")

      {:error, _} ->
        Logger.warning("[LemonSqueezy webhook] Unparseable body")
        send_resp(conn, 400, "Bad request")
    end
  end

  defp verify_signature(_raw_body, nil), do: :error

  defp verify_signature(raw_body, signature) do
    secret = Application.get_env(:reseller, Reseller.Billing.LemonSqueezy, [])[:webhook_secret]

    if is_nil(secret) or secret == "" do
      Logger.warning("[LemonSqueezy webhook] LEMONSQUEEZY_WEBHOOK_SECRET not configured")
      :error
    else
      expected =
        :crypto.mac(:hmac, :sha256, secret, raw_body)
        |> Base.encode16(case: :lower)

      if Plug.Crypto.secure_compare(expected, String.downcase(signature)) do
        :ok
      else
        :error
      end
    end
  end
end
