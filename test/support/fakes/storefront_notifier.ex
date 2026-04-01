defmodule Reseller.Support.Fakes.StorefrontNotifier do
  @behaviour Reseller.Storefronts.Notifier

  @impl true
  def deliver_inquiry_received(user, storefront, inquiry, _opts) do
    send(self(), {:storefront_notifier_called, user.email, storefront.id, inquiry.id})
    {:ok, :delivered}
  end
end
