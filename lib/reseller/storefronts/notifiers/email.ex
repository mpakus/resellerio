defmodule Reseller.Storefronts.Notifiers.Email do
  @moduledoc """
  Sends storefront inquiry notification emails through Swoosh.
  """

  import Swoosh.Email

  alias Reseller.Mailer
  alias Reseller.Storefronts.{Storefront, StorefrontInquiry}

  @behaviour Reseller.Storefronts.Notifier

  @impl true
  def deliver_inquiry_received(
        user,
        %Storefront{} = storefront,
        %StorefrontInquiry{} = inquiry,
        opts \\ []
      ) do
    from_email =
      Keyword.get(
        opts,
        :from_email,
        Application.fetch_env!(:reseller, Reseller.Storefronts)[:from_email]
      )

    product_line =
      if inquiry.product_id do
        "Product ID: #{inquiry.product_id}\n"
      else
        ""
      end

    email =
      new()
      |> to(user.email)
      |> from(from_email)
      |> subject("New inquiry on #{storefront.title || "your storefront"}")
      |> text_body("""
      You received a new storefront inquiry.

      Storefront: #{storefront.title || storefront.slug}
      #{product_line}
      From: #{inquiry.full_name}
      Contact: #{inquiry.contact}

      Message:
      #{inquiry.message}

      ---
      Source: #{inquiry.source_path}
      """)

    case Mailer.deliver(email) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
