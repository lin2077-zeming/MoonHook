///|
test "signed request contains signature and metadata headers" {
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders")
    .with_secret("demo-secret")
    .with_header("X-Team", "payments")
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-1")
    .with_event_type("order.created")
    .with_subject("order/42")
    .with_payload("{\"total\": 99}")
    .with_timestamp_ms(1700000000)
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  let request = @MoonHook.build_signed_request(hook, event)
  @test.assert_eq(request.http_method, "POST")
  @test.assert_eq(request.url, "https://example.com/hooks/orders")
  @test.assert_eq(request.body, "{\"total\": 99}")
  @test.assert_eq(
    request.signature,
    @MoonHook.sign_webhook("demo-secret", 1700000000, "{\"total\": 99}"),
  )
  @test.assert_eq(
    @MoonHook.find_header(request.headers, "X-MoonHook-Signature"),
    Some(request.signature),
  )
  @test.assert_eq(
    @MoonHook.find_header(request.headers, "X-MoonHook-Event-Type"),
    Some("order.created"),
  )
  @test.assert_eq(
    @MoonHook.find_header(request.headers, "X-Team"),
    Some("payments"),
  )
}

///|
test "verify webhook request accepts valid and rejects tampered body" {
  let secret = "demo-secret"
  let body = "{\"total\": 99}"
  let headers = [
    ("X-MoonHook-Signature", @MoonHook.sign_hmac_sha256(secret, body)),
  ]
  @test.assert_eq(@MoonHook.verify_webhook_request(secret, headers, body), true)
  @test.assert_eq(
    @MoonHook.verify_webhook_request(secret, headers, "{\"total\": 100}"),
    false,
  )
  @test.assert_eq(@MoonHook.verify_webhook_request(secret, [], body), false)
}

///|
test "verify signed request" {
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders").with_secret(
    "demo-secret",
  )
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
  let request = @MoonHook.build_signed_request(hook, event)
  @test.assert_eq(@MoonHook.verify_signed_request("demo-secret", request), true)
  let tampered : @MoonHook.SignedRequest = {
    http_method: request.http_method,
    url: request.url,
    headers: request.headers,
    body: "{\"total\": 100}",
    signature: request.signature,
  }
  @test.assert_eq(
    @MoonHook.verify_signed_request("demo-secret", tampered),
    false,
  )
}

///|
test "find_header matches names case insensitively" {
  let headers = [("X-MoonHook-Signature", "abc"), ("x-team", "payments")]
  @test.assert_eq(
    @MoonHook.find_header(headers, "x-moonhook-signature"),
    Some("abc"),
  )
  @test.assert_eq(@MoonHook.find_header(headers, "X-Team"), Some("payments"))
}

///|
test "verify webhook request accepts sha256 prefix" {
  let secret = "demo-secret"
  let body = "{\"total\": 99}"
  let signature = @MoonHook.sign_hmac_sha256(secret, body)
  let headers = [("x-moonhook-signature", "sha256=" + signature)]
  @test.assert_eq(@MoonHook.verify_webhook_request(secret, headers, body), true)
  @test.assert_eq(
    @MoonHook.verify_webhook_request(secret, headers, "{\"total\": 100}"),
    false,
  )
}

///|
test "timestamped webhook signature verifies inside tolerance" {
  let secret = "demo-secret"
  let body = "{\"total\": 99}"
  let signature = @MoonHook.sign_webhook(secret, 1000, body)
  @test.assert_eq(
    @MoonHook.verify_webhook(secret, 1000, body, signature, 1000, 60_000),
    true,
  )
  @test.assert_eq(
    @MoonHook.verify_webhook(
      secret,
      1000,
      body,
      signature,
      1000 + 30_000,
      60_000,
    ),
    true,
  )
  @test.assert_eq(
    @MoonHook.verify_webhook(secret, 1000, body, signature, 2000, 500),
    false,
  )
  @test.assert_eq(
    @MoonHook.verify_webhook(secret, 1000, body, signature, 1000, -1),
    true,
  )
}

///|
test "verify webhook request with timestamp rejects replay" {
  let secret = "demo-secret"
  let body = "{\"total\": 99}"
  let event = @MoonHook.EventBuilder::new()
    .with_id("evt-ts")
    .with_event_type("order.created")
    .with_payload(body)
    .with_timestamp_ms(1700000000)
    .build()
    |> result => {
      match result {
        Ok(event) => event
        Err(_) => abort("bad event")
      }
    }
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders").with_secret(
    secret,
  )
  let request = @MoonHook.build_signed_request(hook, event)
  @test.assert_eq(
    @MoonHook.verify_webhook_request_with_timestamp(
      secret,
      request.headers,
      request.body,
      1700000000,
      60_000,
    ),
    true,
  )
  @test.assert_eq(
    @MoonHook.verify_webhook_request_with_timestamp(
      secret,
      request.headers,
      request.body,
      1700000000 + 120_000,
      60_000,
    ),
    false,
  )
  @test.assert_eq(
    @MoonHook.verify_webhook_request_with_timestamp(
      "other-secret",
      request.headers,
      request.body,
      1700000000,
      60_000,
    ),
    false,
  )
}
