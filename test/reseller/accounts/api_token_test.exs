defmodule Reseller.Accounts.ApiTokenTest do
  use Reseller.DataCase, async: true

  alias Reseller.Accounts.ApiToken

  describe "create_changeset/2" do
    test "requires the token hash and expiry" do
      changeset = ApiToken.create_changeset(%ApiToken{}, %{})

      refute changeset.valid?

      assert errors_on(changeset) == %{
               expires_at: ["can't be blank"],
               token_hash: ["can't be blank"]
             }
    end
  end

  describe "update_changeset/3" do
    test "requires expiry when editing a token" do
      changeset = ApiToken.update_changeset(%ApiToken{}, %{"device_name" => "Phone"}, %{})

      refute changeset.valid?

      assert errors_on(changeset) == %{expires_at: ["can't be blank"]}
    end
  end
end
