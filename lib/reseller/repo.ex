defmodule Reseller.Repo do
  use Ecto.Repo,
    otp_app: :reseller,
    adapter: Ecto.Adapters.Postgres
end
