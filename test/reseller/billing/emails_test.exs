defmodule Reseller.Billing.EmailsTest do
  use ExUnit.Case, async: true

  alias Reseller.Billing.Emails

  @user %{email: "seller@example.com", plan: "growth", plan_status: "active", addon_credits: %{}}

  describe "welcome_email/2" do
    test "addresses the correct user email" do
      email = Emails.welcome_email(@user, "Growth")
      assert {"", "seller@example.com"} in email.to
    end

    test "includes the plan name in subject" do
      email = Emails.welcome_email(@user, "Growth")
      assert email.subject =~ "Growth"
    end

    test "body includes workspace URL" do
      email = Emails.welcome_email(@user, "Growth")
      assert email.text_body =~ "resellerio.com/app"
    end
  end

  describe "expiring_soon_email/2" do
    test "subject includes days left" do
      email = Emails.expiring_soon_email(@user, 7)
      assert email.subject =~ "7 days"
    end

    test "body includes billing URL" do
      email = Emails.expiring_soon_email(@user, 7)
      assert email.text_body =~ "lemonsqueezy.com/billing"
    end
  end

  describe "expiring_urgent_email/1" do
    test "subject conveys urgency" do
      email = Emails.expiring_urgent_email(@user)
      assert email.subject =~ "2 days"
    end

    test "body includes billing and pricing URLs" do
      email = Emails.expiring_urgent_email(@user)
      assert email.text_body =~ "lemonsqueezy.com/billing"
      assert email.text_body =~ "resellerio.com/pricing"
    end
  end

  describe "expired_email/1" do
    test "subject indicates expiry" do
      email = Emails.expired_email(@user)
      assert email.subject =~ "expired"
    end

    test "body reassures data is safe" do
      email = Emails.expired_email(@user)
      assert email.text_body =~ "safe"
    end

    test "body includes pricing link" do
      email = Emails.expired_email(@user)
      assert email.text_body =~ "resellerio.com/pricing"
    end
  end

  describe "renewal_confirmation_email/2" do
    test "includes plan name in subject" do
      email = Emails.renewal_confirmation_email(@user, "Pro")
      assert email.subject =~ "Pro"
    end

    test "body includes workspace URL" do
      email = Emails.renewal_confirmation_email(@user, "Pro")
      assert email.text_body =~ "resellerio.com/app"
    end
  end

  describe "payment_failed_email/1" do
    test "subject contains action required" do
      email = Emails.payment_failed_email(@user)
      assert email.subject =~ "Action required"
    end

    test "body includes billing portal link" do
      email = Emails.payment_failed_email(@user)
      assert email.text_body =~ "lemonsqueezy.com/billing"
    end
  end
end
