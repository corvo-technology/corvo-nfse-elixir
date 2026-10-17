defmodule CorvoNfse.CalculatePlansTest do
  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Resources.{Invoices, Plans}

  setup :verify_on_exit!

  @base "http://localhost:4000/v1"

  test "calculate returns the estimate and omits a missing customer" do
    expect_request(
      json_response(%{
        "data" => %{
          "preEmission" => true,
          "status" => "ready",
          "taxes" => %{
            "iss" => %{"base" => "15000.00", "rate" => "3", "amount" => "450.00"},
            "ibsTotal" => %{"base" => "14550.00", "amount" => "14.55"}
          },
          "netReceivableAmount" => "15000.00",
          "blocking" => nil
        }
      })
    )

    params = %{
      "companyTaxId" => "11222333000181",
      "service" => %{},
      "amount" => 15_000,
      "competenceDate" => "2026-10-16"
    }

    assert {:ok, estimate} = Invoices.calculate(client(), params)
    assert estimate["status"] == "ready"
    assert estimate["taxes"]["iss"]["amount"] == "450.00"
    refute Map.has_key?(estimate["taxes"]["ibsTotal"], "rate")

    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/invoices/calculate"
    refute Map.has_key?(Jason.decode!(request.body), "customer")
  end

  test "calculate returns a blocked estimate as data, not as an error" do
    expect_request(
      json_response(%{
        "data" => %{
          "status" => "blocked",
          "blocking" => %{"code" => "TAX_RATE_NOT_FOUND", "message" => "x", "step" => "s"}
        }
      })
    )

    assert {:ok, %{"blocking" => %{"code" => "TAX_RATE_NOT_FOUND"}}} =
             Invoices.calculate(client(), %{"amount" => 10})
  end

  test "plans catalog: list, get and quote" do
    expect_requests([
      json_response(%{
        "data" => [%{"slug" => "developer", "monthlyAllowance" => 200}],
        "pagination" => %{"limit" => 5, "hasMore" => false, "nextCursor" => nil}
      }),
      json_response(%{"data" => %{"slug" => "growth", "monthlyTotalCents" => 8990}}),
      json_response(%{"data" => %{"recommended_plan" => "volume"}}),
      json_response(%{"data" => nil})
    ])

    assert {:ok, page} = Plans.list(client(), limit: 5)
    assert [%{"slug" => "developer"}] = page.data
    assert {:ok, %{"monthlyTotalCents" => 8990}} = Plans.get(client(), "growth")
    assert {:ok, %{"recommended_plan" => "volume"}} = Plans.quote(client(), 20_000)
    assert {:ok, nil} = Plans.quote(client(), 0)

    urls = Enum.map(pop_requests(), & &1.url)

    assert urls == [
             @base <> "/plans?limit=5",
             @base <> "/plans/growth",
             @base <> "/plans/quote?volume=20000",
             @base <> "/plans/quote?volume=0"
           ]
  end
end
