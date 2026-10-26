# corvo-nfse

Elixir SDK for the [Corvo](https://corvo.tech) NFS-e API. Register companies, calculate taxes, issue Brazilian service invoices (NFS-e), follow them by webhook and download the PDF and XML, from Elixir 1.16+.

- **Result-style, never raises.** Every API, network or timeout failure comes back as `{:error, %CorvoNfse.Error{}}` with `status`, `code`, `message`, `details`, `request_id` and `retry_after`.
- **Pagination built in.** `list/2` returns one page; `iterate/2` returns a `Stream` that follows `hasMore` and `nextCursor`.
- **Safe retries.** Issuing an invoice and sending an email accept an idempotency key.
- **Webhook verification in one call.** HMAC-SHA256 against the raw body, constant-time.
- The wire format is passed through unchanged: responses are plain maps with string keys, exactly as the server sent them. Library only, no CLI.

Full API reference: <https://corvo.tech/en/docs>.

## Installation

```elixir
def deps do
  [
    {:corvo_nfse, "~> 0.2.0"}
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
    "taxRegime" => "Simples Nacional",   # "MEI" | "Simples Nacional" | "Lucro Presumido" | "Lucro Real"
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

Use `"options" => %{"type" => "SCHEDULE"}` with a future `competenceDate` to schedule the issuance.

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

`CorvoNfse.Types.Webhook.events/0` lists the 9 events you can subscribe to. The `webhook.test` event is only sent by `Webhooks.test/2`.

## Resources

| Resource | Operations |
|---|---|
| `CorvoNfse.Resources.Companies` | `create`, `list`, `iterate`, `get`, `update`, `remove` |
| `CorvoNfse.Resources.Certificates` | `upload`, `list`, `remove` |
| `CorvoNfse.Resources.Invoices` | `create`, `calculate`, `get`, `list`, `iterate`, `events`, `pdf`, `xml`, `download_url`, `send_email` |
| `CorvoNfse.Resources.Webhooks` | `list`, `create`, `remove`, `test` |
| `CorvoNfse.Resources.Webhooks.Deliveries` | `list`, `iterate`, `stats`, `retry` |
| `CorvoNfse.Resources.Credits` | `balance`, `plans`, `history`, `iterate_history` |
| `CorvoNfse.Resources.Billing` | `plan`, `usage` |
| `CorvoNfse.Resources.Plans` | `list`, `get`, `quote` (public price catalog) |
| `CorvoNfse.Resources.Health` | `live`, `ready` |

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
mix test      # the contract test is excluded without env
mix credo --strict
```

The contract test runs only when `CORVO_API_KEY` and `CORVO_BASE_URL` point to a reachable instance.

## License

MIT, see [LICENSE](LICENSE).
