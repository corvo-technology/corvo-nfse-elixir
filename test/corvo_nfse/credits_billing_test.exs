defmodule CorvoNfse.CreditsBillingTest do
  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Resources.{Billing, Credits}

  setup :verify_on_exit!

  @base "http://localhost:4000/v1"

  test "balance reads /credits with the plain data envelope" do
    expect_request(
      json_response(%{
        "data" => %{
          "tenantId" => "ten_1",
          "balance" => 100,
          "overageUnits" => 0,
          "overageAmountCents" => 0,
          "hardLimit" => nil
        }
      })
    )

    assert {:ok, %{"balance" => 100}} = Credits.balance(client())

    request = assert_request()
    assert request.method == :get
    assert request.url == @base <> "/credits"
  end

  test "plans unwraps props from each item" do
    expect_request(
      json_response(%{
        "data" => [%{"props" => %{"id" => "plan_1", "slug" => "scale"}}],
        "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil}
      })
    )

    assert {:ok, page} = Credits.plans(client())
    assert [%{"id" => "plan_1", "slug" => "scale"}] = page.data

    request = assert_request()
    assert request.url == @base <> "/credits/plans"
  end

  test "history and iterate_history walk /credits/history" do
    expect_request(
      json_response(%{
        "data" => [%{"props" => %{"id" => "txn_1"}}],
        "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => "Y3VyMg"}
      })
    )

    assert {:ok, page} = Credits.history(client(), limit: 1)
    assert [%{"id" => "txn_1"}] = page.data
    request = assert_request()
    assert request.url == @base <> "/credits/history?limit=1"

    expect_request(
      json_response(%{
        "data" => [%{"props" => %{"id" => "txn_2"}}],
        "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil}
      })
    )

    assert {:ok, stream} = Credits.iterate_history(client(), limit: 1)
    assert Enum.to_list(stream) == [%{"id" => "txn_2"}]
    request = assert_request()
    assert request.url == @base <> "/credits/history?limit=1"
  end

  test "billing plan and usage" do
    expect_request(
      json_response(%{
        "data" => %{
          "plan" => %{
            "slug" => "starter",
            "name" => "Starter",
            "monthly_allowance" => 100,
            "daily_limit" => nil,
            "max_active_companies" => 3,
            "monthly_price_cents" => 0
          },
          "subscription" => %{
            "status" => "active",
            "paid_until" => nil,
            "cancel_at_period_end" => false,
            "scheduled_plan" => nil,
            "blocked" => false
          },
          "usage" => %{
            "overage_units" => 0,
            "overage_amount_cents" => 0,
            "hard_limit" => nil,
            "credits_used" => 1,
            "credits_reserved" => 0,
            "credits_remaining" => 99,
            "monthly_allowance" => 100,
            "daily_usage" => 0,
            "daily_limit" => nil,
            "active_companies" => 1,
            "max_active_companies" => 3,
            "period_start" => "2026-10-01",
            "period_end" => "2026-10-31"
          }
        }
      })
    )

    assert {:ok, %{"plan" => %{"slug" => "starter"}}} = Billing.plan(client())
    request = assert_request()
    assert request.url == @base <> "/billing/plan"

    expect_request(
      json_response(%{
        "data" => %{
          "canEmit" => true,
          "creditsRemaining" => 99,
          "creditsUsed" => 1,
          "creditsReserved" => 0,
          "monthlyAllowance" => 100,
          "dailyUsage" => 0,
          "dailyLimit" => nil,
          "activeCompanies" => 1,
          "maxActiveCompanies" => 3,
          "periodStart" => "2026-10-01",
          "periodEnd" => "2026-10-31"
        }
      })
    )

    assert {:ok, %{"canEmit" => true}} = Billing.usage(client())
    request = assert_request()
    assert request.url == @base <> "/billing/usage"
  end
end
