defmodule Reseller.Accounts.UserTest do
  use Reseller.DataCase, async: true

  alias Reseller.Accounts.User

  describe "create_changeset/3" do
    test "allows admins to create admin users through the admin schema changeset" do
      changeset =
        User.create_changeset(
          %User{},
          %{
            "email" => "Admin@Example.com ",
            "password" => "very-secure-password",
            "is_admin" => true
          },
          %{}
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :email) == "admin@example.com"
      assert Ecto.Changeset.get_field(changeset, :is_admin)
      assert is_binary(Ecto.Changeset.get_field(changeset, :hashed_password))
    end
  end

  describe "update_changeset/3" do
    test "keeps the existing password when a blank password is submitted" do
      user = user_fixture()

      changeset =
        User.update_changeset(
          user,
          %{
            "email" => "updated@example.com",
            "password" => "   "
          },
          %{}
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :email) == "updated@example.com"
      assert Ecto.Changeset.get_change(changeset, :password) == nil
      assert Ecto.Changeset.get_change(changeset, :hashed_password) == nil
    end

    test "validates password length when a new password is provided" do
      user = user_fixture()

      changeset =
        User.update_changeset(
          user,
          %{
            "email" => user.email,
            "password" => "short"
          },
          %{}
        )

      refute changeset.valid?
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end
  end
end
