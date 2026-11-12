///|
test "classifies retryable and terminal HTTP status codes" {
  assert_true(is_success_status(200))
  assert_true(is_success_status(204))
  assert_false(is_success_status(500))
  assert_true(is_retryable_status(408))
  assert_true(is_retryable_status(429))
  assert_true(is_retryable_status(503))
  assert_false(is_retryable_status(400))
  assert_false(is_retryable_status(404))
}

///|
fn test_event(payload : String) -> @MoonHook.WebhookEvent {
  let built = @MoonHook.EventBuilder::new()
    .with_id("evt-http")
    .with_event_type("order.created")
    .with_subject("order/42")
    .with_timestamp_ms(@env.now().to_int())
    .with_payload(payload)
    .build()
  match built {
    Ok(event) => event
    Err(message) => abort(message)
  }
}

///|
fn test_registry(
  hook_id : String,
  url : String,
  secret : String,
) -> @MoonHook.HookRegistry {
  let registry = @MoonHook.HookRegistry::new()
  let hook = @MoonHook.Hook::new(hook_id, url)
    .with_secret(secret)
    .with_retry_policy(@MoonHook.RetryPolicy::Fixed(10))
    .with_max_attempts(3)
  registry.register(hook) |> ignore
  registry
}

///|
async test "delivers a signed webhook over HTTP end to end" {
  let received : Array[String] = []
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever(
        webhook_receiver("shared-secret", 300_000, payload => {
          received.push(payload)
        }),
      )
    }
    let registry = test_registry(
      "orders",
      "http://127.0.0.1:\{port}/hooks/orders",
      "shared-secret",
    )
    let payload = "{\"total\": 99}"
    let engine = AsyncDeliveryEngine::new(registry, http_transport())
    let outcome = engine.deliver("orders", test_event(payload))
    assert_eq(outcome.status, @MoonHook.DeliveryStatus::Success)
    assert_eq(outcome.attempts.length(), 1)
    assert_eq(outcome.attempts[0].status_code, 200)
    assert_eq(received.length(), 1)
    assert_eq(received[0], payload)
  }
}

///|
async test "retries a server error and succeeds on the second attempt" {
  let requests : Array[Int32] = []
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        requests.push(requests.length() + 1)
        if requests.length() == 1 {
          conn.send_response(500, "Internal Server Error")
        } else {
          conn.send_response(200, "OK")
        }
      })
    }
    let registry = test_registry(
      "orders",
      "http://127.0.0.1:\{port}/hooks/orders",
      "shared-secret",
    )
    let engine = AsyncDeliveryEngine::new(registry, http_transport())
    let outcome = engine.deliver("orders", test_event("{\"total\": 99}"))
    assert_eq(outcome.status, @MoonHook.DeliveryStatus::Success)
    assert_eq(outcome.attempts.length(), 2)
    assert_eq(outcome.attempts[0].status_code, 500)
    assert_eq(outcome.attempts[1].status_code, 200)
  }
}

///|
async test "rejects a request signed with the wrong secret" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever(webhook_receiver("server-secret", 300_000, _ => ()))
    }
    let registry = test_registry(
      "orders",
      "http://127.0.0.1:\{port}/hooks/orders",
      "wrong-secret",
    )
    let engine = AsyncDeliveryEngine::new(registry, http_transport())
    let outcome = engine.deliver("orders", test_event("{\"total\": 99}"))
    assert_eq(outcome.status, @MoonHook.DeliveryStatus::DeadLetter)
    assert_eq(outcome.attempts.length(), 1)
    assert_eq(outcome.attempts[0].status_code, 401)
  }
}

///|
async test "rejects a replayed request outside the timestamp window" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever(
        webhook_receiver("shared-secret", 300_000, _ => {
          abort("replay should not be accepted")
        }),
      )
    }
    let registry = test_registry(
      "orders",
      "http://127.0.0.1:\{port}/hooks/orders",
      "shared-secret",
    )
    let engine = AsyncDeliveryEngine::new(registry, http_transport())
    let stale = @MoonHook.EventBuilder::new()
      .with_id("evt-stale")
      .with_event_type("order.created")
      .with_timestamp_ms(@env.now().to_int() - 600_000)
      .with_payload("{\"total\": 99}")
      .build()
    let event = match stale {
      Ok(event) => event
      Err(message) => abort(message)
    }
    let outcome = engine.deliver("orders", event)
    assert_eq(outcome.status, @MoonHook.DeliveryStatus::DeadLetter)
    assert_eq(outcome.attempts[0].status_code, 401)
  }
}
