defmodule ResellerWeb.Webhooks.LemonSqueezyControllerTest do
  use ResellerWeb.ConnCase, async: false

  @secret "test_webhook_secret"

  setup do
    Application.put_env(:reseller, Reseller.Billing.LemonSqueezy,
      webhook_secret: @secret,
      variants: %{
        "starter_monthly" => "var_starter_monthly",
        "growth_monthly" => "var_growth_monthly",
        "addon_ai_drafts" => "var_addon_ai_drafts"
      }
    )

    on_exit(fn ->
      Application.delete_env(:reseller, Reseller.Billing.LemonSqueezy)
    end)

    :ok
  end

  defp sign(body), do: :crypto.mac(:hmac, :sha256, @secret, body) |> Base.encode16(case: :lower)

  defp post_webhook(conn, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-signature", sign(body))
    |> post("/webhooks/lemonsqueezy", body)
  end

  defp subscription_payload(event_name, extra_attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          "user_email" => "seller@example.com",
          "customer_id" => 9999,
          "variant_id" => "var_starter_monthly",
          "status" => "active",
          "renews_at" => "2026-12-01T00:00:00Z",
          "trial_ends_at" => nil,
          "custom_data" => %{}
        },
        extra_attrs
      )

    %{
      "meta" => %{"event_name" => event_name},
      "data" => %{
        "id" => "sub_test_123",
        "attributes" => attrs
      }
    }
    |> Jason.encode!()
  end

  describe "POST /webhooks/lemonsqueezy" do
    test "returns 401 with missing signature", %{conn: conn} do
      body = subscription_payload("subscription_created")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/lemonsqueezy", body)

      assert conn.status == 401
    end

    test "returns 401 with invalid signature", %{conn: conn} do
      body = subscription_payload("subscription_created")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-signature", "badbadbadbad")
        |> post("/webhooks/lemonsqueezy", body)

      assert conn.status == 401
    end

    test "returns 200 with valid signature", %{conn: conn} do
      body = subscription_payload("subscription_created")
      conn = post_webhook(conn, body)
      assert conn.status == 200
    end

    test "returns 400 for unparseable body", %{conn: conn} do
      body = "not valid json {"

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("x-signature", sign(body))
        |> post("/webhooks/lemonsqueezy", body)

      assert conn.status == 400
    end

    test "handles unknown event gracefully", %{conn: conn} do
      body =
        %{"meta" => %{"event_name" => "unknown_future_event"}, "data" => %{}} |> Jason.encode!()

      conn = post_webhook(conn, body)
      assert conn.status == 200
    end

    test "subscription_created updates user plan via webhook", %{conn: conn} do
      user = user_fixture(%{"email" => "seller@example.com"})

      body =
        subscription_payload("subscription_created", %{
          "user_email" => user.email,
          "custom_data" => %{"user_id" => user.id},
          "variant_id" => "var_starter_monthly",
          "status" => "active"
        })

      conn = post_webhook(conn, body)
      assert conn.status == 200

      Process.sleep(100)

      updated = Reseller.Accounts.get_user(user.id)
      assert updated.plan == "starter"
      assert updated.plan_status == "active"
      assert updated.ls_subscription_id == "sub_test_123"
    end

    test "subscription_cancelled sets plan_status to canceling", %{conn: conn} do
      user = user_fixture(%{"email" => "canceler@example.com"})

      {:ok, _} =
        Reseller.Billing.apply_subscription(user, %{
          plan: "growth",
          plan_status: "active",
          ls_subscription_id: "sub_cancel_456"
        })

      body =
        %{
          "meta" => %{"event_name" => "subscription_cancelled"},
          "data" => %{
            "id" => "sub_cancel_456",
            "attributes" => %{
              "status" => "cancelled",
              "ends_at" => "2026-12-31T00:00:00Z"
            }
          }
        }
        |> Jason.encode!()

      conn = post_webhook(conn, body)
      assert conn.status == 200

      Process.sleep(100)

      updated = Reseller.Accounts.get_user(user.id)
      assert updated.plan_status == "canceling"
    end

    test "subscription_expired reverts user to free plan", %{conn: conn} do
      user = user_fixture(%{"email" => "expired@example.com"})

      {:ok, _} =
        Reseller.Billing.apply_subscription(user, %{
          plan: "pro",
          plan_status: "active",
          ls_subscription_id: "sub_expire_789"
        })

      body =
        %{
          "meta" => %{"event_name" => "subscription_expired"},
          "data" => %{"id" => "sub_expire_789", "attributes" => %{}}
        }
        |> Jason.encode!()

      conn = post_webhook(conn, body)
      assert conn.status == 200

      Process.sleep(100)

      updated = Reseller.Accounts.get_user(user.id)
      assert updated.plan == "free"
      assert updated.plan_status == "expired"
    end

    test "order_created credits addon to user", %{conn: conn} do
      user = user_fixture(%{"email" => "addon@example.com"})

      body =
        %{
          "meta" => %{"event_name" => "order_created"},
          "data" => %{
            "id" => "order_001",
            "attributes" => %{
              "user_email" => user.email,
              "custom_data" => %{"user_id" => user.id}
            },
            "relationships" => %{
              "order-items" => %{
                "data" => [%{"id" => "var_addon_ai_drafts"}]
              }
            }
          }
        }
        |> Jason.encode!()

      conn = post_webhook(conn, body)
      assert conn.status == 200

      Process.sleep(100)

      updated = Reseller.Accounts.get_user(user.id)
      assert updated.addon_credits["ai_drafts"] == 100
    end

    test "idempotent replay of subscription_created does not error", %{conn: conn} do
      user = user_fixture(%{"email" => "idempotent@example.com"})

      body =
        subscription_payload("subscription_created", %{
          "user_email" => user.email,
          "custom_data" => %{"user_id" => user.id}
        })

      conn1 = post_webhook(conn, body)
      assert conn1.status == 200

      conn2 = post_webhook(build_conn(), body)
      assert conn2.status == 200

      Process.sleep(150)

      updated = Reseller.Accounts.get_user(user.id)
      assert updated.plan == "starter"
    end
  end
end
