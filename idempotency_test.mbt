///|
test "idempotency key is accepted once then rejected inside TTL" {
  let store = @MoonHook.IdempotencyStore::new()
  @test.assert_eq(store.check_and_mark("key-1", "evt-1", 1000, 10_000), true)
  @test.assert_eq(store.check_and_mark("key-1", "evt-2", 2000, 10_000), false)
  @test.assert_eq(store.length(), 1)
  let record = store.get("key-1")
  guard record is Some(record) else {
    fail("expected record")
  }
  @test.assert_eq(record.event_id, "evt-1")
  @test.assert_eq(record.expires_at_ms, 11_000)
}

///|
test "expired idempotency key can be reused" {
  let store = @MoonHook.IdempotencyStore::new()
  @test.assert_eq(store.check_and_mark("key-2", "evt-1", 1000, 100), true)
  @test.assert_eq(store.check_and_mark("key-2", "evt-1", 1100, 100), false)
  @test.assert_eq(store.check_and_mark("key-2", "evt-3", 1101, 100), true)
  @test.assert_eq(store.get("key-2").map(record => record.event_id), Some("evt-3"))
}

///|
test "clear expired removes stale keys" {
  let store = @MoonHook.IdempotencyStore::new()
  store.check_and_mark("old", "evt-1", 1000, 100) |> ignore
  store.check_and_mark("new", "evt-2", 1000, 10_000) |> ignore
  store.clear_expired(1101)
  @test.assert_eq(store.length(), 1)
  @test.assert_eq(store.get("old"), None)
  @test.assert_eq(store.get("new") is Some(_), true)
}
