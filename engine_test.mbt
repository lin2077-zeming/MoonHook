///|
fn test_hook() -> @MoonHook.Hook {
  @MoonHook.Hook::new("orders", "https://example.com/hooks/orders").with_retry_policy(
    Fixed(10),
  )
}

///|
test "delivery succeeds on first attempt" {
  let registry = @MoonHook.HookRegistry::new()
  let hook = test_hook()
  registry.register(hook) |> ignore
  let mock = @MoonHook.MockTransport::new([
    @MoonHook.DeliveryResult::success(12),
  ])
  let engine = @MoonHook.DeliveryEngine::new(registry, mock.as_transport())
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-1")
    .with_event_type("order.created")
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  let outcome = engine.deliver("orders", event)
  @test.assert_eq(outcome.status, Success)
  @test.assert_eq(outcome.attempts.length(), 1)
  @test.assert_eq(outcome.attempts[0].status_code, 200)
}

///|
test "delivery retries then succeeds" {
  let registry = @MoonHook.HookRegistry::new()
  let hook = test_hook().with_max_attempts(3)
  registry.register(hook) |> ignore
  let mock = @MoonHook.MockTransport::new([
    @MoonHook.DeliveryResult::failure(500, "boom", 10, true),
    @MoonHook.DeliveryResult::success(8),
  ])
  let engine = @MoonHook.DeliveryEngine::new(registry, mock.as_transport())
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-2")
    .with_event_type("order.created")
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  let outcome = engine.deliver("orders", event)
  @test.assert_eq(outcome.status, Success)
  @test.assert_eq(outcome.attempts.length(), 2)
  @test.assert_eq(outcome.attempts[0].status_code, 500)
  @test.assert_eq(outcome.attempts[1].status_code, 200)
}

///|
test "delivery dead letters after max attempts" {
  let registry = @MoonHook.HookRegistry::new()
  let hook = test_hook().with_max_attempts(3)
  registry.register(hook) |> ignore
  let mock = @MoonHook.MockTransport::new([
    @MoonHook.DeliveryResult::failure(500, "boom", 10, true),
    @MoonHook.DeliveryResult::failure(500, "boom", 10, true),
    @MoonHook.DeliveryResult::failure(500, "boom", 10, true),
  ])
  let engine = @MoonHook.DeliveryEngine::new(registry, mock.as_transport())
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-3")
    .with_event_type("order.created")
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  let outcome = engine.deliver("orders", event)
  @test.assert_eq(outcome.status, DeadLetter)
  @test.assert_eq(outcome.attempts.length(), 3)
}

///|
test "non retryable failure dead letters immediately" {
  let registry = @MoonHook.HookRegistry::new()
  let hook = test_hook().with_max_attempts(3)
  registry.register(hook) |> ignore
  let mock = @MoonHook.MockTransport::new([
    @MoonHook.DeliveryResult::failure(400, "bad request", 5, false),
  ])
  let engine = @MoonHook.DeliveryEngine::new(registry, mock.as_transport())
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-4")
    .with_event_type("order.created")
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  let outcome = engine.deliver("orders", event)
  @test.assert_eq(outcome.status, DeadLetter)
  @test.assert_eq(outcome.attempts.length(), 1)
}

///|
test "missing and inactive hooks are skipped" {
  let registry = @MoonHook.HookRegistry::new()
  let hook = test_hook().with_active(false)
  registry.register(hook) |> ignore
  let mock = @MoonHook.MockTransport::new([])
  let engine = @MoonHook.DeliveryEngine::new(registry, mock.as_transport())
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-5")
    .with_event_type("order.created")
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  @test.assert_eq(engine.deliver("missing", event).status, Skipped)
  @test.assert_eq(engine.deliver("orders", event).status, Skipped)
}
