defmodule Mix.Tasks.Reseller.MakeAdminTest do
  use Reseller.DataCase, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Reseller.MakeAdmin
  alias Reseller.Accounts

  describe "run/1" do
    test "grants admin access to an existing user" do
      user = user_fixture(%{"email" => "seller@example.com"})

      output =
        capture_io(fn ->
          MakeAdmin.run([user.email])
        end)

      assert output =~ "Granted admin access to seller@example.com"
      assert Accounts.get_user!(user.id).is_admin
    end

    test "raises when the user does not exist" do
      assert_raise Mix.Error, "No user found with email missing@example.com", fn ->
        MakeAdmin.run(["missing@example.com"])
      end
    end

    test "raises when called without an email" do
      assert_raise Mix.Error, "Usage: mix reseller.make_admin EMAIL", fn ->
        MakeAdmin.run([])
      end
    end
  end
end
