# Changelog

All notable changes to MoonHook are documented in this file.

## [0.3.1] - 2026-09-11

### Added

- README for the `transport_http` package, so the mooncakes.io package page
  documents the sender, receiver, retry semantics and the `e2e` demo instead of
  reporting a missing README.

## [0.3.0] - 2026-09-07

### Added

- `transport_http` package: real HTTP delivery built on `moonbitlang/async`.
  - `post_signed_request` performs one signed POST attempt and classifies the
    response: 2xx is success, 408/425/429 and 5xx are retryable, other 4xx is
    terminal, and connection level errors are retryable.
  - `http_transport` returns an async transport that signs each event with the
    existing `build_signed_request` helper.
  - `AsyncDeliveryEngine` keeps the lookup, retry and dead letter semantics of
    `DeliveryEngine`, but awaits every attempt and sleeps
    `RetryPolicy::next_delay_ms` between attempts instead of retrying back to
    back.
  - `webhook_receiver` builds an `@http.Server` handler that reads the request
    body, verifies the signature and the timestamp window, and answers 200 or
    401.
- End-to-end integration tests against a real local HTTP server: successful
  delivery with receiver side verification, retry after a 500 response,
  rejection of a wrong secret, and rejection of a replayed timestamp.
- `cmd/httpdemo` CLI with `e2e`, `serve`, and `deliver` commands.
- `DeliveryResult::success_with_status`, so transports can report the status
  code returned by the receiver instead of a hardcoded `200`.
- CI covers the native and wasm-gc targets (check + test) and checks js.

### Changed

- `preferred_target` is now `native`: the HTTP adapter needs the native IO of
  `moonbitlang/async`, and interface generation follows the canonical target.
  The core package stays target agnostic and is still verified on wasm-gc and
  js, because the new packages declare `supported_targets = "+native"`.
- New dependency: `moonbitlang/async@0.21.3` (Apache-2.0).
- Re-formatted with `moon fmt` from toolchain 0.1.20260824.

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
