///|
test "fixed policy keeps a constant delay" {
  let policy : @MoonHook.RetryPolicy = Fixed(100)
  @test.assert_eq(policy.next_delay_ms(1), 100)
  @test.assert_eq(policy.next_delay_ms(3), 100)
  @test.assert_eq(policy.next_delay_ms(0), 0)
}

///|
test "exponential policy grows and caps" {
  let policy : @MoonHook.RetryPolicy = Exponential(100, 2.0, 1000)
  @test.assert_eq(policy.next_delay_ms(1), 100)
  @test.assert_eq(policy.next_delay_ms(2), 200)
  @test.assert_eq(policy.next_delay_ms(3), 400)
  @test.assert_eq(policy.next_delay_ms(4), 800)
  @test.assert_eq(policy.next_delay_ms(5), 1000)
}

///|
test "none policy never retries" {
  let policy : @MoonHook.RetryPolicy = None
  @test.assert_eq(policy.next_delay_ms(1), 0)
  @test.assert_eq(policy.should_retry(1, 5), false)
}

///|
test "should_retry respects max attempts" {
  let policy : @MoonHook.RetryPolicy = Fixed(50)
  @test.assert_eq(policy.should_retry(1, 3), true)
  @test.assert_eq(policy.should_retry(2, 3), true)
  @test.assert_eq(policy.should_retry(3, 3), false)
}

///|
test "policy descriptions" {
  let none : @MoonHook.RetryPolicy = None
  let fixed : @MoonHook.RetryPolicy = Fixed(200)
  let exp : @MoonHook.RetryPolicy = Exponential(100, 2.0, 1000)
  @test.assert_eq(none.describe(), "none")
  @test.assert_eq(fixed.describe(), "fixed(200ms)")
  @test.assert_eq(exp.describe(), "exponential(100ms x2, max 1000ms)")
}

///|
test "policy validation accepts valid configurations" {
  let none : @MoonHook.RetryPolicy = None
  let fixed : @MoonHook.RetryPolicy = Fixed(0)
  let exp : @MoonHook.RetryPolicy = Exponential(100, 2.0, 1000)
  @test.assert_eq(none.validate(), Ok(()))
  @test.assert_eq(fixed.validate(), Ok(()))
  @test.assert_eq(exp.validate(), Ok(()))
}

///|
test "policy validation rejects invalid configurations" {
  let negative_fixed : @MoonHook.RetryPolicy = Fixed(-1)
  guard negative_fixed.validate() is Err(message) else { fail("expected Err") }
  @test.assert_eq(message, "retry delay must be non-negative")

  let zero_initial : @MoonHook.RetryPolicy = Exponential(0, 2.0, 1000)
  guard zero_initial.validate() is Err(message) else { fail("expected Err") }
  @test.assert_eq(message, "initial retry delay must be positive")

  let shrinking : @MoonHook.RetryPolicy = Exponential(100, 0.5, 1000)
  guard shrinking.validate() is Err(message) else { fail("expected Err") }
  @test.assert_eq(message, "retry multiplier must be at least 1")

  let bad_max : @MoonHook.RetryPolicy = Exponential(100, 2.0, 50)
  guard bad_max.validate() is Err(message) else { fail("expected Err") }
  @test.assert_eq(message, "max retry delay must be at least the initial delay")
}

///|
test "negative fixed delay is clamped for direct use" {
  let policy : @MoonHook.RetryPolicy = Fixed(-1)
  @test.assert_eq(policy.next_delay_ms(1), 0)
  @test.assert_eq(policy.next_delay_ms(0), 0)
}
