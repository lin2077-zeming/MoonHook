///|
fn audit_entry(id : String, status : String) -> @MoonHook.AuditEntry {
  {
    timestamp_ms: 1000,
    hook_id: "orders",
    event_id: id,
    attempt: 1,
    status,
    error: "",
    duration_ms: 5,
  }
}

///|
test "audit log records and lists entries" {
  let log = @MoonHook.AuditLog::new()
  log.record(audit_entry("evt-1", "success"))
  log.record(audit_entry("evt-2", "dead_letter"))
  @test.assert_eq(log.length(), 2)
  @test.assert_eq(log.list()[1].status, "dead_letter")
}

///|
test "audit log recent returns newest entries" {
  let log = @MoonHook.AuditLog::new()
  for i in 0..<5 {
    log.record(audit_entry("evt-\{i}", "success"))
  }
  let recent = log.recent(2)
  @test.assert_eq(recent.length(), 2)
  @test.assert_eq(recent[0].event_id, "evt-3")
  @test.assert_eq(recent[1].event_id, "evt-4")
  @test.assert_eq(log.recent(0).length(), 0)
}
