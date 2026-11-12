///|
/// High-level facade that ties registration, enqueueing, delivery, dead
/// letters, idempotency, and audit logging into one object.
pub struct MoonHook {
  registry : HookRegistry
  outbox : InMemoryOutbox
  dead_letter : InMemoryDeadLetter
  idempotency : IdempotencyStore
  audit : AuditLog
  engine : DeliveryEngine
  idempotency_ttl_ms : Int32
}

///|
pub fn MoonHook::new(transport : Transport) -> MoonHook {
  let registry = HookRegistry::new()
  let engine = DeliveryEngine::new(registry, transport)
  {
    registry,
    outbox: InMemoryOutbox::new(),
    dead_letter: InMemoryDeadLetter::new(),
    idempotency: IdempotencyStore::new(),
    audit: AuditLog::new(),
    engine,
    idempotency_ttl_ms: 60_000,
  }
}

///|
pub fn MoonHook::with_idempotency_ttl_ms(
  self : MoonHook,
  idempotency_ttl_ms : Int32,
) -> MoonHook {
  {
    registry: self.registry,
    outbox: self.outbox,
    dead_letter: self.dead_letter,
    idempotency: self.idempotency,
    audit: self.audit,
    engine: self.engine,
    idempotency_ttl_ms,
  }
}

///|
pub fn MoonHook::register(self : MoonHook, hook : Hook) -> Result[Unit, String] {
  self.registry.register(hook)
}

///|
pub fn MoonHook::hook_count(self : MoonHook) -> Int32 {
  self.registry.count()
}

///|
pub fn MoonHook::outbox_length(self : MoonHook) -> Int32 {
  self.outbox.length()
}

///|
pub fn MoonHook::dead_letter_length(self : MoonHook) -> Int32 {
  self.dead_letter.length()
}

///|
pub fn MoonHook::dead_letters(self : MoonHook) -> Array[DeadLetterEntry] {
  self.dead_letter.list()
}

///|
pub fn MoonHook::audit_entries(self : MoonHook) -> Array[AuditEntry] {
  self.audit.list()
}

///|
/// Enqueues an event into the outbox after checking hook state and the
/// idempotency window. Returns `Err` for unknown/inactive hooks and duplicates.
pub fn MoonHook::enqueue(
  self : MoonHook,
  hook_id : String,
  event : WebhookEvent,
  now_ms : Int32,
) -> Result[Unit, String] {
  match self.registry.get(hook_id) {
    None => Err("hook not found: " + hook_id)
    Some(hook) =>
      if !hook.active {
        Err("hook is inactive: " + hook_id)
      } else if !self.idempotency.check_and_mark(
          event.idempotency_key,
          event.id,
          now_ms,
          self.idempotency_ttl_ms,
        ) {
        Err("duplicate idempotency key: " + event.idempotency_key)
      } else {
        self.outbox.enqueue(hook_id, event, now_ms)
        Ok(())
      }
  }
}

///|
/// Delivers immediately, records audit entries, and moves permanent failures
/// into the dead letter queue.
pub fn MoonHook::deliver_now(
  self : MoonHook,
  hook_id : String,
  event : WebhookEvent,
  now_ms : Int32,
) -> DeliveryOutcome {
  let outcome = self.engine.deliver(hook_id, event)
  self.record_audit(outcome, now_ms)
  if outcome.status == DeadLetter {
    self.dead_letter.push({
      hook_id,
      event,
      reason: "delivery failed",
      failed_at_ms: now_ms,
      attempts: outcome.attempts.length(),
    })
  }
  outcome
}

///|
/// Drains the outbox through the delivery engine and returns the number of
/// deliveries attempted. Skipped or failed deliveries land in the dead letter
/// queue.
pub fn MoonHook::drain(self : MoonHook, now_ms : Int32) -> Int32 {
  let pending = self.outbox.take_all()
  let mut delivered = 0
  for item in pending {
    match self.registry.get(item.hook_id) {
      None =>
        self.dead_letter.push({
          hook_id: item.hook_id,
          event: item.event,
          reason: "hook not found",
          failed_at_ms: now_ms,
          attempts: item.attempts_used,
        })
      Some(hook) =>
        if !hook.active {
          self.dead_letter.push({
            hook_id: item.hook_id,
            event: item.event,
            reason: "hook is inactive",
            failed_at_ms: now_ms,
            attempts: item.attempts_used,
          })
        } else {
          let outcome = self.engine.deliver(item.hook_id, item.event)
          self.record_audit(outcome, now_ms)
          if outcome.status == DeadLetter {
            self.dead_letter.push({
              hook_id: item.hook_id,
              event: item.event,
              reason: "delivery failed",
              failed_at_ms: now_ms,
              attempts: outcome.attempts.length(),
            })
          }
          delivered = delivered + 1
        }
    }
  }
  delivered
}

///|
fn MoonHook::record_audit(
  self : MoonHook,
  outcome : DeliveryOutcome,
  now_ms : Int32,
) -> Unit {
  for attempt in outcome.attempts {
    self.audit.record({
      timestamp_ms: now_ms,
      hook_id: outcome.hook_id,
      event_id: outcome.event_id,
      attempt: attempt.attempt,
      status: outcome.status.describe(),
      error: attempt.error,
      duration_ms: attempt.duration_ms,
    })
  }
}
