# Changelog

All notable changes to MoonHook are documented in this file.

## [0.4.1] - 2026-11-13

Maintenance release for the quarterly compatibility review. No behavioural
change to the library API; everything below is toolchain compatibility.

### Changed

- Verified on the current toolchain: `moon 0.1.20261104`,
  `moonc v0.10.20+65efd5b93`, `core 0.10.20+65efd5b93`. The README now records
  these versions and the minimum toolchain requirement.
- Migrated all 20 `} derive(...)` clauses to the `#derive(...)` attribute syntax.
  moonc v0.10.20 reports the old form as `deprecated_syntax`, which is an error
  under `--deny-warn`.
- Adopted the canonical `Int32` / `UInt32` spelling that `moon fmt` now
  normalises to. `Int` / `UInt` are aliases of the same types
  (`#alias(Int32)` in core), so this is source compatible for consumers.
- `moonbitlang/async` 0.21.3 -> 0.22.9. async 0.22.9 needs core 0.10.20; it does
  not compile on moonc v0.10.18 or older.
- Reformatted the whole module with `moon fmt` from the new toolchain.

### Added

- `extends.mbt`: explicit `pub extend` declarations for every derived `Eq` and
  `@debug.Debug` impl, following the convention used by `moonbitlang/core`.
  moonc v0.10.18+ deprecates implicitly promoting derived trait methods to
  regular methods (`implicit_impl_as_method`), which broke `--deny-warn`.
  `Eq::equal` stays promoted; `Eq::not_equal` and `Debug::to_repr` remain
  available but are deprecated and hidden from the generated interface.
- CI runs `moon test --target js --deny-warn`, so all three supported targets
  are tested and not merely type checked.

### Fixed

- Removed the unused `moonbitlang/core/array` and `moonbitlang/core/uint`
  package imports (`unused_package`).
- `MockTransport::new` uses `@ref.Ref(0)` instead of the deprecated
  `@ref.new(0)`.

## [0.4.0] - 2026-09-11

### Added

- `SignatureProvider`: outbound signing for the schemes providers actually use,
  with the sender and the receiver sharing one implementation.
  - `GitHub`: `X-Hub-Signature-256: sha256=<hex>` over the raw body.
  - `Stripe`: `Stripe-Signature: t=<unix_s>,v1=<hex>` over `"<t>.<body>"`,
    accepting several `v1` values so secret rotation keeps working.
  - `Slack`: `X-Slack-Signature: v0=<hex>` plus `X-Slack-Request-Timestamp`
    over `"v0:<t>:<body>"`.
  - `FeishuBot`: `timestamp` / `sign` fields inside the JSON body, with
    `sign = base64(HMAC-SHA256(key = "<t>\n<secret>", message = ""))`; the
    signature does not cover the message body, which is documented.
  - `Shopify`: `X-Shopify-Hmac-Sha256: <base64>` over the raw body.
  - `sign_value`, `sign_headers`, `header_names`, `verify`, `parse` and
    `describe`, plus `SignedRequest::with_provider_signature` to attach the
    provider headers to an already signed request.
  - `feishu_bot_text_body` builds a complete custom-bot message body.
- Signature tests: GitHub's documented vector plus values cross-checked against
  an independent HMAC-SHA256 implementation, rotation, replay window, tampering
  and case-insensitive header cases.
- CLI: `providers` and `sign-provider <provider> <secret> <timestamp_s> <payload>`.

## [0.3.2] - 2026-09-11

### Changed

- The module description now states the positioning explicitly: an
  **outbound** webhook delivery framework. No library code changed in this
  release.

### Added

- `docs/SCOPE.md`: what is in and out of scope for MoonHook, and how it
  relates to webhook projects aimed at the inbound side.
- CI gates on `--deny-warn` for `check` and `test` on native, wasm-gc and
  js, fails when `moon info` would change the committed interfaces, prints
  a coverage summary, and smoke-tests the end-to-end demo.

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
