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
      assert user.hashed_password != "very-secure-password"
      assert is_binary(user.hashed_password)
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
  end
end
