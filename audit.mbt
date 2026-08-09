///|
/// One auditable delivery attempt.
pub(all) struct AuditEntry {
  timestamp_ms : Int
  hook_id : String
  event_id : String
  attempt : Int
  status : String
  error : String
  duration_ms : Int
} derive(Eq, @debug.Debug)

///|
/// In-memory audit trail with a bounded recent-view helper.
pub struct AuditLog {
  entries : Array[AuditEntry]
} derive(@debug.Debug)

///|
pub fn AuditLog::new() -> AuditLog {
  { entries: [] }
}

///|
pub fn AuditLog::record(self : AuditLog, entry : AuditEntry) -> Unit {
  self.entries.push(entry)
}

///|
pub fn AuditLog::list(self : AuditLog) -> Array[AuditEntry] {
  self.entries.copy()
}

///|
pub fn AuditLog::length(self : AuditLog) -> Int {
  self.entries.length()
}

///|
/// Returns the most recent `n` entries, or all entries when fewer exist.
pub fn AuditLog::recent(self : AuditLog, n : Int) -> Array[AuditEntry] {
  if n <= 0 {
    []
  } else {
    let total = self.entries.length()
    let start = if total > n { total - n } else { 0 }
    let result : Array[AuditEntry] = []
    for i in start..<total {
      result.push(self.entries[i])
    }
    result
  }
}
