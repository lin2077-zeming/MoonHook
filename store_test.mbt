///|
fn test_event() -> @MoonHook.WebhookEvent {
  let result = @MoonHook.EventBuilder::new()
    .with_id("evt-store")
    .with_event_type("order.created")
    .build()
  match result {
    Ok(event) => event
    Err(_) => abort("bad event")
  }
}

///|
test "outbox enqueues and drains in FIFO order" {
  let outbox = @MoonHook.InMemoryOutbox::new()
  outbox.enqueue("orders", test_event(), 100)
  outbox.enqueue("invoices", test_event(), 200)
  @test.assert_eq(outbox.length(), 2)
  let drained = outbox.take_all()
  @test.assert_eq(drained.length(), 2)
  @test.assert_eq(drained[0].hook_id, "orders")
  @test.assert_eq(drained[0].queued_at_ms, 100)
  @test.assert_eq(drained[1].hook_id, "invoices")
  @test.assert_eq(outbox.is_empty(), true)
}

///|
test "dead letter stores failed deliveries" {
  let dead = @MoonHook.InMemoryDeadLetter::new()
  let event = test_event()
  dead.push({
    hook_id: "orders",
    event,
    reason: "max attempts exceeded",
    failed_at_ms: 300,
    attempts: 3,
  })
  @test.assert_eq(dead.length(), 1)
  let listed = dead.list()
  @test.assert_eq(listed[0].reason, "max attempts exceeded")
  @test.assert_eq(listed[0].attempts, 3)
  dead.clear()
  @test.assert_eq(dead.length(), 0)
}
