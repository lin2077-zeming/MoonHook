///|
/// Controls whether and how a failed delivery is retried.
///
/// - `None`: no retry, the first failure moves the event to the dead letter queue.
/// - `Fixed(delay_ms)`: every retry waits the same delay.
/// - `Exponential(initial_ms, multiplier, max_ms)`: delay grows by a multiplier,
///   capped at `max_ms`.
pub(all) enum RetryPolicy {
  None
  Fixed(Int)
  Exponential(Int, Double, Int)
} derive(Eq, @debug.Debug)

///|
/// Returns the delay before retry `attempt`, where attempt starts at 1 for the
/// first retry after the initial failure.
pub fn RetryPolicy::next_delay_ms(self : RetryPolicy, attempt : Int) -> Int {
  match self {
    None => 0
    Fixed(delay_ms) => if attempt > 0 { delay_ms } else { 0 }
    Exponential(initial_ms, multiplier, max_ms) =>
      if attempt <= 0 {
        0
      } else {
        let exponent = (attempt - 1).to_double()
        let raw = initial_ms.to_double() * @math.pow(multiplier, exponent)
        let capped = if raw > max_ms.to_double() {
          max_ms
        } else {
          raw.to_int()
        }
        if capped < 0 { 0 } else { capped }
      }
  }
}

///|
/// Returns true when another attempt is allowed.
pub fn RetryPolicy::should_retry(
  self : RetryPolicy,
  attempt : Int,
  max_attempts : Int,
) -> Bool {
  match self {
    None => false
    _ => attempt < max_attempts
  }
}

///|
/// A short human-readable description used by the CLI and audit logs.
pub fn RetryPolicy::describe(self : RetryPolicy) -> String {
  match self {
    None => "none"
    Fixed(delay_ms) => "fixed(\{delay_ms}ms)"
    Exponential(initial_ms, multiplier, max_ms) =>
      "exponential(\{initial_ms}ms x\{multiplier}, max \{max_ms}ms)"
  }
}
