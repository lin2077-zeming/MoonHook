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
