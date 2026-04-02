defmodule Reseller.Billing.LemonSqueezy do
  @moduledoc """
  HTTP client and URL builder for LemonSqueezy checkout flows.

  ## Configuration

      config :reseller, Reseller.Billing.LemonSqueezy,
        api_key: "...",
        webhook_secret: "...",
        store_id: "...",
        variants: %{
          "starter_monthly" => "12345",
          "starter_annual"  => "12346",
          "growth_monthly"  => "12347",
          "growth_annual"   => "12348",
          "pro_monthly"     => "12349",
          "pro_annual"      => "12350",
          "addon_ai_drafts"     => "12351",
          "addon_lifestyle"     => "12352",
          "addon_bg_removals"   => "12353",
          "addon_extra_seat"    => "12354"
        }

  All environment variable bindings are in `config/runtime.exs`.
  """

  @checkout_redirect_url "https://resellerio.com/app?checkout=success"
  @checkout_cancel_url "https://resellerio.com/pricing"

  @doc """
  Returns the LemonSqueezy hosted checkout URL for the given plan key and period.

  The user's `id` and `email` are embedded so the webhook handler can attribute
  the subscription without relying solely on email matching.

  ## Example

      checkout_url("growth", :monthly, user)
      #=> {:ok, "https://checkout.lemonsqueezy.com/buy/..."}
  """
  @spec checkout_url(String.t(), :monthly | :annual, map()) ::
          {:ok, String.t()} | {:error, :variant_not_configured} | {:error, term()}
  def checkout_url(plan, period, user) do
    variant_key = "#{plan}_#{period}"

    case variant_id(variant_key) do
      nil ->
        {:error, :variant_not_configured}

      vid ->
        build_checkout_url(vid, user)
    end
  end

  @doc """
  Returns the checkout URL for a one-time add-on pack purchase.
  """
  @spec addon_checkout_url(String.t(), map()) ::
          {:ok, String.t()} | {:error, :variant_not_configured} | {:error, term()}
  def addon_checkout_url(addon_key, user) do
    case variant_id("addon_#{addon_key}") do
      nil ->
        {:error, :variant_not_configured}

      vid ->
        build_checkout_url(vid, user)
    end
  end

  defp build_checkout_url(variant_id, user) do
    params = %{
      "checkout[custom][user_id]" => to_string(user.id),
      "checkout[email]" => user.email,
      "checkout[redirect_url]" => @checkout_redirect_url,
      "checkout[cancel_url]" => @checkout_cancel_url
    }

    query = URI.encode_query(params)
    url = "https://checkout.lemonsqueezy.com/buy/#{variant_id}?#{query}"
    {:ok, url}
  end

  defp variant_id(key) do
    config()[:variants][key]
  end

  defp config do
    Application.get_env(:reseller, __MODULE__, [])
  end
end
