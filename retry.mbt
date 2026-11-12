///|
/// Controls whether and how a failed delivery is retried.
///
/// - `None`: no retry, the first failure moves the event to the dead letter queue.
/// - `Fixed(delay_ms)`: every retry waits the same delay.
/// - `Exponential(initial_ms, multiplier, max_ms)`: delay grows by a multiplier,
///   capped at `max_ms`.
#derive(Eq, @debug.Debug)
pub(all) enum RetryPolicy {
  None
  Fixed(Int32)
  Exponential(Int32, Double, Int32)
}

///|
/// Returns the delay before retry `attempt`, where attempt starts at 1 for the
/// first retry after the initial failure.
pub fn RetryPolicy::next_delay_ms(self : RetryPolicy, attempt : Int32) -> Int32 {
  match self {
    None => 0
    Fixed(delay_ms) =>
      if attempt > 0 {
        if delay_ms < 0 {
          0
        } else {
          delay_ms
        }
      } else {
        0
      }
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
        if capped < 0 {
          0
        } else {
          capped
        }
      }
  }
}

///|
/// Validates the policy parameters used by a Hook.
pub fn RetryPolicy::validate(self : RetryPolicy) -> Result[Unit, String] {
  match self {
    None => Ok(())
    Fixed(delay_ms) =>
      if delay_ms < 0 {
        Err("retry delay must be non-negative")
      } else {
        Ok(())
      }
    Exponential(initial_ms, multiplier, max_ms) =>
      if initial_ms <= 0 {
        Err("initial retry delay must be positive")
      } else if multiplier < 1.0 {
        Err("retry multiplier must be at least 1")
      } else if max_ms < initial_ms {
        Err("max retry delay must be at least the initial delay")
      } else {
        Ok(())
      }
  }
}

///|
/// Returns true when another attempt is allowed.
pub fn RetryPolicy::should_retry(
  self : RetryPolicy,
  attempt : Int32,
  max_attempts : Int32,
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
