defmodule Reseller.Exports.Notifier do
  @moduledoc """
  Behaviour and facade for notifying users when exports are ready.
  """

  @callback deliver_export_ready(
              Reseller.Accounts.User.t(),
              Reseller.Exports.Export.t(),
              String.t(),
              keyword()
            ) ::
              {:ok, term()} | {:error, term()}

  @spec deliver_export_ready(
          Reseller.Accounts.User.t(),
          Reseller.Exports.Export.t(),
          String.t(),
          keyword()
        ) ::
          {:ok, term()} | {:error, term()}
  def deliver_export_ready(user, export, download_url, opts \\ []) do
    notifier(opts).deliver_export_ready(user, export, download_url, opts)
  end

  @spec notifier(keyword()) :: module()
  def notifier(opts \\ []) do
    Keyword.get(opts, :notifier, Application.fetch_env!(:reseller, Reseller.Exports)[:notifier])
  end
end
