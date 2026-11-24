# Changelog

All notable changes to `corvo_nfse` are documented here.

## 0.3.0

Follows the public API contract 0.3.0 (`spec/openapi.json`): all 92 operations are covered, and
`test/corvo_nfse/openapi_coverage_test.exs` fails when the contract has an operation the SDK lacks.
(The version jumps from 0.2.0 to 0.3.0 so the SDK number follows the contract number.)

### Breaking

- **Plan slugs** `developer`, `growth`, `scale` and `volume` are gone. They are now `free`,
  `solo`, `equipe`, `empresa` and `escala` (plus `self-hosted`). Treat the slug as an open string.
- **`Invoices.create/3` with `"options" => %{"type" => "SCHEDULE"}`** no longer answers with an invoice:
  `{:ok, data}` is a schedule (snake_case fields). `"RECURRING"` (with `"recurrence"`) is new and
  answers the same way. Follow the schedule with `Schedules`.
- **`Credits.balance/1`**: `overageUnits` and `overageAmountCents` were removed; `planRemaining` and
  `avulsoBalance` were added, and `balance` now includes the loose notes.
- **`Billing.plan/1`**: `usage.overage_units` and `usage.overage_amount_cents` were removed;
  `usage.avulso_balance`, `subscription.stripe_portal_available`, `stripe_subscription` and
  `pix_subscription` were added. A workspace without a plan answers `404` with `NO_PLAN_ASSIGNED`.
- **Credits purchase preview** is now `Credits.preview_purchase/2` (`GET /credits/purchase/preview?units=N`);
  the old `POST` only answered `410`.
- **Webhook events**: 12 types (`nfse.invoice.taker_rejected` is new). A test key can no longer reach
  live webhooks (webhooks are tied to the key's environment), and URLs that resolve to private
  networks are refused.
- Invoice fields follow the contract: `documentsReadyAt`, `documentsStatus`, `emailStatus`, `stage`,
  `lastEmailStatus` (not `documentsReady`/`lastEmail`); new `substitutesInvoiceId`,
  `substitutionDescription` and `portalFlag`.

### Added

- New resources: `Customers` (`search`, `iterate`, `get`, `update`, `remove`), `Cnpj.lookup/2`,
  `ServiceFavorites`, `AccountantPackage` (`get`, `update`, `send`, `list_sends`), `InvoicePackage`
  (`summary`, ZIP `download`), `Schedules` (`list`, `iterate`, `get`, `update`, `pause`, `resume`,
  `cancel`, `list_runs`, `iterate_runs`), `Imports` (multipart `start`, `list`, `get`, `emit`,
  `list_rows`, `iterate_rows`, `update_row`, `discard`, `download_template`, `download_errors`),
  `FiscalProfiles`, `ServiceTaxProfiles`, `DpsSequence`, `FiscalPortal.status/1`, `Integrations`,
  `IntegrationConnections` and `IntegrationOperations`.
- `Invoices.substitute/4`, `Invoices.overview/2`, `Invoices.review/3`, the `customer_tax_id:` list filter
  and the `email:` option of `Invoices.send_email/3`.
- `Credits.preview_purchase/2`.
- `CorvoNfse.Multipart` (shared multipart builder), `Types.Schedule`, `Types.Credits.PurchasePreview`.
- A `User-Agent: corvo-nfse-elixir/<version>` header on every request.
- Requests accept `PUT`.

### Changed

- CI checks formatting and also runs Elixir 1.18.
- Plan docs and the `Types` docs follow the new contract.

## 0.1.1

### Fixed

- Resources and list items are read straight from `data`: `Invoices.create/3`, `Invoices.get/2`
  and the invoice, event, plan and history lists no longer return `nil` items (the SDK looked for a
  `props` wrapper the API does not send).
- Type docs follow the API: optional customer and `service.code`, `discount`, `options.type`,
  `sendMunicipalReg`, `defaultServiceCode`, `scheduledFor`, `monthlyCreditAllowance`, the real
  credit transaction fields and `reason` on the quota status.
- `Types.Webhook.events/0` lists `nfse.invoice.fiscal_discrepancy` and no longer `webhook.test`, which
  cannot be subscribed.

### Added

- `Invoices.calculate/2` (pre-emission tax estimate) and `CorvoNfse.Resources.Plans` (public catalog).

## Unreleased

### Added

- `Invoices.create_batch/2` (`POST /v1/invoices/batches`, 1 to 50 items, per-item `idempotencyKey`).
- `Invoices.cancel/4` (`POST /v1/invoices/:id/cancel`), the `cancelling`/`cancelled` statuses and the
  `cancellation*` fields on the invoice.
- `deduction` on invoice params; `discount` and `deduction` on the invoice.
- `simplesRate` and `simplesIssRate` on company params.
- `Types.Webhook.events/0` lists 11 events (adds `nfse.invoice.cancelled` and
  `nfse.invoice.cancellation_rejected`).

### Changed

- Only `MEI` and `Simples Nacional` are documented as tax regimes (the API rejects the others).

### Contract changes

Cross-SDK contract changes (new/removed operations, envelope or error-code
changes) are synced from `corvo-nfse-node`, which is the source of truth. This
section records them per release; see the shared design spec for the process.

### Added

- Initial release: 28 API-key operations plus 2 public health checks.
- Envelope unwrapping (`data` / `none`), `204 -> nil`.
- Result-style `{:ok, data} | {:error, %CorvoNfse.Error{}}`.
- `iterate` streams with eager first page (`{:error, ...}` on first-page
  failure).
- `CorvoNfse.Webhooks.verify_signature/3` (HMAC-SHA256, constant-time).
