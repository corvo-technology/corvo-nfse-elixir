# corvo-nfse

Elixir SDK for the [Corvo](https://corvo.tech) NFS-e API. Register companies, calculate taxes, issue Brazilian service invoices (NFS-e), follow them by webhook and download the PDF and XML, from Elixir 1.16+.

- **Result-style, never raises.** Every API, network or timeout failure comes back as `{:error, %CorvoNfse.Error{}}` with `status`, `code`, `message`, `details`, `request_id` and `retry_after`.
- **Pagination built in.** `list/2` returns one page; `iterate/2` returns a `Stream` that follows `hasMore` and `nextCursor`.
- **Safe retries.** Issuing an invoice and sending an email accept an idempotency key.
- **Webhook verification in one call.** HMAC-SHA256 against the raw body, constant-time.
- The wire format is passed through unchanged: responses are plain maps with string keys, exactly as the server sent them. Library only, no CLI.

Covers the 92 operations of the public API contract 0.3.0 (<https://corvo.tech/openapi.json>). Full API reference: <https://corvo.tech/en/docs>.

## Installation

```elixir
def deps do
  [
    {:corvo_nfse, "~> 0.3.0"}
  ]
end
```

## Quickstart

Start with a `corvo_test_...` key: invoices issued with it have no fiscal value.

```elixir
client = CorvoNfse.new(api_key: "corvo_test_...")  # or set CORVO_API_KEY

{:ok, page} = CorvoNfse.Resources.Companies.list(client, limit: 10)
page.data        #=> [%{"id" => "...", "legalName" => "..."}]
page.pagination  #=> %{"limit" => 10, "hasMore" => true, "nextCursor" => "eyJ..."}
```

`CorvoNfse.new/1` is the only call that raises (`ArgumentError`): it fails fast when no API key is configured or the base URL is invalid.

### Register a company

```elixir
{:ok, company} =
  CorvoNfse.Resources.Companies.create(client, %{
    "legalName" => "Empresa Exemplo Ltda",
    "taxId" => "11222333000181",
    "taxRegime" => "Simples Nacional",   # "MEI" | "Simples Nacional" (the only regimes Corvo serves)
    "simplesRate" => "6.54",              # required for Simples Nacional: effective DAS rate (%), ignored for MEI
    "municipalityCode" => "3550308",      # IBGE code, 7 digits
    "defaultServiceCode" => "010101"      # optional: used when an invoice omits service.code
  })
```

In `live`, also upload the A1 certificate with `CorvoNfse.Resources.Certificates.upload/4`. The company is ready when `company["status"] == "ready"` and `company["setupGaps"] == []`.

### Estimate the taxes before issuing

Nothing is issued, stored or charged.

```elixir
{:ok, estimate} =
  CorvoNfse.Resources.Invoices.calculate(client, %{
    "companyTaxId" => "11222333000181",
    "service" => %{"description" => "Consultoria"},
    "amount" => 1500,
    "competenceDate" => "2026-10-16"
  })

# estimate["status"] is "ready" or "blocked": a fiscal gap is data, not an error.
```

### Issue an invoice

Issuing is asynchronous: a successful call means the request was accepted, not that the invoice is authorized. Follow the status with `Invoices.get/2` or webhooks.

```elixir
{:ok, invoice} =
  CorvoNfse.Resources.Invoices.create(
    client,
    %{
      "companyTaxId" => "11222333000181",   # or "companyId"
      # "customer" is optional; when sent, "taxId" (CPF or CNPJ) is required.
      "customer" => %{"taxId" => "52998224725", "name" => "Cliente", "email" => "cliente@example.com"},
      "service" => %{"description" => "Consultoria"},  # code and city default to the company's
      "amount" => 150.5,
      "competenceDate" => "2026-10-16",
      "options" => %{"email" => %{"send" => true}}
    },
    idempotency_key: "order-42"   # the same key never issues twice
  )
```

Use `"options" => %{"type" => "SCHEDULE"}` with a future `competenceDate` (from tomorrow on) to schedule the issuance. In that case `{:ok, data}` is a **schedule** (snake_case fields), not an invoice: the note only exists when the schedule runs (09:00 America/Sao_Paulo, Monday to Friday). `"RECURRING"` repeats it, with `"recurrence" => %{"frequency" => "MONTHLY", "endsOn" => "2027-12-01"}`. See [Schedules](#schedules).

To declare a deduction from the ISS base, send `"deduction"` (greater than 0 and less than `amount` minus `discount`). The invoice is still issued for the full `amount`, and you are responsible for the declared value.

### Issue up to 50 invoices at once

`create_batch/2` takes 1 to 50 items (they can belong to different companies). Items are checked one by one: valid ones are saved together, invalid ones come back `"rejected"` and are not saved. Send an `"idempotencyKey"` per item, so repeating the batch after a timeout returns the saved ones with `"replayed"`.

```elixir
{:ok, batch} =
  CorvoNfse.Resources.Invoices.create_batch(client, [
    %{"companyTaxId" => "11222333000181", "idempotencyKey" => "sheet-row-2",
      "service" => %{"description" => "Consultoria"}, "amount" => 150.5, "competenceDate" => "2026-10-16"},
    %{"companyTaxId" => "11222333000181", "idempotencyKey" => "sheet-row-3",
      "service" => %{"description" => "Manutenção"}, "amount" => 300, "competenceDate" => "2026-10-16"}
  ])

for %{"status" => "rejected"} = result <- batch["results"] do
  IO.puts("#{result["index"]} #{result["error"]["code"]} #{result["error"]["message"]}")
end
```

The route allows 10 batches per minute per tenant (`429` with `Retry-After`).

### Cancel an invoice

```elixir
{:ok, invoice} =
  CorvoNfse.Resources.Invoices.cancel(client, "inv_1", "issue_error",
    description: "Wrong amount on the invoice"
  )
# reason: "issue_error" | "service_not_provided" | "other"
```

- `queued`: cancelled at once, `"status"` is `"cancelled"` with `"cancelledAt"` set.
- `authorized`: `"status"` is `"cancelling"` while the cancellation is processed at the Sefin. The issuance credit is not refunded.
- `processing`: stays `"processing"` with `"cancellationRequestedAt"` set and is cancelled once authorized.

The description (15 to 255 characters) is required for an authorized or processing invoice and optional for a queued one. Read the invoice again (or listen to the `nfse.invoice.cancelled` and `nfse.invoice.cancellation_rejected` webhooks) to see the outcome: `cancelled`, or back to `authorized` with `lastErrorCode` when the cancellation was rejected.

### Look up a CNPJ and manage customers

```elixir
{:ok, cnpj} = CorvoNfse.Resources.Cnpj.lookup(client, "11222333000181")
cnpj["legalName"]

{:ok, page} = CorvoNfse.Resources.Customers.search(client, search: "ada", limit: 20)
{:ok, customer} = CorvoNfse.Resources.Customers.get(client, "52998224725")
{:ok, _} = CorvoNfse.Resources.Customers.update(client, "52998224725", %{"email" => "novo@example.com"})
{:ok, _} = CorvoNfse.Resources.Customers.remove(client, "52998224725")

{:ok, _favorite} =
  CorvoNfse.Resources.ServiceFavorites.create(client, company_id, %{
    "label" => "Consultoria", "serviceCode" => "010101", "description" => "Consultoria em TI"
  })
```

### Substitute an invoice, send the e-mail elsewhere, review

```elixir
{:ok, substitute} =
  CorvoNfse.Resources.Invoices.substitute(client, "inv_1", %{"description" => "Descricao corrigida"},
    idempotency_key: "sub-1"
  )

{:ok, _} = CorvoNfse.Resources.Invoices.send_email(client, "inv_1", email: "outro@example.com")
{:ok, _} = CorvoNfse.Resources.Invoices.review(client, "retry", ["inv_7"])  # invoices in manual_review
```

### Accountant package

```elixir
{:ok, _} = CorvoNfse.Resources.AccountantPackage.update(client, company_id, %{"accountantEmail" => "contador@example.com"})
{:ok, _} = CorvoNfse.Resources.AccountantPackage.send(client, company_id, "2026-10")
{:ok, %{body: zip}} = CorvoNfse.Resources.InvoicePackage.download(client, company_id, "2026-10")
```

### Schedules

```elixir
{:ok, page} = CorvoNfse.Resources.Schedules.list(client, status: "active")
{:ok, _} = CorvoNfse.Resources.Schedules.pause(client, "sch_1")
{:ok, runs} = CorvoNfse.Resources.Schedules.list_runs(client, "sch_1")
```

### Import a spreadsheet

```elixir
{:ok, %{body: template}} = CorvoNfse.Resources.Imports.download_template(client)
{:ok, job} = CorvoNfse.Resources.Imports.start(client, {:file, "notas.csv"}, company_id: company_id)
# poll Imports.get/2 until job["status"] == "ready", fix rows with update_row/4, then:
{:ok, _} = CorvoNfse.Resources.Imports.emit(client, job["id"], send_email: true)
```

### Plans and credits

Plan slugs are `free`, `solo`, `equipe`, `empresa` and `escala` (plus `self-hosted`); treat them as open strings and read the allowance from `monthlyCreditAllowance`.

```elixir
{:ok, %{"balance" => balance, "planRemaining" => plan, "avulsoBalance" => loose}} =
  CorvoNfse.Resources.Credits.balance(client)   # balance = plan notes left + loose notes

{:ok, %{"totalCents" => total}} = CorvoNfse.Resources.Credits.preview_purchase(client, 10)
```

### Webhook environments

A webhook created with a `corvo_test_` key only receives test events and cannot reach live webhooks; use a `corvo_live_` key to manage live ones. Destinations that resolve to private networks are refused.

### Handling errors

```elixir
case CorvoNfse.Resources.Companies.get(client, "comp_missing") do
  {:ok, company} ->
    company

  {:error, %CorvoNfse.Error{status: 404, code: code, request_id: request_id}} ->
    Logger.warning("not found code=#{code} request_id=#{request_id}")
end
```

`CorvoNfse.Error` fields: `status`, `code` (the API's `ERROR_*` code, or `http_<status>`, `network_error`, `timeout`, `invalid_json`), `message`, `details`, `request_id`, `retry_after` (seconds, on `429`).

### Pagination and streaming

```elixir
{:ok, stream} = CorvoNfse.Resources.Invoices.iterate(client, status: "authorized", limit: 50)

stream
|> Stream.take(200)
|> Enum.each(&index/1)
```

`iterate` fetches the first page eagerly: a failure there returns `{:error, %CorvoNfse.Error{}}` and nothing was streamed. If a page after the first fails while you consume the stream, the stream raises the `%CorvoNfse.Error{}`.

### Download the PDF or XML

The invoice must be `authorized` and have its documents ready.

```elixir
{:ok, %{body: pdf, mime_type: "application/pdf", file_name: file_name}} =
  CorvoNfse.Resources.Invoices.pdf(client, "inv_1")

File.write!(file_name, pdf)
```

### Verify webhooks

```elixir
[signature] = Plug.Conn.get_req_header(conn, "x-corvo-signature")
{:ok, raw_body, _conn} = Plug.Conn.read_body(conn)  # the raw bytes, not the parsed JSON

if CorvoNfse.Webhooks.verify_signature(raw_body, signature, secret) do
  # verified; deduplicate by the event id, the same event can arrive twice
end
```

`CorvoNfse.Types.Webhook.events/0` lists the 12 events you can subscribe to. The `webhook.test` event is only sent by `Webhooks.test/2`.

## Resources

| Resource | Operations |
|---|---|
| `CorvoNfse.Resources.Companies` | `create`, `list`, `iterate`, `get`, `update`, `remove` |
| `CorvoNfse.Resources.Certificates` | `upload`, `list`, `remove` |
| `CorvoNfse.Resources.Invoices` | `create`, `create_batch`, `calculate`, `get`, `list`, `iterate`, `events`, `pdf`, `xml`, `download_url`, `send_email`, `cancel`, `substitute`, `overview`, `review` |
| `CorvoNfse.Resources.InvoicePackage` | `summary`, `download` |
| `CorvoNfse.Resources.Customers` | `search`, `iterate`, `get`, `update`, `remove` |
| `CorvoNfse.Resources.Cnpj` | `lookup` |
| `CorvoNfse.Resources.ServiceFavorites` | `list`, `create`, `remove` |
| `CorvoNfse.Resources.AccountantPackage` | `get`, `update`, `send`, `list_sends` |
| `CorvoNfse.Resources.Schedules` | `list`, `iterate`, `get`, `update`, `pause`, `resume`, `cancel`, `list_runs`, `iterate_runs` |
| `CorvoNfse.Resources.Imports` | `start`, `list`, `get`, `emit`, `list_rows`, `iterate_rows`, `update_row`, `discard`, `download_template`, `download_errors` |
| `CorvoNfse.Resources.FiscalProfiles` | `list`, `upsert`, `approve` |
| `CorvoNfse.Resources.ServiceTaxProfiles` | `list`, `create`, `update`, `remove`, `approve` |
| `CorvoNfse.Resources.DpsSequence` | `get`, `set` |
| `CorvoNfse.Resources.FiscalPortal` | `status` |
| `CorvoNfse.Resources.Integrations` | `list_providers` |
| `CorvoNfse.Resources.IntegrationConnections` | `create`, `list`, `get`, `validate`, `update_credentials`, `activate`, `pause`, `disconnect`, `list_rules`, `replace_rules`, `list_events`, `list_operations` |
| `CorvoNfse.Resources.IntegrationOperations` | `complete_customer`, `retry` |
| `CorvoNfse.Resources.Webhooks` | `list`, `create`, `remove`, `test` |
| `CorvoNfse.Resources.Webhooks.Deliveries` | `list`, `iterate`, `stats`, `retry` |
| `CorvoNfse.Resources.Credits` | `balance`, `plans`, `history`, `iterate_history`, `preview_purchase` |
| `CorvoNfse.Resources.Billing` | `plan`, `usage` |
| `CorvoNfse.Resources.Health` | `live` (and `ready`, which is not part of the contract) |
| `CorvoNfse.Resources.Plans` | `list`, `get`, `quote` (public price catalog, not part of the contract) |

Changing plans and the billing portal exist only in the dashboard, so they are not in the SDK. `CorvoNfse.Types.*` documents every wire type with `defstruct` and `@type`.

## Configuration

`CorvoNfse.new/1` options (with environment fallbacks):

| Option | Environment | Default |
|---|---|---|
| `:api_key` | `CORVO_API_KEY` | required |
| `:base_url` | `CORVO_BASE_URL` | `https://api.corvo.tech` |
| `:prefix` | `CORVO_API_PREFIX` | `"v1"` |
| `:receive_timeout` | none | 30_000 ms |
| `:allow_insecure_http` | none | `false` (`http://` only for loopback and private hosts) |

Auth is the `X-API-Key` header. Keys are `corvo_test_...` or `corvo_live_...` and belong to one account and environment; the key decides the environment.

## Development

```bash
mix deps.get
mix test      # the live contract test is excluded without env
mix format --check-formatted
mix credo --strict
```

`spec/openapi.json` is the vendored API contract (from `docs/openapi/openapi.json` in corvo-nfse). `test/corvo_nfse/openapi_coverage_test.exs` maps every `operationId` to an SDK function and checks its HTTP method, path, query and body against the contract: when the API changes, replace the file and the test names what is missing.

The contract test runs only when `CORVO_API_KEY` and `CORVO_BASE_URL` point to a reachable instance.

## License

MIT, see [LICENSE](LICENSE).
