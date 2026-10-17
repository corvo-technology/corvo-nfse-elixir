# Changelog

All notable changes to `corvo_nfse` are documented here.

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
