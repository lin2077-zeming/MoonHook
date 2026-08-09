///|
test "event builder creates a valid event" {
  let result = @MoonHook.EventBuilder::new()
    .with_id("evt-1")
    .with_event_type("order.created")
    .with_subject("order/42")
    .with_payload("{\"total\": 99}")
    .with_timestamp_ms(1700000000)
    .build()
  guard result is Ok(event) else {
    fail("expected Ok(event)")
  }
  @test.assert_eq(event.id, "evt-1")
  @test.assert_eq(event.event_type, "order.created")
  @test.assert_eq(event.subject, "order/42")
  @test.assert_eq(event.payload, "{\"total\": 99}")
  @test.assert_eq(event.idempotency_key, "evt-1:order.created")
}

///|
test "event builder rejects missing id" {
  let result = @MoonHook.EventBuilder::new()
    .with_event_type("order.created")
    .build()
  guard result is Err(message) else {
    fail("expected Err")
  }
  @test.assert_eq(message, "event id is required")
}

///|
test "event builder rejects missing event type" {
  let result = @MoonHook.EventBuilder::new().with_id("evt-1").build()
  guard result is Err(message) else {
    fail("expected Err")
  }
  @test.assert_eq(message, "event type is required")
}

///|
test "explicit idempotency key wins over default" {
  let result = @MoonHook.EventBuilder::new()
    .with_id("evt-2")
    .with_event_type("invoice.paid")
    .with_idempotency_key("invoice-42")
    .build()
  guard result is Ok(event) else {
    fail("expected Ok(event)")
  }
  @test.assert_eq(event.idempotency_key, "invoice-42")
}
