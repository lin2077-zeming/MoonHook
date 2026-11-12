///|
/// One auditable delivery attempt.
#derive(Eq, @debug.Debug)
pub(all) struct AuditEntry {
  timestamp_ms : Int32
  hook_id : String
  event_id : String
  attempt : Int32
  status : String
  error : String
  duration_ms : Int32
}

///|
/// In-memory audit trail with a bounded recent-view helper.
#derive(@debug.Debug)
pub struct AuditLog {
  entries : Array[AuditEntry]
}

///|
pub fn AuditLog::new() -> AuditLog {
  { entries: [], }
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
pub fn AuditLog::length(self : AuditLog) -> Int32 {
  self.entries.length()
}

///|
/// Returns the most recent `n` entries, or all entries when fewer exist.
pub fn AuditLog::recent(self : AuditLog, n : Int32) -> Array[AuditEntry] {
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
