///|
test "event json round trip" {
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-json-1")
    .with_event_type("order.created")
    .with_subject("order/42")
    .with_payload("{\"total\": 99}")
    .with_timestamp_ms(1700000000)
    .with_idempotency_key("order-42")
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  let encoded = @MoonHook.event_to_json_string(event)
  let decoded = @MoonHook.event_from_json_string(encoded)
  guard decoded is Ok(decoded) else { fail("expected Ok") }
  @test.assert_eq(decoded, event)
}

///|
test "event json defaults optional fields" {
  let input = "{\"id\":\"evt-2\",\"event_type\":\"invoice.paid\",\"payload\":\"{}\",\"timestamp_ms\":1700000000}"
  let decoded = @MoonHook.event_from_json_string(input)
  guard decoded is Ok(decoded) else { fail("expected Ok") }
  @test.assert_eq(decoded.subject, "")
  @test.assert_eq(decoded.idempotency_key, "evt-2:invoice.paid")
}

///|
test "event json rejects invalid input" {
  guard @MoonHook.event_from_json_string("not json") is Err(_) else {
    fail("expected Err")
  }
  guard @MoonHook.event_from_json_string("[1,2,3]") is Err(_) else {
    fail("expected Err")
  }
  guard @MoonHook.event_from_json_string("{}") is Err(_) else {
    fail("expected Err")
  }
}

///|
test "hook json round trip" {
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders")
    .with_secret("demo-secret")
    .with_header("X-Team", "payments")
    .with_header("content-type", "application/json")
    .with_max_attempts(5)
    .with_timeout_ms(1500)
    .with_retry_policy(Exponential(200, 2.0, 5000))
  let encoded = @MoonHook.hook_to_json_string(hook)
  let decoded = @MoonHook.hook_from_json_string(encoded)
  guard decoded is Ok(decoded) else { fail("expected Ok") }
  @test.assert_eq(decoded, hook)
}

///|
test "hook json defaults optional fields" {
  let input = "{\"id\":\"orders\",\"url\":\"https://example.com/hooks/orders\",\"secret\":\"\",\"headers\":[],\"active\":true,\"max_attempts\":3,\"timeout_ms\":5000}"
  let decoded = @MoonHook.hook_from_json_string(input)
  guard decoded is Ok(decoded) else { fail("expected Ok") }
  @test.assert_eq(decoded.headers.length(), 0)
  @test.assert_eq(decoded.retry_policy, Fixed(100))
}

///|
test "hook json rejects invalid input" {
  guard @MoonHook.hook_from_json_string("not json") is Err(_) else {
    fail("expected Err")
  }
  guard @MoonHook.hook_from_json_string("{}") is Err(_) else {
    fail("expected Err")
  }
}

///|
test "pending delivery json round trip" {
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-pending")
    .with_event_type("order.created")
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  let item : @MoonHook.PendingDelivery = {
    hook_id: "orders",
    event,
    queued_at_ms: 100,
    attempts_used: 1,
  }
  let encoded = @MoonHook.pending_delivery_to_json_string(item)
  let decoded = @MoonHook.pending_delivery_from_json_string(encoded)
  guard decoded is Ok(decoded) else { fail("expected Ok") }
  @test.assert_eq(decoded, item)
}

///|
test "dead letter json round trip" {
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-dead")
    .with_event_type("order.created")
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  let entry : @MoonHook.DeadLetterEntry = {
    hook_id: "orders",
    event,
    reason: "max attempts exceeded",
    failed_at_ms: 300,
    attempts: 3,
  }
  let encoded = @MoonHook.dead_letter_to_json_string(entry)
  let decoded = @MoonHook.dead_letter_from_json_string(encoded)
  guard decoded is Ok(decoded) else { fail("expected Ok") }
  @test.assert_eq(decoded, entry)
}

///|
test "pending and dead letter json reject invalid input" {
  guard @MoonHook.pending_delivery_from_json_string("{}") is Err(_) else {
    fail("expected Err")
  }
  guard @MoonHook.dead_letter_from_json_string("[]") is Err(_) else {
    fail("expected Err")
  }
}
