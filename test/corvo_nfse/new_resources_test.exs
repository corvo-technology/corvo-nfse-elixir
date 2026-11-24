defmodule CorvoNfse.NewResourcesTest do
  @moduledoc "Request/response behavior of the operations added in API contract 0.3.0."

  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Error

  alias CorvoNfse.Resources.{
    AccountantPackage,
    Cnpj,
    Customers,
    DpsSequence,
    FiscalPortal,
    FiscalProfiles,
    Imports,
    IntegrationConnections,
    IntegrationOperations,
    Integrations,
    InvoicePackage,
    Invoices,
    Schedules,
    ServiceFavorites,
    ServiceTaxProfiles
  }

  setup :verify_on_exit!

  @base "http://localhost:4000/v1"
  @company "11111111-1111-1111-1111-111111111111"
  @page %{"limit" => 2, "hasMore" => false, "nextCursor" => nil}

  defp json_body(request), do: Jason.decode!(request.body)

  defp header(request, name) do
    case List.keyfind(request.headers, name, 0) do
      {_name, value} -> value
      nil -> nil
    end
  end

  describe "common request shape" do
    test "every new request carries x-api-key and the SDK user-agent" do
      expect_request(json_response(%{"data" => %{"status" => "up"}}))
      assert {:ok, %{"status" => "up"}} = FiscalPortal.status(client())

      request = assert_request()
      assert request.method == :get
      assert request.url == @base <> "/fiscal-portal/status"
      assert {"x-api-key", api_key()} in request.headers
      assert header(request, "user-agent") == "corvo-nfse-elixir/" <> CorvoNfse.version()
    end

    test "an API error keeps code, request id and Retry-After" do
      expect_request(
        json_response(
          %{
            "statusCode" => 429,
            "code" => "ERROR_RATE_LIMITED",
            "message" => "slow down",
            "requestId" => "req_9"
          },
          status: 429,
          headers: [{"retry-after", "7"}]
        )
      )

      assert {:error,
              %Error{status: 429, code: "ERROR_RATE_LIMITED", request_id: "req_9", retry_after: 7}} =
               Customers.get(client(), "52998224725")
    end

    test "codes without the ERROR_ prefix are passed through" do
      expect_request(
        json_response(
          %{
            "statusCode" => 422,
            "code" => "CNPJ_INVALID",
            "message" => "bad",
            "requestId" => "r"
          },
          status: 422
        )
      )

      assert {:error, %Error{status: 422, code: "CNPJ_INVALID"}} = Cnpj.lookup(client(), "1")
    end
  end

  describe "customers and CNPJ" do
    test "cnpj lookup" do
      expect_request(json_response(%{"data" => %{"legalName" => "Acme Ltda", "active" => true}}))

      assert {:ok, %{"legalName" => "Acme Ltda"}} = Cnpj.lookup(client(), "11222333000181")

      assert assert_request().url == @base <> "/cnpj/11222333000181"
    end

    test "search sends search/limit/cursor and parses the page" do
      expect_request(
        json_response(%{
          "data" => [%{"taxId" => "52998224725", "name" => "Ada"}],
          "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => "1"}
        })
      )

      assert {:ok, page} =
               Customers.search(client(), search: "ada lovelace", limit: 1, cursor: "0")

      assert [%{"taxId" => "52998224725"}] = page.data
      assert page.pagination == %{"limit" => 1, "hasMore" => true, "nextCursor" => "1"}

      assert assert_request().url == @base <> "/customers?search=ada+lovelace&limit=1&cursor=0"
    end

    test "iterate follows the offset cursor untouched" do
      expect_requests([
        json_response(%{
          "data" => [%{"taxId" => "1"}],
          "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => "1"}
        }),
        json_response(%{"data" => [%{"taxId" => "2"}], "pagination" => @page})
      ])

      assert {:ok, stream} = Customers.iterate(client(), limit: 1)
      assert Enum.map(stream, & &1["taxId"]) == ["1", "2"]

      assert [first, second] = pop_requests()
      assert first.url == @base <> "/customers?limit=1"
      assert second.url == @base <> "/customers?limit=1&cursor=1"
    end

    test "get, update and remove" do
      expect_request(json_response(%{"data" => %{"taxId" => "52998224725"}}))
      assert {:ok, %{"taxId" => "52998224725"}} = Customers.get(client(), "52998224725")
      request = assert_request()
      assert {request.method, request.url} == {:get, @base <> "/customers/52998224725"}

      expect_request(json_response(%{"data" => %{"name" => "Ada L."}}))

      assert {:ok, _} =
               Customers.update(client(), "52998224725", %{"name" => "Ada L.", "email" => nil})

      request = assert_request()
      assert {request.method, request.url} == {:patch, @base <> "/customers/52998224725"}
      assert json_body(request) == %{"name" => "Ada L.", "email" => nil}

      expect_request(json_response(%{"data" => %{"deleted" => true}}))
      assert {:ok, %{"deleted" => true}} = Customers.remove(client(), "52998224725")
      request = assert_request()
      assert {request.method, request.url} == {:delete, @base <> "/customers/52998224725"}
    end
  end

  describe "service favorites" do
    test "list, create and remove" do
      expect_request(json_response(%{"data" => [%{"id" => "f1", "label" => "Consultoria"}]}))
      assert {:ok, [%{"id" => "f1"}]} = ServiceFavorites.list(client(), @company)
      assert assert_request().url == @base <> "/companies/#{@company}/service-favorites"

      expect_request(json_response(%{"data" => %{"id" => "f2"}}, status: 201))

      params = %{"label" => "Consultoria", "serviceCode" => "010101", "description" => "TI"}
      assert {:ok, %{"id" => "f2"}} = ServiceFavorites.create(client(), @company, params)
      request = assert_request()
      assert request.method == :post
      assert json_body(request) == params

      expect_request(json_response(%{"data" => %{"deleted" => true}}))
      assert {:ok, _} = ServiceFavorites.remove(client(), @company, "f2")
      request = assert_request()
      assert request.method == :delete
      assert request.url == @base <> "/companies/#{@company}/service-favorites/f2"
    end
  end

  describe "accountant package" do
    test "get, update (PUT, nil turns the send off), send and list_sends" do
      path = @base <> "/companies/#{@company}/accountant-package"

      expect_request(json_response(%{"data" => %{"email" => "c@x.co", "lastSentMonth" => nil}}))
      assert {:ok, %{"email" => "c@x.co"}} = AccountantPackage.get(client(), @company)
      assert assert_request().url == path

      expect_request(json_response(%{"data" => %{"accountantEmail" => nil}}))
      assert {:ok, _} = AccountantPackage.update(client(), @company, %{"accountantEmail" => nil})
      request = assert_request()
      assert {request.method, request.url} == {:put, path}
      assert json_body(request) == %{"accountantEmail" => nil}

      expect_request(json_response(%{"data" => %{"status" => "sent"}}))
      assert {:ok, _} = AccountantPackage.send(client(), @company, "2026-10")
      request = assert_request()
      assert {request.method, request.url} == {:post, path <> "/send"}
      assert json_body(request) == %{"month" => "2026-10"}

      expect_request(json_response(%{"data" => [%{"month" => "2026-10"}]}))
      assert {:ok, [%{"month" => "2026-10"}]} = AccountantPackage.list_sends(client(), @company)
      assert assert_request().url == path <> "/sends"
    end

    test "send surfaces PACKAGE_TOO_LARGE" do
      expect_request(
        json_response(
          %{
            "statusCode" => 422,
            "code" => "PACKAGE_TOO_LARGE",
            "message" => "m",
            "requestId" => "r"
          },
          status: 422
        )
      )

      assert {:error, %Error{code: "PACKAGE_TOO_LARGE"}} =
               AccountantPackage.send(client(), @company, "2026-10")
    end
  end

  describe "invoice package" do
    test "summary sends the month" do
      expect_request(
        json_response(%{"data" => %{"count" => 3, "total" => 450.5, "limit" => 500}})
      )

      assert {:ok, %{"count" => 3}} = InvoicePackage.summary(client(), @company, "2026-10")

      assert assert_request().url ==
               @base <> "/companies/#{@company}/invoice-package/summary?month=2026-10"
    end

    test "download returns the ZIP bytes with name and mime type" do
      expect_request(
        {:ok,
         %{
           status: 200,
           headers: [
             {"content-type", "application/zip"},
             {"content-disposition", ~s(attachment; filename="notas-2026-10.zip")}
           ],
           body: <<80, 75, 3, 4>>
         }}
      )

      assert {:ok,
              %{
                body: <<80, 75, 3, 4>>,
                mime_type: "application/zip",
                file_name: "notas-2026-10.zip"
              }} =
               InvoicePackage.download(client(), @company, "2026-10", include: ["xml", "pdf"])

      assert assert_request().url ==
               @base <> "/companies/#{@company}/invoice-package?month=2026-10&include=xml%2Cpdf"
    end

    test "download maps an error body" do
      expect_request(
        json_response(
          %{
            "statusCode" => 404,
            "code" => "ERROR_NOT_FOUND",
            "message" => "none",
            "requestId" => "r"
          },
          status: 404
        )
      )

      assert {:error, %Error{status: 404, code: "ERROR_NOT_FOUND"}} =
               InvoicePackage.download(client(), @company, "2026-10")
    end
  end

  describe "invoices (new and changed)" do
    test "list filters by customer_tax_id" do
      expect_request(json_response(%{"data" => [], "pagination" => @page}))

      assert {:ok, %{data: []}} =
               Invoices.list(client(), customer_tax_id: "52998224725", status: "authorized")

      assert assert_request().url ==
               @base <> "/invoices?status=authorized&customerTaxId=52998224725"
    end

    test "send_email sends the optional destination and the idempotency key" do
      expect_request(json_response(%{"data" => %{"status" => "queued"}}, status: 202))

      assert {:ok, _} =
               Invoices.send_email(client(), "inv_1",
                 email: "outro@example.com",
                 idempotency_key: "mail-1"
               )

      request = assert_request()
      assert request.url == @base <> "/invoices/inv_1/email"
      assert json_body(request) == %{"email" => "outro@example.com"}
      assert header(request, "idempotency-key") == "mail-1"
      assert header(request, "content-type") == "application/json"
    end

    test "substitute posts the correction with an idempotency key" do
      expect_request(
        json_response(%{"data" => %{"id" => "inv_2", "substitutesInvoiceId" => "inv_1"}},
          status: 202
        )
      )

      params = %{
        "description" => "Descricao errada",
        "service" => %{"description" => "Consultoria 10/2026"},
        "purchaseOrder" => "PO-9",
        "notes" => "obs"
      }

      assert {:ok, %{"substitutesInvoiceId" => "inv_1"}} =
               Invoices.substitute(client(), "inv_1", params, idempotency_key: "sub-1")

      request = assert_request()
      assert {request.method, request.url} == {:post, @base <> "/invoices/inv_1/substitute"}
      assert json_body(request) == params
      assert header(request, "idempotency-key") == "sub-1"
    end

    test "substitute surfaces ERROR_INVOICE_NOT_SUBSTITUTABLE" do
      expect_request(
        json_response(
          %{
            "statusCode" => 409,
            "code" => "ERROR_INVOICE_NOT_SUBSTITUTABLE",
            "message" => "no",
            "requestId" => "r"
          },
          status: 409
        )
      )

      assert {:error, %Error{status: 409, code: "ERROR_INVOICE_NOT_SUBSTITUTABLE"}} =
               Invoices.substitute(client(), "inv_1", %{"description" => "x"})
    end

    test "overview sends the period" do
      expect_request(json_response(%{"data" => %{"total" => 12}}))
      assert {:ok, %{"total" => 12}} = Invoices.overview(client(), period: "30d")
      assert assert_request().url == @base <> "/invoices/overview?period=30d"

      expect_request(json_response(%{"data" => %{"total" => 3}}))
      assert {:ok, _} = Invoices.overview(client())
      assert assert_request().url == @base <> "/invoices/overview"
    end

    test "review sends action and invoice ids" do
      expect_request(json_response(%{"data" => %{"processed" => 2}}, status: 202))
      assert {:ok, %{"processed" => 2}} = Invoices.review(client(), "retry", ["a", "b"])

      request = assert_request()
      assert {request.method, request.url} == {:post, @base <> "/invoices/review"}
      assert json_body(request) == %{"action" => "retry", "invoiceIds" => ["a", "b"]}
    end

    test "create with options.type SCHEDULE returns the schedule (snake_case), not an invoice" do
      expect_request(
        json_response(
          %{
            "data" => %{
              "id" => "sch_1",
              "kind" => "once",
              "status" => "active",
              "next_run_on" => "2026-12-01",
              "company_id" => @company
            }
          },
          status: 202
        )
      )

      params = %{
        "companyId" => @company,
        "amount" => 10,
        "competenceDate" => "2026-12-01",
        "options" => %{"type" => "SCHEDULE"}
      }

      assert {:ok, %{"kind" => "once", "next_run_on" => "2026-12-01"} = schedule} =
               Invoices.create(client(), params, idempotency_key: "s-1")

      refute Map.has_key?(schedule, "nfseNumber")
      request = assert_request()
      assert json_body(request)["options"] == %{"type" => "SCHEDULE"}
      assert header(request, "idempotency-key") == "s-1"
    end

    test "create with RECURRING sends the recurrence" do
      expect_request(
        json_response(%{"data" => %{"id" => "sch_2", "kind" => "recurring"}}, status: 202)
      )

      options = %{
        "type" => "RECURRING",
        "recurrence" => %{"frequency" => "MONTHLY", "endsOn" => "2027-12-01"}
      }

      assert {:ok, %{"kind" => "recurring"}} =
               Invoices.create(client(), %{"amount" => 10, "options" => options})

      assert json_body(assert_request())["options"] == options
    end
  end

  describe "schedules" do
    test "list filters and parses the page; get/update/pause/resume/cancel/runs" do
      expect_request(
        json_response(%{
          "data" => [%{"id" => "s1", "status" => "paused"}],
          "pagination" => %{"limit" => 5, "hasMore" => true, "nextCursor" => "5"}
        })
      )

      assert {:ok, page} =
               Schedules.list(client(), status: "paused", company_id: @company, limit: 5)

      assert [%{"id" => "s1"}] = page.data
      assert page.pagination["nextCursor"] == "5"

      assert assert_request().url ==
               @base <> "/schedules?status=paused&companyId=#{@company}&limit=5"

      expect_request(json_response(%{"data" => %{"id" => "s1"}}))
      assert {:ok, %{"id" => "s1"}} = Schedules.get(client(), "s1")
      assert assert_request().url == @base <> "/schedules/s1"

      expect_request(json_response(%{"data" => %{"id" => "s1"}}))

      assert {:ok, _} =
               Schedules.update(client(), "s1", %{"frequency" => "BIWEEKLY", "endsOn" => nil})

      request = assert_request()
      assert {request.method, request.url} == {:patch, @base <> "/schedules/s1"}
      assert json_body(request) == %{"frequency" => "BIWEEKLY", "endsOn" => nil}

      for {fun, action} <- [pause: "pause", resume: "resume", cancel: "cancel"] do
        expect_request(json_response(%{"data" => %{"id" => "s1"}}))
        assert {:ok, _} = apply(Schedules, fun, [client(), "s1"])
        request = assert_request()
        assert {request.method, request.url} == {:post, @base <> "/schedules/s1/#{action}"}
        assert request.body == nil
      end

      expect_request(
        json_response(%{
          "data" => [%{"id" => "r1", "outcome" => "failed"}],
          "pagination" => @page
        })
      )

      assert {:ok, runs} = Schedules.list_runs(client(), "s1", limit: 2)
      assert [%{"outcome" => "failed"}] = runs.data
      assert assert_request().url == @base <> "/schedules/s1/runs?limit=2"
    end

    test "iterate_runs walks the pages" do
      expect_requests([
        json_response(%{
          "data" => [%{"id" => "r1"}],
          "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => "1"}
        }),
        json_response(%{"data" => [%{"id" => "r2"}], "pagination" => @page})
      ])

      assert {:ok, stream} = Schedules.iterate_runs(client(), "s1", limit: 1)
      assert Enum.map(stream, & &1["id"]) == ["r1", "r2"]
    end

    test "state errors keep their code" do
      expect_request(
        json_response(
          %{
            "statusCode" => 409,
            "code" => "ERROR_SCHEDULE_STATE",
            "message" => "m",
            "requestId" => "r"
          },
          status: 409
        )
      )

      assert {:error, %Error{code: "ERROR_SCHEDULE_STATE"}} = Schedules.resume(client(), "s1")
    end
  end

  describe "imports" do
    test "start uploads a multipart with the file and company_id" do
      expect_request(
        json_response(%{"data" => %{"id" => "m1", "status" => "processing"}}, status: 202)
      )

      csv = "cnpj,valor\n11222333000181,10\n"

      assert {:ok, %{"id" => "m1"}} =
               Imports.start(client(), {:binary, csv},
                 company_id: @company,
                 file_name: "notas.csv"
               )

      request = assert_request()
      assert {request.method, request.url} == {:post, @base <> "/imports"}
      assert "multipart/form-data; boundary=" <> boundary = header(request, "content-type")

      body = IO.iodata_to_binary(request.body)
      assert body =~ ~s(name="companyId"\r\n\r\n#{@company}\r\n)
      assert body =~ ~s(name="file"; filename="notas.csv")
      assert body =~ "content-type: text/csv\r\n\r\n" <> csv <> "\r\n"
      assert String.ends_with?(body, "--" <> boundary <> "--\r\n")
    end

    test "start reads a file from disk and sends xlsx with its mime type" do
      path =
        Path.join(System.tmp_dir!(), "corvo-import-#{System.unique_integer([:positive])}.xlsx")

      File.write!(path, "PKxlsx")
      on_exit(fn -> File.rm(path) end)

      expect_request(json_response(%{"data" => %{"id" => "m2"}}, status: 202))
      assert {:ok, _} = Imports.start(client(), {:file, path})

      body = IO.iodata_to_binary(assert_request().body)
      assert body =~ ~s(filename="#{Path.basename(path)}")
      assert body =~ "spreadsheetml.sheet"
      refute body =~ "companyId"
    end

    test "list, get, emit and discard" do
      expect_request(json_response(%{"data" => [%{"id" => "m1"}]}))
      assert {:ok, [%{"id" => "m1"}]} = Imports.list(client(), limit: 5)
      assert assert_request().url == @base <> "/imports?limit=5"

      expect_request(json_response(%{"data" => %{"id" => "m1", "status" => "ready"}}))
      assert {:ok, %{"status" => "ready"}} = Imports.get(client(), "m1")
      assert assert_request().url == @base <> "/imports/m1"

      expect_request(json_response(%{"data" => %{"status" => "emitting"}}, status: 202))
      assert {:ok, %{"status" => "emitting"}} = Imports.emit(client(), "m1", send_email: true)
      request = assert_request()
      assert {request.method, request.url} == {:post, @base <> "/imports/m1/emit"}
      assert json_body(request) == %{"sendEmail" => true}

      expect_request(empty_response())
      assert {:ok, nil} = Imports.discard(client(), "m1")
      request = assert_request()
      assert {request.method, request.url} == {:delete, @base <> "/imports/m1"}
    end

    test "list_rows filters and update_row patches the line" do
      expect_request(
        json_response(%{
          "data" => [%{"line" => 2, "status" => "error"}],
          "pagination" => %{"limit" => 50, "hasMore" => false, "nextCursor" => nil}
        })
      )

      assert {:ok, page} = Imports.list_rows(client(), "m1", status: "error", limit: 50)
      assert [%{"line" => 2}] = page.data
      assert assert_request().url == @base <> "/imports/m1/rows?status=error&limit=50"

      expect_request(json_response(%{"data" => %{"line" => 2, "status" => "valid"}}))
      item = %{"item" => %{"amount" => 20}}
      assert {:ok, %{"status" => "valid"}} = Imports.update_row(client(), "m1", 2, item)
      request = assert_request()
      assert {request.method, request.url} == {:patch, @base <> "/imports/m1/rows/2"}
      assert json_body(request) == item
    end

    test "template and errors come back as CSV bytes" do
      expect_request(
        {:ok,
         %{
           status: 200,
           headers: [
             {"content-type", "text/csv; charset=utf-8"},
             {"content-disposition", "attachment; filename=modelo.csv"}
           ],
           body: "cnpj,valor\n"
         }}
      )

      assert {:ok,
              %{
                body: "cnpj,valor\n",
                file_name: "modelo.csv",
                mime_type: "text/csv; charset=utf-8"
              }} =
               Imports.download_template(client())

      assert assert_request().url == @base <> "/imports/template"

      expect_request(
        {:ok, %{status: 200, headers: [{"content-type", "text/csv"}], body: "linha,erro\n"}}
      )

      assert {:ok, %{body: "linha,erro\n"}} = Imports.download_errors(client(), "m1")
      assert assert_request().url == @base <> "/imports/m1/errors.csv"
    end

    test "an import error code is kept" do
      expect_request(
        json_response(
          %{
            "statusCode" => 422,
            "code" => "ERROR_IMPORT_TOO_LARGE",
            "message" => "m",
            "requestId" => "r"
          },
          status: 422
        )
      )

      assert {:error, %Error{code: "ERROR_IMPORT_TOO_LARGE"}} =
               Imports.start(client(), {:binary, "x"})
    end

    test "a bad source raises ArgumentError before any request" do
      assert_raise ArgumentError, fn -> Imports.start(client(), "notasource") end
      assert_no_request()
    end
  end

  describe "company-level profiles and DPS numbering" do
    test "dps sequence get and set (PUT)" do
      expect_request(json_response(%{"data" => %{"series" => "1", "lastNumber" => 10}}))
      assert {:ok, %{"lastNumber" => 10}} = DpsSequence.get(client(), @company)
      assert assert_request().url == @base <> "/companies/#{@company}/dps-sequence"

      expect_request(json_response(%{"data" => %{"series" => "1", "lastNumber" => 500}}))

      assert {:ok, %{"lastNumber" => 500}} =
               DpsSequence.set(client(), @company, %{"lastNumber" => 500})

      request = assert_request()
      assert request.method == :put
      assert json_body(request) == %{"lastNumber" => 500}
    end

    test "dps sequence below current is an error" do
      expect_request(
        json_response(
          %{
            "statusCode" => 422,
            "code" => "DPS_NUMBER_BELOW_CURRENT",
            "message" => "m",
            "requestId" => "r"
          },
          status: 422
        )
      )

      assert {:error, %Error{code: "DPS_NUMBER_BELOW_CURRENT"}} =
               DpsSequence.set(client(), @company, %{"lastNumber" => 1})
    end

    test "fiscal profiles" do
      base = @base <> "/companies/#{@company}/fiscal-profile"

      expect_request(json_response(%{"data" => [%{"id" => "p1"}]}))
      assert {:ok, [%{"id" => "p1"}]} = FiscalProfiles.list(client(), @company)
      assert assert_request().url == base

      expect_request(json_response(%{"data" => %{"id" => "p2"}}))
      assert {:ok, _} = FiscalProfiles.upsert(client(), @company, %{"validFrom" => "2026-01-01"})
      request = assert_request()
      assert {request.method, request.url} == {:put, base}
      assert json_body(request) == %{"validFrom" => "2026-01-01"}

      expect_request(json_response(%{"data" => %{"id" => "p2"}}, status: 201))
      assert {:ok, _} = FiscalProfiles.approve(client(), @company, "p2")
      request = assert_request()
      assert {request.method, request.url} == {:post, base <> "/p2/approve"}
    end

    test "service tax profiles" do
      base = @base <> "/companies/#{@company}/service-tax-profiles"

      expect_request(json_response(%{"data" => [%{"id" => "s1"}]}))
      assert {:ok, [_]} = ServiceTaxProfiles.list(client(), @company, date: "2026-11-24")
      assert assert_request().url == base <> "?date=2026-11-24"

      expect_request(json_response(%{"data" => %{"id" => "s2"}}, status: 201))

      assert {:ok, _} =
               ServiceTaxProfiles.create(client(), @company, %{"serviceCode" => "010101"})

      request = assert_request()
      assert {request.method, request.url} == {:post, base}

      expect_request(json_response(%{"data" => %{"id" => "s2"}}))
      assert {:ok, _} = ServiceTaxProfiles.update(client(), @company, "s2", %{"issRate" => "2"})
      request = assert_request()
      assert {request.method, request.url} == {:patch, base <> "/s2"}
      assert json_body(request) == %{"issRate" => "2"}

      expect_request(json_response(%{"data" => %{"deleted" => true}}))
      assert {:ok, _} = ServiceTaxProfiles.remove(client(), @company, "s2")
      request = assert_request()
      assert {request.method, request.url} == {:delete, base <> "/s2"}

      expect_request(json_response(%{"data" => %{"id" => "s2"}}, status: 201))
      assert {:ok, _} = ServiceTaxProfiles.approve(client(), @company, "s2")
      request = assert_request()
      assert {request.method, request.url} == {:post, base <> "/s2/approve"}
    end
  end

  describe "integrations" do
    test "providers and connection lifecycle" do
      expect_request(json_response(%{"data" => [%{"id" => "prov"}]}))
      assert {:ok, [%{"id" => "prov"}]} = Integrations.list_providers(client())
      assert assert_request().url == @base <> "/integrations/providers"

      expect_request(json_response(%{"data" => %{"id" => "n1"}}, status: 201))

      params = %{
        "provider" => "prov",
        "companyId" => @company,
        "credentials" => %{"apiKey" => "k"}
      }

      assert {:ok, %{"id" => "n1"}} = IntegrationConnections.create(client(), params)
      request = assert_request()
      assert {request.method, request.url} == {:post, @base <> "/integrations/connections"}
      assert json_body(request) == params

      conn = @base <> "/integrations/connections/n1"

      for {fun, suffix} <- [
            validate: "/validate",
            activate: "/activate",
            pause: "/pause",
            disconnect: "/disconnect"
          ] do
        expect_request(json_response(%{"data" => %{"id" => "n1"}}))
        assert {:ok, _} = apply(IntegrationConnections, fun, [client(), "n1"])
        request = assert_request()
        assert {request.method, request.url} == {:post, conn <> suffix}
      end

      expect_request(json_response(%{"data" => %{"id" => "n1"}}))
      assert {:ok, _} = IntegrationConnections.get(client(), "n1")
      assert assert_request().url == conn

      expect_request(json_response(%{"data" => [%{"id" => "n1"}]}))
      assert {:ok, [_]} = IntegrationConnections.list(client())
      assert assert_request().url == @base <> "/integrations/connections"
    end

    test "credentials and rules are replaced with PUT" do
      conn = @base <> "/integrations/connections/n1"

      expect_request(json_response(%{"data" => %{"id" => "n1"}}))
      creds = %{"credentials" => %{"apiKey" => "rotated"}}
      assert {:ok, _} = IntegrationConnections.update_credentials(client(), "n1", creds)
      request = assert_request()
      assert {request.method, request.url} == {:put, conn <> "/credentials"}
      assert json_body(request) == creds

      expect_request(json_response(%{"data" => [%{"id" => "r1"}]}))
      rules = %{"rules" => [%{"match" => "all"}]}

      assert {:ok, [%{"id" => "r1"}]} =
               IntegrationConnections.replace_rules(client(), "n1", rules)

      request = assert_request()
      assert {request.method, request.url} == {:put, conn <> "/rules"}
      assert json_body(request) == rules

      expect_request(json_response(%{"data" => []}))
      assert {:ok, []} = IntegrationConnections.list_rules(client(), "n1")
      assert assert_request().url == conn <> "/rules"
    end

    test "events and operations take a limit; operations can be completed and retried" do
      conn = @base <> "/integrations/connections/n1"

      expect_request(json_response(%{"data" => []}))
      assert {:ok, []} = IntegrationConnections.list_events(client(), "n1", limit: 10)
      assert assert_request().url == conn <> "/events?limit=10"

      expect_request(json_response(%{"data" => [%{"id" => "o1"}]}))
      assert {:ok, [%{"id" => "o1"}]} = IntegrationConnections.list_operations(client(), "n1")
      assert assert_request().url == conn <> "/operations"

      expect_request(json_response(%{"data" => %{"id" => "o1"}}))
      body = %{"taxId" => "52998224725", "name" => "Ada"}
      assert {:ok, _} = IntegrationOperations.complete_customer(client(), "o1", body)
      request = assert_request()

      assert {request.method, request.url} ==
               {:patch, @base <> "/integrations/operations/o1/customer"}

      assert json_body(request) == body

      expect_request(json_response(%{"data" => %{"queued" => true}}))
      assert {:ok, %{"queued" => true}} = IntegrationOperations.retry(client(), "o1")
      request = assert_request()

      assert {request.method, request.url} ==
               {:post, @base <> "/integrations/operations/o1/retry"}
    end
  end
end
