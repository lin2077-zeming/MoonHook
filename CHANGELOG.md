# Changelog

All notable changes to MoonHook are documented in this file.

## [0.2.0] - 2026-08-18

### Added

- Receiver-side webhook verification:
  - `verify_signature_header` and `verify_webhook_request` now accept both raw
    hex signatures and GitHub-style `sha256=<hex>` header values.
  - `sign_webhook` / `verify_webhook` sign `"<timestamp_ms>.<payload>"` and
    enforce a replay-protection time window.
  - `verify_webhook_request_with_timestamp` verifies a MoonHook native signed
    request using the timestamp header.
- HTTP header constants (`X-MoonHook-*`) and case-insensitive header lookup in
  `find_header` and `Hook::header_value`.
- JSON serialization for `Hook`, `RetryPolicy`, `PendingDelivery`, and
  `DeadLetterEntry`, with round-trip tests.
- `RetryPolicy::validate` and stricter `Hook::validate` checks for retry
  delays, multiplier, and max delay.
- CLI `request` command that prints a fully signed HTTP request.
- `moon fmt --check` in CI.

### Fixed

- `DeliveryEngine` now honors `RetryPolicy::None`; a retryable failure under
  the `None` policy moves straight to the dead letter queue after one attempt.
- Negative retry delays are clamped to zero for direct policy use.

### Changed

- `build_signed_request` signs `"<timestamp_ms>.<payload>"` instead of the raw
  payload, and `verify_signed_request` verifies using the timestamp header.
- Version bumped to `0.2.0`.

## [0.1.0] - 2026-08-09

### Added

- `WebhookEvent` / `Hook` models with validation builders.
- `HookRegistry` for registration, lookup, and deduplication.
- Pure MoonBit SHA-256 and HMAC-SHA256 with RFC test vectors.
- `RetryPolicy` with none, fixed, and exponential backoff modes.
- `DeliveryEngine` with retry and dead letter handling.
- `InMemoryOutbox` / `InMemoryDeadLetter`.
- `IdempotencyStore` with TTL cleanup.
- `AuditLog` with recent-entry queries.
- Demo CLI with `demo`, `sign`, and `verify` commands.
