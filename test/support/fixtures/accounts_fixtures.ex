defmodule Reseller.AccountsFixtures do
  alias Reseller.Accounts
  alias Reseller.Accounts.ApiToken
  alias Reseller.Repo

  def unique_user_email do
    "seller-#{System.unique_integer([:positive])}@example.com"
  end

  def valid_user_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      "email" => unique_user_email(),
      "password" => "very-secure-password"
    })
  end

  def user_fixture(attrs \\ %{}) do
    attrs
    |> valid_user_attrs()
    |> Accounts.register_user()
    |> case do
      {:ok, user} -> user
      {:error, changeset} -> raise "could not create user fixture: #{inspect(changeset.errors)}"
    end
  end

  def admin_user_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    {:ok, admin_user} = Accounts.grant_admin(user)
    admin_user
  end

  def api_token_fixture(user \\ nil, attrs \\ %{}) do
    user = user || user_fixture()

    case Accounts.issue_api_token(user, attrs) do
      {:ok, raw_token, api_token} ->
        {raw_token, api_token}

      {:error, changeset} ->
        raise "could not create api token fixture: #{inspect(changeset.errors)}"
    end
  end

  def expired_api_token_fixture(user \\ nil, attrs \\ %{}) do
    user = user || user_fixture()
    raw_token = random_token()
    token_hash = :crypto.hash(:sha256, raw_token)

    api_token =
      %ApiToken{}
      |> ApiToken.create_changeset(%{
        token_hash: token_hash,
        context: Map.get(attrs, :context) || Map.get(attrs, "context") || "mobile",
        device_name: Map.get(attrs, :device_name) || Map.get(attrs, "device_name"),
        expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      })
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Repo.insert!()

    {raw_token, api_token}
  end

  defp random_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
