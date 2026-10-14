defmodule CorvoNfse.TransportTest do
  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Error
  alias CorvoNfse.Resources.{Companies, Invoices}

  setup :verify_on_exit!

  @base "http://localhost:4000"

  describe "request building" do
    test "builds the URL with the v1 prefix and sends X-API-Key (never Bearer)" do
      expect_request(json_response(%{"data" => %{"id" => "comp_1"}}))

      assert {:ok, %{"id" => "comp_1"}} = Companies.get(client(), "comp_1")

      request = assert_request()
      assert request.method == :get
      assert request.url == @base <> "/v1/companies/comp_1"
      assert {"x-api-key", api_key()} in request.headers
      assert {"accept", "application/json"} in request.headers

      refute Enum.any?(request.headers, fn {name, _value} -> name == "authorization" end)
    end

    test "honours a custom prefix and receive timeout" do
      expect_request(json_response(%{"data" => nil}))
      client = client(prefix: "api/v2", receive_timeout: 5_000)

      assert {:ok, _data} = Companies.get(client, "comp_1")

      request = assert_request()
      assert request.url == @base <> "/api/v2/companies/comp_1"
      assert request.receive_timeout == 5_000
    end

    test "encodes path segments like encodeURIComponent" do
      expect_request(json_response(%{"data" => %{"id" => "comp_1"}}))

      assert {:ok, %{"id" => "comp_1"}} = Companies.get(client(), "comp 1/x")

      request = assert_request()
      assert request.url == @base <> "/v1/companies/comp%201%2Fx"
    end

    test "builds query strings, skipping nil values and encoding the rest" do
      expect_request(json_response(%{"data" => [], "pagination" => nil}))

      assert {:ok, %{data: []}} =
               Invoices.list(client(), company_id: "comp 1", external_id: "a/b", limit: 5)

      request = assert_request()
      assert request.url == @base <> "/v1/invoices?companyId=comp+1&externalId=a%2Fb&limit=5"
    end

    test "serializes the JSON body with wire keys unchanged" do
      expect_request(json_response(%{"data" => %{"id" => "comp_1"}}))

      params = %{"legalName" => "Acme Ltda", "tradeName" => "Acme", "simpleNational" => true}

      assert {:ok, %{"id" => "comp_1"}} = Companies.create(client(), params)

      request = assert_request()
      assert request.method == :post
      assert {"content-type", "application/json"} in request.headers
      assert Jason.decode!(request.body) == %{"legalName" => "Acme Ltda", "tradeName" => "Acme", "simpleNational" => true}
    end

    test "uses PATCH for updates" do
      expect_request(json_response(%{"data" => %{"id" => "comp_1"}}))

      assert {:ok, _company} = Companies.update(client(), "comp_1", %{"legalName" => "New"})

      request = assert_request()
      assert request.method == :patch
      assert request.url == @base <> "/v1/companies/comp_1"
    end

    test "sends Idempotency-Key only when provided" do
      expect_request(json_response(%{"data" => %{"id" => "inv_1"}}))

      assert {:ok, _invoice} =
               Invoices.create(client(), invoice_params(), idempotency_key: "idem_123")

      request = assert_request()
      assert {"idempotency-key", "idem_123"} in request.headers
    end

    test "omits Idempotency-Key and Content-Type for bodyless POSTs" do
      expect_request(json_response(%{"data" => %{"sent" => true}}))

      assert {:ok, %{"sent" => true}} = Invoices.send_email(client(), "inv_1")

      request = assert_request()
      refute header_named(request, "idempotency-key")
      refute header_named(request, "content-type")
      assert request.body == nil
    end
  end

  describe "envelope unwrapping" do
    test ":data unwraps the envelope (default)" do
      expect_request(json_response(%{"data" => %{"id" => "comp_1"}}))

      assert {:ok, %{"id" => "comp_1"}} = Companies.get(client(), "comp_1")
    end

    test ":data yields nil when data is null or the envelope is absent" do
      expect_request(json_response(%{"data" => nil}))
      assert {:ok, nil} = Companies.get(client(), "comp_1")

      expect_request(json_response(%{"status" => "ok"}))
      assert {:ok, nil} = Companies.get(client(), "comp_1")
    end

    test ":data_props unwraps data.props" do
      expect_request(json_response(%{"data" => %{"props" => %{"id" => "inv_1"}}}))

      assert {:ok, %{"id" => "inv_1"}} = Invoices.get(client(), "inv_1")
    end

    test ":data_props yields nil when props is absent" do
      expect_request(json_response(%{"data" => %{"id" => "inv_1"}}))

      assert {:ok, nil} = Invoices.get(client(), "inv_1")
    end

    test ":none returns the parsed body as-is" do
      expect_request(json_response(%{"status" => "ok"}))

      assert {:ok, %{"status" => "ok"}} =
               CorvoNfse.Resources.Health.live(client())
    end

    test "204 and empty bodies return nil" do
      expect_request(empty_response(204))
      assert {:ok, nil} = Companies.remove(client(), "comp_1")

      expect_request(empty_response(200))
      assert {:ok, nil} = Companies.remove(client(), "comp_2")
    end
  end

  describe "error mapping" do
    test "maps REST errors: status, code, message, details, requestId" do
      expect_request(
        json_response(
          %{
            "statusCode" => 400,
            "code" => "ERROR_VALIDATION",
            "message" => "Validation failed",
            "details" => [%{"field" => "amount", "code" => "too_small", "message" => "must be > 0"}],
            "requestId" => "req_42"
          },
          status: 400
        )
      )

      assert {:error, error} = Companies.get(client(), "comp_1")

      assert %Error{} = error
      assert error.status == 400
      assert error.code == "ERROR_VALIDATION"
      assert error.message == "Validation failed"
      assert [%{"field" => "amount"}] = error.details
      assert error.request_id == "req_42"
      assert error.retry_after == nil
    end

    test "falls back to http_<status> with the X-Request-Id header" do
      expect_request(
        json_response(%{"error" => "Gone"}, status: 410, headers: [
          {"content-type", "application/json"},
          {"x-request-id", "req_hdr"}
        ])
      )

      assert {:error, error} = Companies.get(client(), "comp_1")

      assert error.status == 410
      assert error.code == "http_410"
      assert error.message == "Gone"
      assert error.request_id == "req_hdr"
      assert error.details == nil
    end

    test "joins array messages and prefers body retryAfter over the header" do
      expect_request(
        json_response(
          %{"message" => ["first problem", "second problem"], "retryAfter" => 7},
          status: 429,
          headers: [
            {"content-type", "application/json"},
            {"retry-after", "30"}
          ]
        )
      )

      assert {:error, error} = Companies.get(client(), "comp_1")

      assert error.message == "first problem; second problem"
      assert error.retry_after == 7
    end

    test "reads Retry-After from the header when the body omits retryAfter" do
      expect_request(
        json_response(%{"code" => "rate_limited", "message" => "slow down"}, status: 429,
          headers: [
            {"content-type", "application/json"},
            {"retry-after", "30"}
          ]
        )
      )

      assert {:error, %Error{retry_after: 30, code: "rate_limited"}} =
               Companies.get(client(), "comp_1")
    end

    test "falls back to a generic message for non-JSON error bodies" do
      expect_request({:ok, %{status: 500, headers: [], body: "<html>boom</html>"}})

      assert {:error, %Error{status: 500, code: "http_500", message: message, details: nil}} =
               Companies.get(client(), "comp_1")

      assert message == "Request failed with status 500"
    end

    test "reports invalid_json for unparsable success bodies" do
      expect_request({:ok, %{status: 200, headers: [{"content-type", "application/json"}], body: "{oops"}})

      assert {:error, %Error{status: 200, code: "invalid_json", message: "Invalid JSON in response"}} =
               Companies.get(client(), "comp_1")
    end

    test "maps refused connections to network_error" do
      expect_fun(fn _request -> {:error, :econnrefused} end)

      assert {:error, %Error{status: 0, code: "network_error", message: message}} =
               Companies.get(client(), "comp_1")

      assert message =~ "Network request failed"
    end

    test "maps timeouts to timeout with the configured deadline" do
      expect_fun(fn _request -> {:error, :timeout} end)

      assert {:error, %Error{status: 0, code: "timeout", message: message}} =
               Companies.get(client(), "comp_1")

      assert message == "Request timed out after 30000ms"
    end

    test "maps Mint-style timeout reasons to timeout" do
      expect_fun(fn _request -> {:error, %{reason: :timeout}} end)

      assert {:error, %Error{code: "timeout"}} = Companies.get(client(), "comp_1")
    end

    test "never lets adapter exceptions escape" do
      expect_fun(fn _request -> raise RuntimeError, "pool crashed" end)

      assert {:error, %Error{status: 0, code: "network_error", message: message}} =
               Companies.get(client(), "comp_1")

      assert message =~ "pool crashed"
    end
  end

  describe "list" do
    test "returns items plus the untouched pagination object" do
      expect_request(
        json_response(%{
          "data" => [%{"id" => "comp_1"}, %{"id" => "comp_2"}],
          "pagination" => %{"limit" => 2, "hasMore" => true, "nextCursor" => "Y3VyMg"}
        })
      )

      assert {:ok, page} = Companies.list(client(), limit: 2)

      assert [%{"id" => "comp_1"}, %{"id" => "comp_2"}] = page.data
      assert page.pagination == %{"limit" => 2, "hasMore" => true, "nextCursor" => "Y3VyMg"}

      request = assert_request()
      assert request.url == @base <> "/v1/companies?limit=2"
    end

    test "extracts props from each item for invoice-like endpoints" do
      expect_request(
        json_response(%{
          "data" => [%{"props" => %{"id" => "inv_1"}}, %{"props" => %{"id" => "inv_2"}}],
          "pagination" => %{"limit" => 2, "hasMore" => false, "nextCursor" => nil}
        })
      )

      assert {:ok, page} = Invoices.list(client())

      assert [%{"id" => "inv_1"}, %{"id" => "inv_2"}] = page.data
      assert page.pagination["hasMore"] == false
    end

    test "surfaces list failures as {:error, ...}" do
      expect_request(json_response(%{"message" => "forbidden"}, status: 403))

      assert {:error, %Error{status: 403, code: "http_403"}} = Companies.list(client())
    end
  end

  describe "paginate" do
    test "walks pages eagerly on the first fetch and follows nextCursor" do
      expect_requests([
        json_response(%{
          "data" => [%{"id" => "comp_1"}],
          "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => "Y3VyMg"}
        }),
        json_response(%{
          "data" => [%{"id" => "comp_2"}],
          "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil}
        })
      ])

      assert {:ok, stream} = Companies.iterate(client(), limit: 1)
      assert Enum.to_list(stream) == [%{"id" => "comp_1"}, %{"id" => "comp_2"}]

      [first, second] = pop_requests()
      assert first.url == @base <> "/v1/companies?limit=1"
      assert second.url == @base <> "/v1/companies?limit=1&cursor=Y3VyMg"
    end

    test "surfaces a first-page failure as {:error, ...}" do
      expect_request(json_response(%{"message" => "boom"}, status: 500))

      assert {:error, %Error{status: 500, code: "http_500"}} = Companies.iterate(client())
    end

    test "raises a typed error when a later page fails mid-stream" do
      expect_requests([
        json_response(%{
          "data" => [%{"id" => "comp_1"}],
          "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => "Y3VyMg"}
        }),
        json_response(%{"message" => "boom"}, status: 503)
      ])

      assert {:ok, stream} = Companies.iterate(client(), limit: 1)

      assert_raise Error, fn -> Enum.to_list(stream) end
    end

    test "stops when hasMore is true but nextCursor is null" do
      expect_request(
        json_response(%{
          "data" => [%{"id" => "comp_1"}],
          "pagination" => %{"limit" => 1, "hasMore" => true, "nextCursor" => nil}
        })
      )

      assert {:ok, stream} = Companies.iterate(client())
      assert Enum.to_list(stream) == [%{"id" => "comp_1"}]
      assert_request()
    end

    test "yields nothing for an empty first page" do
      expect_request(
        json_response(%{"data" => [], "pagination" => %{"limit" => 10, "hasMore" => false, "nextCursor" => nil}})
      )

      assert {:ok, stream} = Companies.iterate(client())
      assert Enum.to_list(stream) == []
    end
  end

  describe "raw downloads" do
    test "returns body, mime type and file name" do
      expect_request(
        {:ok,
         %{
           status: 200,
           headers: [
             {"content-type", "application/pdf"},
             {"content-disposition", ~s(attachment; filename="nfse_123.pdf")}
           ],
           body: "%PDF-1.4"
         }}
      )

      assert {:ok, download} = Invoices.pdf(client(), "inv_1")

      assert download.body == "%PDF-1.4"
      assert download.mime_type == "application/pdf"
      assert download.file_name == "nfse_123.pdf"
    end

    test "parses unquoted file names and maps HTTP failures" do
      expect_request(
        {:ok,
         %{
           status: 200,
           headers: [
             {"content-type", "text/xml"},
             {"content-disposition", "attachment; filename=nfse_123.xml"}
           ],
           body: "<DPS/>"
         }}
      )

      assert {:ok, %{file_name: "nfse_123.xml", mime_type: "text/xml"}} =
               Invoices.xml(client(), "inv_1")

      expect_request(json_response(%{"message" => "nope"}, status: 404))

      assert {:error, %Error{status: 404}} = Invoices.xml(client(), "missing")
    end
  end

  defp invoice_params do
    %{
      "customer" => %{"name" => "Ada", "taxId" => "12345678900"},
      "service" => %{"code" => "0101"},
      "amount" => 10.5,
      "competenceDate" => "2026-10-01"
    }
  end

  defp header_named(request, name) do
    Enum.find_value(request.headers, fn
      {^name, value} -> value
      _other -> nil
    end)
  end
end
