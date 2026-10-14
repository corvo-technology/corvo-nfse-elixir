# corvo-nfse

Official Elixir SDK for the Corvo NFS-e API — 28 API-key operations plus 2 public health checks, cursor pagination, result-style errors and webhook signature verification.

Corvo is API-first: this repository is a thin, predictable library over the same contract shared by every Corvo SDK (Python, Go, Ruby, PHP, Rust, .NET, Elixir, Java and the canonical Node.js SDK). The wire format is passed through unchanged — no re-casing of server fields.

## Why

- **Result-style, never raises.** Every API, network or timeout failure comes back as `{:error, %CorvoNfse.Error{}}` with `status`, `code`, `message`, `details`, `request_id` and `retry_after` — the same error contract as the Node SDK.
- **Envelope handling built in.** `{data: ...}`, `{data: {props: ...}}` and `204 No Content` are unwrapped to the value you actually want; `nil` for empty responses.
- **Cursor pagination that disappears.** `list/2` returns one page; `iterate/2` returns a `Stream` that follows `hasMore`/`nextCursor` for you.
- **`X-API-Key` auth, self-host friendly.** Defaults to `https://api.corvo.tech`, honors `CORVO_API_KEY` / `CORVO_BASE_URL` / `CORVO_API_PREFIX`, and accepts `http://` for loopback/private hosts.
- **Webhook verification in one call.** Constant-time HMAC-SHA256 verification against the raw body.

## Installation

```elixir
def deps do
  [
    {:corvo_nfse, "~> 0.1.0"}
  ]
end
```

## Quickstart

```elixir
client = CorvoNfse.new(api_key: "corvo_test_...")  # or CORVO_API_KEY

{:ok, page} = CorvoNfse.Resources.Companies.list(client, limit: 10)
page.data        #=> [%{"id" => "comp_...", "legalName" => "..."}]
page.pagination  #=> %{"limit" => 10, "hasMore" => true, "nextCursor" => "eyJ..."}

{:ok, invoice} =
  CorvoNfse.Resources.Invoices.create(
    client,
    %{
      "customer" => %{"name" => "Ada Lovelace", "taxId" => "12345678900"},
      "service" => %{"code" => "0101", "municipalityCode" => "3550308"},
      "amount" => 10.5,
      "competenceDate" => "2026-10-01"
    },
    idempotency_key: "my-key-42"
  )
```

### Handling errors

```elixir
case CorvoNfse.Resources.Companies.get(client, "comp_missing") do
  {:ok, company} ->
    company

  {:error, %CorvoNfse.Error{status: 404, code: code, request_id: request_id}} ->
    Logger.warning("not found code=#{code} request_id=#{request_id}")
end
```

`CorvoNfse.Error` fields: `status`, `code` (stable: `ERROR_*`, `http_500`, `network_error`, `timeout`, `invalid_json`), `message`, `details`, `request_id`, `retry_after`. Construction problems (missing API key, invalid base URL) raise `ArgumentError`; nothing else does.

### Pagination and streaming

```elixir
{:ok, stream} = CorvoNfse.Resources.Invoices.iterate(client, status: "authorized", limit: 50)

stream
|> Stream.take(200)
|> Enum.each(&index/1)
```

`iterate` fetches the **first page eagerly**: a failure there returns `{:error, %CorvoNfse.Error{}}` and nothing was streamed. On success you get `{:ok, stream}`. If a page *after* the first fails while you consume the stream, the stream raises the `%CorvoNfse.Error{}` (the single documented raising site in the SDK).

### Verifying webhooks

```elixir
[signature] = Plug.Conn.get_req_header(conn, "x-corvo-signature")
{:ok, raw_body, _conn} = Plug.Conn.read_body(conn)

if CorvoNfse.Webhooks.verify_signature(raw_body, signature, secret) do
  # verified: HMAC-SHA256, constant-time comparison
end
```

Known test vector (also asserted by the test suite):

```
body     {"type":"nfse.invoice.authorized","data":{"id":"inv_1"}}
secret   whsec_test_123
signature  sha256=8f9bd040d8f717b19618ab3395ddfa4b8c176b8dc863195227b88dd85426bbbc
```

### Downloads

```elixir
{:ok, %{body: pdf, mime_type: "application/pdf", file_name: "nfse_123.pdf"}} =
  CorvoNfse.Resources.Invoices.pdf(client, "inv_1")
```

## Resource surface

Exactly the shared contract — no subsets, no extras (asserted by `test/corvo_nfse_test.exs`):

| Resource | Operations |
|---|---|
| `CorvoNfse.Resources.Companies` | `create`, `list`, `iterate`, `get`, `update`, `remove` |
| `CorvoNfse.Resources.Certificates` | `upload`, `list`, `remove` |
| `CorvoNfse.Resources.Invoices` | `create`, `get`, `list`, `iterate`, `events`, `pdf`, `xml`, `download_url`, `send_email` |
| `CorvoNfse.Resources.Webhooks` | `list`, `create`, `remove`, `test` |
| `CorvoNfse.Resources.Webhooks.Deliveries` | `list`, `iterate`, `stats`, `retry` |
| `CorvoNfse.Resources.Credits` | `balance`, `plans`, `history`, `iterate_history` |
| `CorvoNfse.Resources.Billing` | `plan`, `usage` |
| `CorvoNfse.Resources.Health` (public) | `live`, `ready` |

Response entities are plain maps with **string keys** exactly as the server sent them; `CorvoNfse.Types.*` mirrors every wire type with `defstruct` + `@type`.

## CLI

This package is library-only. The CLI ships with the Node SDK ([`corvo-nfse-node`](https://github.com/corvo-technology/corvo-nfse-node)) — use `npx corvo-nfse` (or the `corvo` binary) for one-off operations; both SDKs hit the same API.

## Development

```bash
mix deps.get
mix compile
mix test              # unit + resource suites; contract test auto-skips without env
mix credo --strict
```

Contract tests against a live instance run only when `CORVO_API_KEY` **and** `CORVO_BASE_URL` are set:

```bash
CORVO_API_KEY=corvo_live_... CORVO_BASE_URL=https://api.corvo.tech mix test
```

## License

MIT © Corvo Technology — see [LICENSE](LICENSE).
