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
          "balance" => 105,
          "planRemaining" => 100,
          "avulsoBalance" => 5,
          "hardLimit" => 0
        }
      })
    )

    assert {:ok, %{"balance" => 105, "planRemaining" => 100, "avulsoBalance" => 5} = balance} =
             Credits.balance(client())

    refute Map.has_key?(balance, "overageUnits")

    request = assert_request()
    assert request.method == :get
    assert request.url == @base <> "/credits"
  end

  test "plans returns the items of the page" do
    expect_request(
      json_response(%{
        "data" => [%{"id" => "plan_1", "slug" => "equipe"}],
        "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil}
      })
    )

    assert {:ok, page} = Credits.plans(client())
    assert [%{"id" => "plan_1", "slug" => "equipe"}] = page.data

    request = assert_request()
    assert request.url == @base <> "/credits/plans"
  end

  test "history and iterate_history walk /credits/history" do
    expect_request(
      json_response(%{
        "data" => [%{"id" => "txn_1"}],
        "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => "Y3VyMg"}
      })
    )

    assert {:ok, page} = Credits.history(client(), limit: 1)
    assert [%{"id" => "txn_1"}] = page.data
    request = assert_request()
    assert request.url == @base <> "/credits/history?limit=1"

    expect_request(
      json_response(%{
        "data" => [%{"id" => "txn_2"}],
        "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil}
      })
    )

    assert {:ok, stream} = Credits.iterate_history(client(), limit: 1)
    assert Enum.to_list(stream) == [%{"id" => "txn_2"}]
    request = assert_request()
    assert request.url == @base <> "/credits/history?limit=1"
  end

  test "preview_purchase is a GET with the units in the query" do
    expect_request(
      json_response(%{"data" => %{"units" => 10, "unitPriceCents" => 99, "totalCents" => 990}})
    )

    assert {:ok, %{"units" => 10, "totalCents" => 990}} = Credits.preview_purchase(client(), 10)

    request = assert_request()
    assert request.method == :get
    assert request.url == @base <> "/credits/purchase/preview?units=10"
    assert request.body == nil
  end

  test "billing plan without a plan assigned is a NO_PLAN_ASSIGNED error" do
    expect_request(
      json_response(
        %{
          "statusCode" => 404,
          "code" => "NO_PLAN_ASSIGNED",
          "message" => "no plan",
          "requestId" => "r1"
        },
        status: 404
      )
    )

    assert {:error, %CorvoNfse.Error{status: 404, code: "NO_PLAN_ASSIGNED"}} =
             Billing.plan(client())
  end

  test "billing plan and usage" do
    expect_request(
      json_response(%{
        "data" => %{
          "plan" => %{
            "slug" => "solo",
            "name" => "Solo",
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
            "blocked" => false,
            "stripe_portal_available" => false,
            "stripe_subscription" => false,
            "pix_subscription" => nil
          },
          "usage" => %{
            "avulso_balance" => 4,
            "hard_limit" => 0,
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

    assert {:ok, %{"plan" => %{"slug" => "solo"}, "usage" => %{"avulso_balance" => 4}}} =
             Billing.plan(client())

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
