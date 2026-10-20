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

  describe "cancel" do
    test "posts the reason and description and returns the cancelled invoice (200)" do
      expect_request(
        json_response(%{
          "data" =>
            cancelled_invoice(%{
              "status" => "cancelled",
              "cancellationReason" => "issue_error",
              "cancellationDescription" => "Wrong amount on the invoice",
              "cancelledAt" => "2026-10-20T12:00:00.000Z"
            })
        })
      )

      assert {:ok, invoice} =
               Invoices.cancel(client(), "inv_1", %{
                 reason: :issue_error,
                 description: "Wrong amount on the invoice"
               })

      assert invoice["status"] == "cancelled"
      assert invoice["cancellationReason"] == "issue_error"
      assert invoice["cancelledAt"] == "2026-10-20T12:00:00.000Z"

      request = assert_request()
      assert request.method == :post
      assert request.url == @base <> "/invoices/inv_1/cancel"

      assert Jason.decode!(request.body) == %{
               "reason" => "issue_error",
               "description" => "Wrong amount on the invoice"
             }
    end

    test "sends only the reason when there is no description" do
      expect_request(json_response(%{"data" => cancelled_invoice(%{"status" => "cancelled"})}))

      assert {:ok, %{"status" => "cancelled"}} =
               Invoices.cancel(client(), "inv_1", %{"reason" => "other"})

      request = assert_request()
      assert Jason.decode!(request.body) == %{"reason" => "other"}
    end

    test "escapes the invoice id in the path" do
      expect_request(json_response(%{"data" => cancelled_invoice(%{"status" => "cancelled"})}))

      assert {:ok, _invoice} = Invoices.cancel(client(), "inv/1", %{reason: :other})

      request = assert_request()
      assert request.url == @base <> "/invoices/inv%2F1/cancel"
    end

    test "returns the cancelling invoice on 202" do
      expect_request(
        json_response(
          %{
            "data" =>
              cancelled_invoice(%{
                "status" => "cancelling",
                "cancellationReason" => "service_not_provided",
                "cancellationDescription" => "Service was never delivered",
                "cancellationRequestedAt" => "2026-10-20T12:00:00.000Z"
              })
          },
          status: 202
        )
      )

      assert {:ok, invoice} =
               Invoices.cancel(client(), "inv_1", %{
                 reason: :service_not_provided,
                 description: "Service was never delivered"
               })

      assert invoice["status"] == "cancelling"
      assert invoice["cancellationReason"] == "service_not_provided"
      assert invoice["cancellationRequestedAt"] == "2026-10-20T12:00:00.000Z"
      assert invoice["cancelledAt"] == nil
    end

    test "returns a processing invoice with cancellationRequestedAt on 202" do
      expect_request(
        json_response(
          %{
            "data" =>
              cancelled_invoice(%{
                "status" => "processing",
                "cancellationReason" => "other",
                "cancellationRequestedAt" => "2026-10-20T12:00:00.000Z"
              })
          },
          status: 202
        )
      )

      assert {:ok,
              %{"status" => "processing", "cancellationRequestedAt" => "2026-10-20T12:00:00.000Z"}} =
               Invoices.cancel(client(), "inv_1", %{
                 reason: :other,
                 description: "Customer gave up"
               })
    end

    test "surfaces 409 ERROR_INVOICE_NOT_CANCELLABLE as a CorvoNfse.Error" do
      expect_request(
        json_response(
          %{
            "code" => "ERROR_INVOICE_NOT_CANCELLABLE",
            "message" => "Invoice cannot be cancelled in its current status",
            "requestId" => "req_1"
          },
          status: 409
        )
      )

      assert {:error,
              %CorvoNfse.Error{
                status: 409,
                code: "ERROR_INVOICE_NOT_CANCELLABLE",
                request_id: "req_1"
              }} = Invoices.cancel(client(), "inv_1", %{reason: :issue_error})
    end

    test "surfaces 422 for an invalid description as a CorvoNfse.Error" do
      expect_request(
        json_response(
          %{"code" => "ERROR_VALIDATION", "message" => "description must be 15-255 characters"},
          status: 422
        )
      )

      assert {:error, %CorvoNfse.Error{status: 422, code: "ERROR_VALIDATION"}} =
               Invoices.cancel(client(), "inv_1", %{reason: :other, description: "short"})
    end
  end

  describe "get of a cancelled or cancelling invoice" do
    test "parses a cancelled invoice with the cancellation fields" do
      expect_request(
        json_response(%{
          "data" =>
            cancelled_invoice(%{
              "status" => "cancelled",
              "cancellationReason" => "issue_error",
              "cancellationDescription" => "Wrong amount on the invoice",
              "cancellationRequestedAt" => "2026-10-20T11:59:00.000Z",
              "cancelledAt" => "2026-10-20T12:00:00.000Z"
            })
        })
      )

      assert {:ok, invoice} = Invoices.get(client(), "inv_1")
      assert invoice["status"] == "cancelled"
      assert invoice["cancellationReason"] == "issue_error"
      assert invoice["cancellationDescription"] == "Wrong amount on the invoice"
      assert invoice["cancellationRequestedAt"] == "2026-10-20T11:59:00.000Z"
      assert invoice["cancelledAt"] == "2026-10-20T12:00:00.000Z"

      request = assert_request()
      assert request.method == :get
      assert request.url == @base <> "/invoices/inv_1"
    end

    test "parses a cancelling invoice with null cancelledAt" do
      expect_request(
        json_response(%{
          "data" =>
            cancelled_invoice(%{
              "status" => "cancelling",
              "cancellationReason" => "other",
              "cancellationDescription" => "Customer gave up the order",
              "cancellationRequestedAt" => "2026-10-20T12:00:00.000Z",
              "cancelledAt" => nil
            })
        })
      )

      assert {:ok, invoice} = Invoices.get(client(), "inv_1")
      assert invoice["status"] == "cancelling"
      assert invoice["cancellationReason"] == "other"
      assert invoice["cancellationDescription"] == "Customer gave up the order"
      assert invoice["cancellationRequestedAt"] == "2026-10-20T12:00:00.000Z"
      assert Map.has_key?(invoice, "cancelledAt")
      assert invoice["cancelledAt"] == nil
    end

    test "the invoice struct documents the cancellation fields" do
      invoice = %CorvoNfse.Types.Invoice{
        status: "cancelled",
        cancellationReason: "issue_error",
        cancellationDescription: "Wrong amount on the invoice",
        cancelledAt: "2026-10-20T12:00:00.000Z",
        cancellationRequestedAt: "2026-10-20T11:59:00.000Z"
      }

      assert invoice.cancellationReason == "issue_error"
      assert invoice.cancelledAt == "2026-10-20T12:00:00.000Z"
    end
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

  defp cancelled_invoice(overrides) do
    Map.merge(
      %{
        "id" => "inv_1",
        "companyId" => "comp_1",
        "environment" => "test",
        "status" => "authorized",
        "amount" => 150.5,
        "currency" => "BRL",
        "competenceDate" => "2026-10-16",
        "nfseNumber" => 42,
        "lastErrorCode" => nil,
        "lastErrorMessage" => nil,
        "cancellationReason" => nil,
        "cancellationDescription" => nil,
        "cancelledAt" => nil,
        "cancellationRequestedAt" => nil,
        "createdAt" => "2026-10-16T10:00:00.000Z",
        "updatedAt" => "2026-10-20T12:00:00.000Z"
      },
      overrides
    )
  end

  defp invoice_params do
    %{
      "customer" => %{"name" => "Ada", "taxId" => "12345678900"},
      "service" => %{"code" => "0101"},
      "amount" => 10.5,
      "competenceDate" => "2026-10-01"
    }
  end
end
