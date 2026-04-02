defmodule Reseller.Billing.Emails do
  @moduledoc """
  Subscription lifecycle email templates.

  All emails are sent via `Reseller.Mailer`. The from address is configured at:

      config :reseller, Reseller.Billing, from_email: "billing@resellerio.com"
  """

  import Swoosh.Email

  alias Reseller.Mailer

  @billing_url "https://app.lemonsqueezy.com/billing"
  @pricing_url "https://resellerio.com/pricing"
  @workspace_url "https://resellerio.com/app"

  @doc """
  Sent immediately after a subscription is created (subscription_created webhook).
  """
  def welcome_email(user, plan_name) do
    new()
    |> to(user.email)
    |> from(from_email())
    |> subject("Welcome to ResellerIO #{plan_name} 🎉")
    |> text_body("""
    Hi there,

    Your ResellerIO #{plan_name} plan is now active. You're all set to start listing faster with AI.

    Open your workspace: #{@workspace_url}

    What's included in your #{plan_name} plan:
    - AI product drafting (recognition, metadata, descriptions)
    - Background removal for clean marketplace images
    - AI lifestyle photo generation
    - Price research from comparable sold listings
    - Marketplace-specific listing copy for 12 channels
    - Your personal seller storefront

    Questions? Reply to this email and we'll help.

    — The ResellerIO team
    """)
  end

  @doc """
  Sent 7 days before subscription expiry.
  """
  def expiring_soon_email(user, days_left) do
    new()
    |> to(user.email)
    |> from(from_email())
    |> subject("Your ResellerIO plan expires in #{days_left} days")
    |> text_body("""
    Hi there,

    Your ResellerIO subscription expires in #{days_left} days.

    To keep your access to AI drafting, lifestyle photos, price research, and marketplace copy, renew now:

    Manage billing: #{@billing_url}

    Your inventory, products, and data will always be preserved — even if you let the plan expire.

    — The ResellerIO team
    """)
  end

  @doc """
  Sent 2 days before subscription expiry (urgent reminder).
  """
  def expiring_urgent_email(user) do
    new()
    |> to(user.email)
    |> from(from_email())
    |> subject("Last chance — your ResellerIO plan expires in 2 days")
    |> text_body("""
    Hi there,

    Your ResellerIO subscription expires in 2 days.

    After expiry, AI processing and lifestyle generation will be paused. Your data is always safe.

    Renew to keep going: #{@billing_url}

    Or check plan options: #{@pricing_url}

    — The ResellerIO team
    """)
  end

  @doc """
  Sent when a subscription has fully expired.
  """
  def expired_email(user) do
    new()
    |> to(user.email)
    |> from(from_email())
    |> subject("Your ResellerIO plan has expired")
    |> text_body("""
    Hi there,

    Your ResellerIO subscription has expired. Your products and data are safe — nothing has been deleted.

    To reactivate AI processing, background removal, and marketplace copy generation, pick a plan:

    See plans: #{@pricing_url}

    — The ResellerIO team
    """)
  end

  @doc """
  Sent when a subscription renews successfully.
  """
  def renewal_confirmation_email(user, plan_name) do
    new()
    |> to(user.email)
    |> from(from_email())
    |> subject("Your ResellerIO #{plan_name} plan has renewed")
    |> text_body("""
    Hi there,

    Your ResellerIO #{plan_name} plan has renewed successfully. Your limits have reset for the new billing cycle.

    Open workspace: #{@workspace_url}

    — The ResellerIO team
    """)
  end

  @doc """
  Sent when a subscription payment fails.
  """
  def payment_failed_email(user) do
    new()
    |> to(user.email)
    |> from(from_email())
    |> subject("Action required — update your ResellerIO billing info")
    |> text_body("""
    Hi there,

    We were unable to process your ResellerIO subscription payment.

    To keep your plan active, please update your billing details:

    Update billing: #{@billing_url}

    If you need help, reply to this email.

    — The ResellerIO team
    """)
  end

  @doc """
  Delivers the given email via Mailer. Returns `{:ok, _}` or `{:error, reason}`.
  """
  def deliver(email), do: Mailer.deliver(email)

  defp from_email do
    Application.get_env(:reseller, Reseller.Billing, [])[:from_email] ||
      "billing@resellerio.com"
  end
end
