defmodule Reseller.Accounts.UserInspectTest do
  use ExUnit.Case, async: true

  alias Reseller.Accounts.User

  test "inspect redacts sensitive password fields" do
    inspected =
      inspect(%User{
        email: "user@example.com",
        password: "super-secret-password",
        hashed_password: "hashed-secret-password"
      })

    assert inspected =~ "user@example.com"
    refute inspected =~ "super-secret-password"
    refute inspected =~ "hashed-secret-password"
  end
end
