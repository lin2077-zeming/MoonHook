///|
/// Final state of a delivery after all attempts.
pub(all) enum DeliveryStatus {
  Success
  Retry
  DeadLetter
  Skipped
} derive(Eq, @debug.Debug)

///|
pub fn DeliveryStatus::describe(self : DeliveryStatus) -> String {
  match self {
    Success => "success"
    Retry => "retry"
    DeadLetter => "dead_letter"
    Skipped => "skipped"
  }
}

///|
/// A single recorded attempt inside a delivery.
pub(all) struct DeliveryAttempt {
  attempt : Int
  status_code : Int
  error : String
  duration_ms : Int
} derive(Eq, @debug.Debug)

///|
/// The complete outcome of `DeliveryEngine::deliver`.
pub(all) struct DeliveryOutcome {
  hook_id : String
  event_id : String
  status : DeliveryStatus
  attempts : Array[DeliveryAttempt]
} derive(Eq, @debug.Debug)

///|
/// Drives delivery: looks up the Hook, executes transport attempts, and
/// applies the Hook's retry policy.
pub struct DeliveryEngine {
  registry : HookRegistry
  transport : Transport
}

///|
pub fn DeliveryEngine::new(
  registry : HookRegistry,
  transport : Transport,
) -> DeliveryEngine {
  { registry, transport }
}

///|
/// Delivers synchronously. Retry delays are exposed through `RetryPolicy` for
/// external schedulers; this engine performs the attempts back to back.
pub fn DeliveryEngine::deliver(
  self : DeliveryEngine,
  hook_id : String,
  event : WebhookEvent,
) -> DeliveryOutcome {
  let attempts : Array[DeliveryAttempt] = []
  match self.registry.get(hook_id) {
    None => { hook_id, event_id: event.id, status: Skipped, attempts }
    Some(hook) =>
      if !hook.active {
        { hook_id, event_id: event.id, status: Skipped, attempts }
      } else {
        let max_attempts = hook.max_attempts
        let mut attempt_number = 1
        let mut final_status = DeadLetter
        while attempt_number <= max_attempts {
          let result = (self.transport)(hook, event)
          attempts.push(
            {
              attempt: attempt_number,
              status_code: result.status_code,
              error: result.error,
              duration_ms: result.duration_ms,
            },
          )
          if result.ok {
            final_status = Success
            break
          } else if !result.retryable {
            final_status = DeadLetter
            break
          } else if attempt_number == max_attempts {
            final_status = DeadLetter
            break
          } else {
            final_status = Retry
          }
          attempt_number = attempt_number + 1
        }
        { hook_id, event_id: event.id, status: final_status, attempts }
      }
  }
}
