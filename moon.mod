// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "lin2077-zeming/MoonHook"

version = "0.3.1"

readme = "README.mbt.md"

repository = "https://github.com/lin2077-zeming/MoonHook"

license = "Apache-2.0"

keywords = [
  "webhook",
  "delivery",
  "http",
  "hmac",
  "retry",
  "outbox",
  "idempotency",
  "audit",
  "moonbit",
]

// The core package stays target agnostic and is checked on wasm-gc and js in
// CI, but `transport_http` needs `moonbitlang/async` and therefore native IO.

preferred_target = "native"

description = "Outbound webhook delivery framework for MoonBit: signing, retry with backoff, outbox, dead letter, idempotency, audit, and real HTTP delivery over moonbitlang/async."

import {
  "moonbitlang/async@0.21.3",
}
