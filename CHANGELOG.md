# Changelog

All notable changes to `corvo_nfse` are documented here.

## Unreleased

### Contract changes

Cross-SDK contract changes (new/removed operations, envelope or error-code
changes) are synced from `corvo-nfse-node`, which is the source of truth. This
section records them per release; see the shared design spec for the process.

### Added

- Initial release: 28 API-key operations plus 2 public health checks.
- Envelope unwrapping (`data` / `data+props` / `none`), `204 -> nil`.
- Result-style `{:ok, data} | {:error, %CorvoNfse.Error{}}`.
- `iterate` streams with eager first page (`{:error, ...}` on first-page
  failure).
- `CorvoNfse.Webhooks.verify_signature/3` (HMAC-SHA256, constant-time).
