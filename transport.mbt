///|
/// The outcome of one physical delivery attempt.
pub(all) struct DeliveryResult {
  ok : Bool
  retryable : Bool
  status_code : Int
  error : String
  duration_ms : Int
} derive(Eq, @debug.Debug)

///|
pub fn DeliveryResult::success(duration_ms : Int) -> DeliveryResult {
  { ok: true, retryable: false, status_code: 200, error: "", duration_ms, }
}

///|
/// A successful attempt that records the status code reported by the receiver,
/// so transports can distinguish `200` from `202` or `204`.
pub fn DeliveryResult::success_with_status(
  status_code : Int,
  duration_ms : Int,
) -> DeliveryResult {
  { ok: true, retryable: false, status_code, error: "", duration_ms, }
}

///|
pub fn DeliveryResult::failure(
  status_code : Int,
  error : String,
  duration_ms : Int,
  retryable : Bool,
) -> DeliveryResult {
  { ok: false, retryable, status_code, error, duration_ms, }
}

///|
/// A transport is a function that performs one delivery attempt.
/// HTTP adapters, test doubles, and in-process sinks all fit this shape.
pub type Transport = (Hook, WebhookEvent) -> DeliveryResult

///|
/// A scripted transport used in tests. It returns the configured results in
/// order and then reports retryable 500 errors once exhausted.
pub struct MockTransport {
  results : Array[DeliveryResult]
  next : @ref.Ref[Int]
} derive(@debug.Debug)

///|
pub fn MockTransport::new(results : Array[DeliveryResult]) -> MockTransport {
  { results, next: @ref.new(0), }
}

///|
pub fn MockTransport::send(
  self : MockTransport,
  _hook : Hook,
  _event : WebhookEvent,
) -> DeliveryResult {
  let index = self.next.val
  self.next.val = index + 1
  if index < self.results.length() {
    self.results[index]
  } else {
    DeliveryResult::failure(500, "mock transport exhausted", 0, true)
  }
}

///|
/// Convenience wrapper so a `MockTransport` can be passed directly to a
/// `DeliveryEngine` through a closure.
pub fn MockTransport::as_transport(self : MockTransport) -> Transport {
  fn(hook, event) { self.send(hook, event) }
}
