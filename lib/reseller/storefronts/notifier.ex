defmodule Reseller.Storefronts.Notifier do
  @moduledoc """
  Behaviour and facade for notifying storefront owners of new inquiries.
  """

  alias Reseller.Accounts.User
  alias Reseller.Storefronts.{Storefront, StorefrontInquiry}

  @callback deliver_inquiry_received(
              User.t(),
              Storefront.t(),
              StorefrontInquiry.t(),
              keyword()
            ) ::
              {:ok, term()} | {:error, term()}

  @spec deliver_inquiry_received(User.t(), Storefront.t(), StorefrontInquiry.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def deliver_inquiry_received(user, storefront, inquiry, opts \\ []) do
    notifier(opts).deliver_inquiry_received(user, storefront, inquiry, opts)
  end

  @spec notifier(keyword()) :: module()
  def notifier(opts \\ []) do
    Keyword.get(
      opts,
      :notifier,
      Application.fetch_env!(:reseller, Reseller.Storefronts)[:notifier]
    )
  end
end
