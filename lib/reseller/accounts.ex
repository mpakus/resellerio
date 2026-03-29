defmodule Reseller.Accounts do
  import Ecto.Query, warn: false

  alias Reseller.Accounts.ApiToken
  alias Reseller.Accounts.Password
  alias Reseller.Accounts.User
  alias Reseller.Repo

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    if user && Password.valid_password?(user.hashed_password, password) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  def authenticate_user(_, _), do: {:error, :invalid_credentials}

  def issue_api_token(%User{} = user, attrs \\ %{}) do
    raw_token = generate_raw_token()
    token_hash = hash_token(raw_token)
    expires_at = DateTime.add(DateTime.utc_now(), api_token_ttl_days() * 86_400, :second)

    api_token =
      %ApiToken{}
      |> ApiToken.create_changeset(%{
        token_hash: token_hash,
        context: Map.get(attrs, :context) || Map.get(attrs, "context") || "mobile",
        device_name: Map.get(attrs, :device_name) || Map.get(attrs, "device_name"),
        expires_at: expires_at
      })
      |> Ecto.Changeset.put_assoc(:user, user)

    case Repo.insert(api_token) do
      {:ok, api_token} -> {:ok, raw_token, api_token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def get_user_by_api_token(raw_token) when is_binary(raw_token) do
    now = DateTime.utc_now()
    token_hash = hash_token(raw_token)

    query =
      from user in User,
        join: api_token in ApiToken,
        on: api_token.user_id == user.id,
        where: api_token.token_hash == ^token_hash and api_token.expires_at > ^now

    case Repo.one(query) do
      nil ->
        nil

      user ->
        touch_api_token_last_used_at(token_hash, now)
        user
    end
  end

  def get_user_by_api_token(_), do: nil

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: normalize_email(email))
  end

  def get_user_by_email(_), do: nil

  def admin?(%User{is_admin: is_admin}), do: is_admin
  def admin?(_), do: false

  def grant_admin(%User{} = user) do
    user
    |> Ecto.Changeset.change(is_admin: true)
    |> Repo.update()
  end

  def grant_admin_by_email(email) when is_binary(email) do
    case get_user_by_email(email) do
      nil -> {:error, :not_found}
      user -> grant_admin(user)
    end
  end

  defp touch_api_token_last_used_at(token_hash, now) do
    from(api_token in ApiToken, where: api_token.token_hash == ^token_hash)
    |> Repo.update_all(set: [last_used_at: now])
  end

  defp generate_raw_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp hash_token(raw_token), do: :crypto.hash(:sha256, raw_token)

  defp normalize_email(email) do
    email
    |> String.trim()
    |> String.downcase()
  end

  defp api_token_ttl_days do
    Application.get_env(:reseller, :api_token_ttl_days, 30)
  end
end
