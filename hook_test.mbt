///|
test "hook defaults" {
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders")
  @test.assert_eq(hook.id, "orders")
  @test.assert_eq(hook.url, "https://example.com/hooks/orders")
  @test.assert_eq(hook.secret, "")
  @test.assert_eq(hook.active, true)
  @test.assert_eq(hook.max_attempts, 3)
  @test.assert_eq(hook.timeout_ms, 5000)
  @test.assert_eq(hook.retry_policy, Fixed(100))
}

///|
test "hook builder updates fields" {
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders")
    .with_secret("s3cret")
    .with_header("X-Team", "payments")
    .with_header("X-Team", "billing")
    .with_active(false)
    .with_max_attempts(5)
    .with_retry_policy(Exponential(200, 2.0, 5000))
    .with_timeout_ms(1500)
  @test.assert_eq(hook.secret, "s3cret")
  @test.assert_eq(hook.active, false)
  @test.assert_eq(hook.max_attempts, 5)
  @test.assert_eq(hook.timeout_ms, 1500)
  @test.assert_eq(hook.retry_policy, Exponential(200, 2.0, 5000))
  @test.assert_eq(hook.header_value("X-Team"), Some("billing"))
  @test.assert_eq(hook.header_value("X-Missing"), None)
}

///|
test "hook validation" {
  let missing_id = @MoonHook.Hook::new("", "https://example.com")
  guard missing_id.validate() is Err(message) else {
    fail("expected Err")
  }
  @test.assert_eq(message, "hook id is required")

  let missing_url = @MoonHook.Hook::new("orders", "")
  guard missing_url.validate() is Err(message) else {
    fail("expected Err")
  }
  @test.assert_eq(message, "hook url is required")

  let bad_attempts = @MoonHook.Hook::new("orders", "https://example.com")
    .with_max_attempts(0)
  guard bad_attempts.validate() is Err(message) else {
    fail("expected Err")
  }
  @test.assert_eq(message, "max attempts must be at least 1")

  let valid = @MoonHook.Hook::new("orders", "https://example.com")
  @test.assert_eq(valid.validate(), Ok(()))
}
