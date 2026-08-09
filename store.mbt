///|
/// A queued delivery waiting to be processed by a scheduler.
pub(all) struct PendingDelivery {
  hook_id : String
  event : WebhookEvent
  queued_at_ms : Int
  attempts_used : Int
} derive(Eq, @debug.Debug)

///|
/// A delivery that permanently failed and was moved to the dead letter queue.
pub(all) struct DeadLetterEntry {
  hook_id : String
  event : WebhookEvent
  reason : String
  failed_at_ms : Int
  attempts : Int
} derive(Eq, @debug.Debug)

///|
/// In-memory outbox. Use this as the default in tests and single-process
/// applications; a durable implementation can swap in behind the same shape.
pub struct InMemoryOutbox {
  entries : Array[PendingDelivery]
} derive(@debug.Debug)

///|
pub fn InMemoryOutbox::new() -> InMemoryOutbox {
  { entries: [] }
}

///|
pub fn InMemoryOutbox::enqueue(
  self : InMemoryOutbox,
  hook_id : String,
  event : WebhookEvent,
  now_ms : Int,
) -> Unit {
  self.entries.push({ hook_id, event, queued_at_ms: now_ms, attempts_used: 0 })
}

///|
/// Returns every pending delivery in FIFO order and empties the outbox.
pub fn InMemoryOutbox::take_all(
  self : InMemoryOutbox,
) -> Array[PendingDelivery] {
  let result = self.entries.copy()
  while !self.entries.is_empty() {
    self.entries.pop() |> ignore
  }
  result
}

///|
pub fn InMemoryOutbox::length(self : InMemoryOutbox) -> Int {
  self.entries.length()
}

///|
pub fn InMemoryOutbox::is_empty(self : InMemoryOutbox) -> Bool {
  self.entries.is_empty()
}

///|
pub struct InMemoryDeadLetter {
  entries : Array[DeadLetterEntry]
} derive(@debug.Debug)

///|
pub fn InMemoryDeadLetter::new() -> InMemoryDeadLetter {
  { entries: [] }
}

///|
pub fn InMemoryDeadLetter::push(
  self : InMemoryDeadLetter,
  entry : DeadLetterEntry,
) -> Unit {
  self.entries.push(entry)
}

///|
pub fn InMemoryDeadLetter::list(
  self : InMemoryDeadLetter,
) -> Array[DeadLetterEntry] {
  self.entries.copy()
}

///|
pub fn InMemoryDeadLetter::length(self : InMemoryDeadLetter) -> Int {
  self.entries.length()
}

///|
pub fn InMemoryDeadLetter::clear(self : InMemoryDeadLetter) -> Unit {
  while !self.entries.is_empty() {
    self.entries.pop() |> ignore
  }
}
