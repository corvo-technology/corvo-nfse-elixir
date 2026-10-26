defmodule CorvoNfse.InvoicesTest do
  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Resources.Invoices

  setup :verify_on_exit!

  @base "http://localhost:4000/v1"

  test "create returns the invoice and sends the wire body unchanged" do
    expect_request(json_response(%{"data" => %{"id" => "inv_1", "status" => "queued"}}))

    assert {:ok, %{"id" => "inv_1", "status" => "queued"}} =
             Invoices.create(client(), invoice_params(), idempotency_key: "idem_1")

    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/invoices"
    assert {"idempotency-key", "idem_1"} in request.headers

    assert Jason.decode!(request.body) == %{
             "customer" => %{"name" => "Ada", "taxId" => "12345678900"},
             "service" => %{"code" => "0101"},
             "amount" => 10.5,
             "competenceDate" => "2026-10-01"
           }
  end

  test "list maps snake_case filters onto camelCase query keys" do
    expect_request(json_response(%{"data" => [], "pagination" => nil}))

    assert {:ok, %{data: []}} =
             Invoices.list(client(),
               company_id: "comp_1",
               status: "authorized",
               external_id: "ext_9",
               limit: 5
             )

    request = assert_request()

    assert request.url ==
             @base <> "/invoices?companyId=comp_1&status=authorized&externalId=ext_9&limit=5"
  end

  test "events lives under the invoice path" do
    expect_request(
      json_response(%{
        "data" => [%{"id" => "evt_1"}],
        "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil}
      })
    )

    assert {:ok, page} = Invoices.events(client(), "inv_1", limit: 1)
    assert [%{"id" => "evt_1"}] = page.data

    request = assert_request()
    assert request.url == @base <> "/invoices/inv_1/events?limit=1"
  end

  test "pdf and xml request the document paths" do
    expect_request(
      {:ok, %{status: 200, headers: [{"content-type", "application/pdf"}], body: "%PDF"}}
    )

    assert {:ok, %{body: "%PDF"}} = Invoices.pdf(client(), "inv_1")
    request = assert_request()
    assert request.url == @base <> "/invoices/inv_1/pdf"

    expect_request({:ok, %{status: 200, headers: [{"content-type", "text/xml"}], body: "<DPS/>"}})

    assert {:ok, %{body: "<DPS/>"}} = Invoices.xml(client(), "inv_1")
    request = assert_request()
    assert request.url == @base <> "/invoices/inv_1/xml"
  end

  test "download_url posts the requested format" do
    expect_request(json_response(%{"data" => %{"url" => "https://cdn.example/x.pdf"}}))

    assert {:ok, %{"url" => "https://cdn.example/x.pdf"}} =
             Invoices.download_url(client(), "inv_1", :pdf)

    request = assert_request()
    assert request.url == @base <> "/invoices/inv_1/download-url"
    assert Jason.decode!(request.body) == %{"format" => "pdf"}
  end

  test "send_email posts to the email path" do
    expect_request(json_response(%{"data" => %{"queued" => true}}))

    assert {:ok, %{"queued" => true}} = Invoices.send_email(client(), "inv_1")

    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/invoices/inv_1/email"
    assert request.body == nil
  end

  test "iterate streams the invoices" do
    expect_requests([
      json_response(%{
        "data" => [%{"id" => "inv_1"}],
        "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil}
      })
    ])

    assert {:ok, stream} = Invoices.iterate(client(), limit: 1)
    assert Enum.to_list(stream) == [%{"id" => "inv_1"}]
  end

  defp invoice_params do
    %{
      "customer" => %{"name" => "Ada", "taxId" => "12345678900"},
      "service" => %{"code" => "0101"},
      "amount" => 10.5,
      "competenceDate" => "2026-10-01"
    }
  end

  test "create_batch posts the items without an Idempotency-Key header" do
    expect_request(
      json_response(
        %{
          "data" => %{
            "total" => 2,
            "accepted" => 1,
            "rejected" => 1,
            "results" => [
              %{
                "index" => 0,
                "status" => "accepted",
                "replayed" => true,
                "invoice" => %{"id" => "inv_1"}
              },
              %{
                "index" => 1,
                "status" => "rejected",
                "error" => %{
                  "code" => "ERROR_VALIDATION",
                  "message" => "Request validation failed"
                }
              }
            ]
          }
        },
        status: 202
      )
    )

    item = %{
      "companyTaxId" => "11222333000181",
      "idempotencyKey" => "sheet-row-2",
      "service" => %{"description" => "Consultoria"},
      "amount" => 150.5,
      "deduction" => 20,
      "competenceDate" => "2026-10-01"
    }

    assert {:ok, %{"total" => 2, "results" => [first, second]}} =
             Invoices.create_batch(client(), [item])

    assert first["replayed"] == true
    assert second["error"]["code"] == "ERROR_VALIDATION"

    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/invoices/batches"
    refute Enum.any?(request.headers, fn {name, _} -> name == "idempotency-key" end)
    assert Jason.decode!(request.body) == %{"invoices" => [item]}
  end

  test "cancel posts the reason and description" do
    expect_request(
      json_response(%{"data" => %{"id" => "inv_1", "status" => "cancelling"}}, status: 202)
    )

    assert {:ok, %{"status" => "cancelling"}} =
             Invoices.cancel(client(), "inv_1", "issue_error",
               description: "Wrong amount on the invoice"
             )

    request = assert_request()
    assert request.method == :post
    assert request.url == @base <> "/invoices/inv_1/cancel"

    assert Jason.decode!(request.body) == %{
             "reason" => "issue_error",
             "description" => "Wrong amount on the invoice"
           }
  end

  test "cancel omits the description when not given" do
    expect_request(json_response(%{"data" => %{"id" => "inv_1", "status" => "cancelled"}}))

    assert {:ok, %{"status" => "cancelled"}} = Invoices.cancel(client(), "inv_1", "other")

    assert Jason.decode!(assert_request().body) == %{"reason" => "other"}
  end
end
