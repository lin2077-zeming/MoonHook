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

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/lin2077-zeming/MoonHook"

license = "Apache-2.0"

keywords = [
  "webhook",
  "delivery",
  "hmac",
  "retry",
  "outbox",
  "idempotency",
  "audit",
  "moonbit",
]

preferred_target = "wasm-gc"

description = "Lightweight webhook delivery framework for MoonBit with signing, retry, outbox, dead letter, idempotency, and audit."
