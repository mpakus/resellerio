defmodule Reseller.AccountsTest do
  use Reseller.DataCase, async: true

  alias Reseller.Accounts
  alias Reseller.Accounts.User

  describe "register_user/1" do
    test "creates a user with normalized email and hashed password" do
      assert {:ok, %User{} = user} =
               Accounts.register_user(%{
                 "email" => " Seller@Example.com ",
                 "password" => "very-secure-password"
               })

      assert user.email == "seller@example.com"
      refute user.is_admin
      assert user.selected_marketplaces == ["ebay", "depop", "poshmark"]
      assert user.hashed_password != "very-secure-password"
      assert is_binary(user.hashed_password)
    end

    test "starts a 7-day trial on registration" do
      assert {:ok, %User{} = user} =
               Accounts.register_user(%{
                 "email" => "trial@example.com",
                 "password" => "very-secure-password"
               })

      assert user.plan_status == "trialing"
      assert %DateTime{} = user.trial_ends_at
      diff = DateTime.diff(user.trial_ends_at, DateTime.utc_now(), :second)
      assert diff > 6 * 86_400
      assert diff <= 7 * 86_400 + 5
    end

    test "validates unique email and password length" do
      assert {:ok, _user} =
               Accounts.register_user(%{
                 "email" => "seller@example.com",
                 "password" => "very-secure-password"
               })

      assert {:error, changeset} =
               Accounts.register_user(%{
                 "email" => "seller@example.com",
                 "password" => "short"
               })

      assert "has already been taken" in errors_on(changeset).email
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "ignores admin flags from public registration input" do
      assert {:ok, %User{} = user} =
               Accounts.register_user(%{
                 "email" => "seller@example.com",
                 "password" => "very-secure-password",
                 "is_admin" => true
               })

      refute user.is_admin
    end
  end

  describe "authenticate_user/2" do
    test "authenticates with valid credentials" do
      assert {:ok, user} =
               Accounts.register_user(%{
                 "email" => "seller@example.com",
                 "password" => "very-secure-password"
               })

      assert {:ok, authenticated_user} =
               Accounts.authenticate_user("seller@example.com", "very-secure-password")

      assert authenticated_user.id == user.id
    end

    test "rejects invalid credentials" do
      assert {:ok, _user} =
               Accounts.register_user(%{
                 "email" => "seller@example.com",
                 "password" => "very-secure-password"
               })

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("seller@example.com", "wrong-password")
    end

    test "accepts differently-cased email input" do
      user_fixture(%{"email" => "seller@example.com"})

      assert {:ok, authenticated_user} =
               Accounts.authenticate_user(" Seller@Example.com ", "very-secure-password")

      assert authenticated_user.email == "seller@example.com"
    end
  end

  describe "issue_api_token/2 and get_user_by_api_token/1" do
    test "issues a token and resolves the user from it" do
      assert {:ok, user} =
               Accounts.register_user(%{
                 "email" => "seller@example.com",
                 "password" => "very-secure-password"
               })

      assert {:ok, raw_token, api_token} =
               Accounts.issue_api_token(user, %{"device_name" => "iPhone"})

      assert is_binary(raw_token)
      assert api_token.device_name == "iPhone"
      assert %User{id: fetched_user_id} = Accounts.get_user_by_api_token(raw_token)
      assert fetched_user_id == user.id
    end

    test "updates the token last_used_at when it is used" do
      user = user_fixture()
      {raw_token, api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

      refute api_token.last_used_at

      assert %User{id: fetched_user_id} = Accounts.get_user_by_api_token(raw_token)
      assert fetched_user_id == user.id

      assert Accounts.get_user_by_api_token(raw_token)

      refreshed_token = Reseller.Repo.get!(Reseller.Accounts.ApiToken, api_token.id)
      assert %DateTime{} = refreshed_token.last_used_at
    end

    test "rejects expired tokens" do
      user = user_fixture()
      {raw_token, _api_token} = expired_api_token_fixture(user)

      assert Accounts.get_user_by_api_token(raw_token) == nil
    end

    test "returns nil for malformed tokens" do
      assert Accounts.get_user_by_api_token(nil) == nil
      assert Accounts.get_user_by_api_token(123) == nil
    end
  end

  describe "grant_admin_by_email/1" do
    test "grants admin access to an existing user" do
      assert {:ok, user} =
               Accounts.register_user(%{
                 "email" => "seller@example.com",
                 "password" => "very-secure-password"
               })

      assert {:ok, admin_user} = Accounts.grant_admin_by_email(user.email)
      assert admin_user.is_admin
    end

    test "returns not_found when the user does not exist" do
      assert {:error, :not_found} = Accounts.grant_admin_by_email("missing@example.com")
    end
  end

  describe "admin?/1" do
    test "returns false for nil and non-admin users" do
      refute Accounts.admin?(nil)
      refute Accounts.admin?(user_fixture())
      assert Accounts.admin?(admin_user_fixture())
    end
  end

  describe "update_user_marketplace_settings/2" do
    test "stores a supported marketplace subset for the user" do
      user = user_fixture()

      assert {:ok, updated_user} =
               Accounts.update_user_marketplace_settings(user, %{
                 "selected_marketplaces" => ["mercari", "ebay", "etsy"]
               })

      assert updated_user.selected_marketplaces == ["ebay", "mercari", "etsy"]
      assert Accounts.selected_marketplaces(updated_user) == ["ebay", "mercari", "etsy"]
    end

    test "allows clearing the selected marketplace list" do
      user = user_fixture()

      assert {:ok, updated_user} =
               Accounts.update_user_marketplace_settings(user, %{
                 "selected_marketplaces" => []
               })

      assert updated_user.selected_marketplaces == []
      assert Accounts.selected_marketplaces(updated_user) == []
    end

    test "rejects unsupported marketplaces" do
      user = user_fixture()

      assert {:error, changeset} =
               Accounts.update_user_marketplace_settings(user, %{
                 "selected_marketplaces" => ["mercari", "unknown_market"]
               })

      assert "contains unsupported marketplaces: unknown_market" in errors_on(changeset).selected_marketplaces
    end
  end
end
