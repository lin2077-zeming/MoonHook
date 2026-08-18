///|
fn coordinator_event() -> @MoonHook.WebhookEvent {
  let result = @MoonHook.EventBuilder::new()
    .with_id("evt-queue-1")
    .with_event_type("order.created")
    .build()
  match result {
    Ok(event) => event
    Err(_) => abort("bad event")
  }
}

///|
test "coordinator enqueues and drains successfully" {
  let transport : @MoonHook.Transport = fn(_hook, _event) {
    @MoonHook.DeliveryResult::success(3)
  }
  let moonhook = @MoonHook.MoonHook::new(transport)
  moonhook.register(
    @MoonHook.Hook::new("orders", "https://example.com/hooks/orders"),
  )
  |> ignore
  @test.assert_eq(moonhook.enqueue("orders", coordinator_event(), 1000), Ok(()))
  @test.assert_eq(moonhook.outbox_length(), 1)
  @test.assert_eq(moonhook.drain(2000), 1)
  @test.assert_eq(moonhook.outbox_length(), 0)
  @test.assert_eq(moonhook.dead_letter_length(), 0)
  @test.assert_eq(moonhook.audit_entries().length(), 1)
}

///|
test "coordinator moves failed deliveries to dead letter" {
  let transport : @MoonHook.Transport = fn(_hook, _event) {
    @MoonHook.DeliveryResult::failure(500, "boom", 5, true)
  }
  let moonhook = @MoonHook.MoonHook::new(transport)
  moonhook.register(
    @MoonHook.Hook::new("orders", "https://example.com/hooks/orders"),
  )
  |> ignore
  let outcome = moonhook.deliver_now("orders", coordinator_event(), 1000)
  @test.assert_eq(outcome.status, DeadLetter)
  @test.assert_eq(moonhook.dead_letter_length(), 1)
  @test.assert_eq(moonhook.dead_letters()[0].reason, "delivery failed")
  @test.assert_eq(moonhook.audit_entries().length(), 3)
}

///|
test "coordinator rejects duplicate idempotency key" {
  let transport : @MoonHook.Transport = fn(_hook, _event) {
    @MoonHook.DeliveryResult::success(3)
  }
  let moonhook = @MoonHook.MoonHook::new(transport)
  moonhook.register(
    @MoonHook.Hook::new("orders", "https://example.com/hooks/orders"),
  )
  |> ignore
  let event = coordinator_event()
  @test.assert_eq(moonhook.enqueue("orders", event, 1000), Ok(()))
  guard moonhook.enqueue("orders", event, 1001) is Err(message) else {
    fail("expected Err")
  }
  @test.assert_eq(
    message, "duplicate idempotency key: evt-queue-1:order.created",
  )
  @test.assert_eq(moonhook.outbox_length(), 1)
}
