///|
/// Tracks when an idempotency key was first seen and when it expires.
pub(all) struct IdempotencyRecord {
  event_id : String
  first_seen_ms : Int
  expires_at_ms : Int
} derive(Eq, @debug.Debug)

///|
/// In-memory idempotency store. Keys are derived from event identity by the
/// caller, typically through a SHA-256 digest of the event id and type.
pub struct IdempotencyStore {
  records : @map.HashMap[String, IdempotencyRecord]
} derive(@debug.Debug)

///|
pub fn IdempotencyStore::new() -> IdempotencyStore {
  { records: @map.HashMap([]) }
}

///|
/// Returns true when `key` has not been seen inside the TTL window, and records
/// it in that case. Returns false for duplicate keys inside the window.
pub fn IdempotencyStore::check_and_mark(
  self : IdempotencyStore,
  key : String,
  event_id : String,
  now_ms : Int,
  ttl_ms : Int,
) -> Bool {
  let ttl = if ttl_ms < 0 { 0 } else { ttl_ms }
  let expires_at = now_ms + ttl
  match self.records.get(key) {
    Some(record) =>
      if record.expires_at_ms < now_ms {
        self.records.set(key, {
          event_id,
          first_seen_ms: now_ms,
          expires_at_ms: expires_at,
        })
        true
      } else {
        false
      }
    None => {
      self.records.set(key, {
        event_id,
        first_seen_ms: now_ms,
        expires_at_ms: expires_at,
      })
      true
    }
  }
}

///|
pub fn IdempotencyStore::get(
  self : IdempotencyStore,
  key : String,
) -> IdempotencyRecord? {
  self.records.get(key)
}

///|
pub fn IdempotencyStore::length(self : IdempotencyStore) -> Int {
  self.records.length()
}

///|
/// Removes records whose TTL has passed. Call this from the scheduler before
/// processing a batch so the table does not grow without bound.
pub fn IdempotencyStore::clear_expired(
  self : IdempotencyStore,
  now_ms : Int,
) -> Unit {
  let expired : Array[String] = []
  for item in self.records.iter() {
    if item.1.expires_at_ms < now_ms {
      expired.push(item.0)
    }
  }
  for key in expired {
    self.records.remove(key)
  }
}
