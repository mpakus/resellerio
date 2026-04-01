defmodule Reseller.Exports.Notifiers.EmailTest do
  use Reseller.DataCase, async: false

  import Swoosh.TestAssertions

  alias Reseller.Exports.Export
  alias Reseller.Exports.Notifier
  alias Reseller.Exports.Notifiers.Email

  setup :set_swoosh_global

  test "deliver_export_ready/4 sends an export-ready email" do
    user = user_fixture(%{"email" => "mailer@example.com"})

    export = %Export{
      id: 123,
      expires_at: ~U[2026-04-05 12:00:00Z]
    }

    assert {:ok, _response} =
             Email.deliver_export_ready(
               user,
               export,
               "https://cdn.example.test/users/1/exports/123.zip",
               from_email: "exports@test.local"
             )

    assert_email_sent(
      to: "mailer@example.com",
      from: "exports@test.local",
      subject: "Your ResellerIO export is ready",
      text_body: ~r/exports\/123\.zip/
    )
  end

  test "notifier/0 returns the configured notifier" do
    assert Notifier.notifier() == Reseller.Support.Fakes.ExportNotifier
  end
end
