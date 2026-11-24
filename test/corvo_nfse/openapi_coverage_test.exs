defmodule CorvoNfse.OpenapiCoverageTest do
  @moduledoc """
  Keeps the SDK in step with the public API contract (`spec/openapi.json`,
  vendored from `docs/openapi/openapi.json` of corvo-nfse).

  Every `operationId` of the contract must have an entry in `@operations`
  below, and every entry must call the SDK function with the HTTP method and
  path the contract declares. When the API changes, replace `spec/openapi.json`
  and this test names what is missing.
  """

  use ExUnit.Case, async: true

  import Mox
  import CorvoNfse.TestHelpers

  alias CorvoNfse.Resources.{
    AccountantPackage,
    Billing,
    Certificates,
    Cnpj,
    Companies,
    Credits,
    Customers,
    DpsSequence,
    FiscalPortal,
    FiscalProfiles,
    Health,
    Imports,
    IntegrationConnections,
    IntegrationOperations,
    Integrations,
    InvoicePackage,
    Invoices,
    Schedules,
    ServiceFavorites,
    ServiceTaxProfiles,
    Webhooks
  }

  alias CorvoNfse.Resources.Webhooks.Deliveries

  setup :verify_on_exit!

  @spec_path Path.expand("../../spec/openapi.json", __DIR__)
  @external_resource @spec_path
  @contract @spec_path |> File.read!() |> Jason.decode!()
  @http_methods ~w(get post put patch delete)

  # operationId => fn(client) calling the SDK with ids "c1"/"i1"/... in path order.
  defp operations,
    do: %{
      "billing_getPlan" => &Billing.plan/1,
      "billing_getUsage" => &Billing.usage/1,
      "cnpj_lookup" => &Cnpj.lookup(&1, "11222333000181"),
      "companies_list" => &Companies.list/1,
      "companies_create" => &Companies.create(&1, %{"legalName" => "Acme"}),
      "companies_get" => &Companies.get(&1, "c1"),
      "companies_update" => &Companies.update(&1, "c1", %{"legalName" => "Acme"}),
      "companies_delete" => &Companies.remove(&1, "c1"),
      "accountantPackage_get" => &AccountantPackage.get(&1, "c1"),
      "accountantPackage_update" =>
        &AccountantPackage.update(&1, "c1", %{"accountantEmail" => "a@b.co"}),
      "accountantPackage_send" => &AccountantPackage.send(&1, "c1", "2026-10"),
      "accountantPackage_listSends" => &AccountantPackage.list_sends(&1, "c1"),
      "certificates_list" => &Certificates.list(&1, "c1"),
      "certificates_upload" => &Certificates.upload(&1, "c1", {:binary, "p12"}, "secret"),
      "certificates_revoke" => &Certificates.remove(&1, "c1", "k1"),
      "invoicePackage_download" => &InvoicePackage.download(&1, "c1", "2026-10"),
      "invoicePackage_summary" => &InvoicePackage.summary(&1, "c1", "2026-10"),
      "serviceFavorites_list" => &ServiceFavorites.list(&1, "c1"),
      "serviceFavorites_create" =>
        &ServiceFavorites.create(&1, "c1", %{"label" => "L", "serviceCode" => "010101"}),
      "serviceFavorites_delete" => &ServiceFavorites.remove(&1, "c1", "f1"),
      "dpsSequence_get" => &DpsSequence.get(&1, "c1"),
      "dpsSequence_set" => &DpsSequence.set(&1, "c1", %{"lastNumber" => 10}),
      "fiscalProfiles_list" => &FiscalProfiles.list(&1, "c1"),
      "fiscalProfiles_upsert" => &FiscalProfiles.upsert(&1, "c1", %{"validFrom" => "2026-01-01"}),
      "fiscalProfiles_approve" => &FiscalProfiles.approve(&1, "c1", "p1"),
      "serviceTaxProfiles_list" => &ServiceTaxProfiles.list(&1, "c1"),
      "serviceTaxProfiles_create" => &ServiceTaxProfiles.create(&1, "c1", %{"code" => "x"}),
      "serviceTaxProfiles_delete" => &ServiceTaxProfiles.remove(&1, "c1", "s1"),
      "serviceTaxProfiles_update" => &ServiceTaxProfiles.update(&1, "c1", "s1", %{"code" => "x"}),
      "serviceTaxProfiles_approve" => &ServiceTaxProfiles.approve(&1, "c1", "s1"),
      "credits_getBalance" => &Credits.balance/1,
      "credits_listHistory" => &Credits.history/1,
      "credits_listPlans" => &Credits.plans/1,
      "credits_previewPurchase" => &Credits.preview_purchase(&1, 5),
      "customers_search" => &Customers.search/1,
      "customers_delete" => &Customers.remove(&1, "52998224725"),
      "customers_get" => &Customers.get(&1, "52998224725"),
      "customers_update" => &Customers.update(&1, "52998224725", %{"name" => "Ada"}),
      "fiscalPortal_status" => &FiscalPortal.status/1,
      "health_live" => &Health.live/1,
      "imports_list" => &Imports.list/1,
      "imports_start" => &Imports.start(&1, {:binary, "a,b\n1,2\n"}),
      "imports_discard" => &Imports.discard(&1, "m1"),
      "imports_get" => &Imports.get(&1, "m1"),
      "imports_emit" => &Imports.emit(&1, "m1"),
      "imports_downloadErrors" => &Imports.download_errors(&1, "m1"),
      "imports_listRows" => &Imports.list_rows(&1, "m1"),
      "imports_updateRow" => &Imports.update_row(&1, "m1", 3, %{"item" => %{"amount" => 1}}),
      "imports_downloadTemplate" => &Imports.download_template/1,
      "integrationConnections_list" => &IntegrationConnections.list/1,
      "integrationConnections_create" =>
        &IntegrationConnections.create(&1, %{
          "provider" => "p",
          "companyId" => "c1",
          "credentials" => %{}
        }),
      "integrationConnections_get" => &IntegrationConnections.get(&1, "n1"),
      "integrationConnections_activate" => &IntegrationConnections.activate(&1, "n1"),
      "integrationConnections_updateCredentials" =>
        &IntegrationConnections.update_credentials(&1, "n1", %{"credentials" => %{}}),
      "integrationConnections_disconnect" => &IntegrationConnections.disconnect(&1, "n1"),
      "integrationConnections_listEvents" => &IntegrationConnections.list_events(&1, "n1"),
      "integrationConnections_listOperations" =>
        &IntegrationConnections.list_operations(&1, "n1"),
      "integrationConnections_pause" => &IntegrationConnections.pause(&1, "n1"),
      "integrationConnections_listRules" => &IntegrationConnections.list_rules(&1, "n1"),
      "integrationConnections_replaceRules" =>
        &IntegrationConnections.replace_rules(&1, "n1", %{"rules" => []}),
      "integrationConnections_validate" => &IntegrationConnections.validate(&1, "n1"),
      "integrationOperations_completeCustomer" =>
        &IntegrationOperations.complete_customer(&1, "o1", %{"taxId" => "52998224725"}),
      "integrationOperations_retry" => &IntegrationOperations.retry(&1, "o1"),
      "integrations_listProviders" => &Integrations.list_providers/1,
      "invoices_list" => &Invoices.list/1,
      "invoices_create" => &Invoices.create(&1, %{"amount" => 1}, idempotency_key: "k"),
      "invoices_get" => &Invoices.get(&1, "i1"),
      "invoices_cancel" =>
        &Invoices.cancel(&1, "i1", "other", description: "a long enough reason"),
      "invoices_createDownloadUrl" => &Invoices.download_url(&1, "i1", :pdf),
      "invoices_sendEmail" =>
        &Invoices.send_email(&1, "i1", idempotency_key: "k", email: "a@b.co"),
      "invoices_listEvents" => &Invoices.events(&1, "i1"),
      "invoices_downloadPdf" => &Invoices.pdf(&1, "i1"),
      "invoices_substitute" =>
        &Invoices.substitute(&1, "i1", %{"description" => "why"}, idempotency_key: "k"),
      "invoices_downloadXml" => &Invoices.xml(&1, "i1"),
      "invoices_createBatch" => &Invoices.create_batch(&1, [%{"amount" => 1}]),
      "invoices_calculate" => &Invoices.calculate(&1, %{"amount" => 1}),
      "invoices_overview" => &Invoices.overview/1,
      "invoices_review" => &Invoices.review(&1, "retry", ["i1"]),
      "schedules_list" => &Schedules.list/1,
      "schedules_get" => &Schedules.get(&1, "s1"),
      "schedules_update" => &Schedules.update(&1, "s1", %{"frequency" => "WEEKLY"}),
      "schedules_cancel" => &Schedules.cancel(&1, "s1"),
      "schedules_pause" => &Schedules.pause(&1, "s1"),
      "schedules_resume" => &Schedules.resume(&1, "s1"),
      "schedules_listRuns" => &Schedules.list_runs(&1, "s1"),
      "webhooks_list" => &Webhooks.list/1,
      "webhooks_create" => &Webhooks.create(&1, %{url: "https://e.co/h", events: []}),
      "webhooks_delete" => &Webhooks.remove(&1, "w1"),
      "webhooks_test" => &Webhooks.test(&1, "w1"),
      "webhookDeliveries_list" => &Deliveries.list/1,
      "webhookDeliveries_retry" => &Deliveries.retry(&1, "d1"),
      "webhookDeliveries_stats" => &Deliveries.stats/1
    }

  @contract_operations (for {path, item} <- @contract["paths"],
                            {method, op} <- item,
                            method in @http_methods do
                          {op["operationId"], String.upcase(method), path, op}
                        end)

  test "the vendored contract is 0.3.0 with 92 operations" do
    assert @contract["info"]["version"] == "0.3.0"
    assert length(@contract_operations) == 92
  end

  test "every operationId of the contract is implemented, and nothing else is mapped" do
    contract_ids = @contract_operations |> Enum.map(&elem(&1, 0)) |> MapSet.new()
    mapped_ids = operations() |> Map.keys() |> MapSet.new()

    assert MapSet.to_list(MapSet.difference(contract_ids, mapped_ids)) == [],
           "operations in the contract but not in the SDK"

    assert MapSet.to_list(MapSet.difference(mapped_ids, contract_ids)) == [],
           "operations mapped here but not in the contract"
  end

  for {operation_id, method, path, op} <- @contract_operations do
    @operation_id operation_id
    @method method
    @path path
    @op op

    test "#{operation_id} sends #{method} #{path} as the contract declares" do
      call = Map.fetch!(operations(), @operation_id)
      expect_request(canned_response(@op))

      assert {:ok, _result} = call.(client())

      request = assert_request()

      assert String.upcase(Atom.to_string(request.method)) == @method
      assert {"x-api-key", api_key()} in request.headers

      %URI{path: url_path, query: query} = URI.parse(request.url)
      assert String.starts_with?(url_path, "/v1")

      assert url_path |> String.replace_prefix("/v1", "") |> path_matches?(@path),
             "#{url_path} does not match #{@path}"

      assert_query(query, @op)
      assert_idempotency(request, @op)
      assert_body(request, @op)
    end
  end

  defp path_matches?(actual, template) do
    pattern =
      template
      |> String.split(~r/\{[^}]+\}/, include_captures: true)
      |> Enum.map_join(fn
        "{" <> _ -> "[^/]+"
        literal -> Regex.escape(literal)
      end)

    Regex.match?(Regex.compile!("^" <> pattern <> "$"), actual)
  end

  defp assert_query(query, op) do
    declared =
      for %{"in" => "query"} = param <- Map.get(op, "parameters", []), do: param["name"]

    sent = if query, do: query |> URI.decode_query() |> Map.keys(), else: []

    assert sent -- declared == [], "query keys #{inspect(sent)} not declared by the contract"

    for %{"in" => "query", "required" => true, "name" => name} <- Map.get(op, "parameters", []) do
      assert name in sent, "required query parameter #{name} was not sent"
    end
  end

  defp assert_idempotency(request, op) do
    declares? =
      Enum.any?(
        Map.get(op, "parameters", []),
        &(&1["$ref"] == "#/components/parameters/IdempotencyKey")
      )

    if declares? do
      assert {"idempotency-key", "k"} in request.headers
    end
  end

  defp assert_body(request, op) do
    # an optional body (e.g. the e-mail override) may be omitted entirely
    content =
      if get_in(op, ["requestBody", "required"]), do: get_in(op, ["requestBody", "content"])

    case content do
      %{"application/json" => _} ->
        assert {"content-type", "application/json"} in request.headers
        assert {:ok, _} = Jason.decode(request.body)

      %{"multipart/form-data" => _} ->
        assert {"content-type", "multipart/form-data; boundary=" <> _} =
                 List.keyfind(request.headers, "content-type", 0)

      _none ->
        :ok
    end
  end

  defp canned_response(op) do
    {status, response} =
      op["responses"]
      |> Enum.filter(fn {code, _} -> String.starts_with?(code, "2") end)
      |> Enum.min_by(fn {code, _} -> code end)

    status = String.to_integer(status)

    case response["content"] do
      nil ->
        empty_response(status)

      %{"application/json" => _} ->
        json_response(
          %{
            "data" => [],
            "pagination" => %{"limit" => 1, "hasMore" => false, "nextCursor" => nil},
            "status" => "ok"
          },
          status: status
        )

      content ->
        [type | _] = Map.keys(content)
        {:ok, %{status: status, headers: [{"content-type", type}], body: "bytes"}}
    end
  end
end
