///|
test "registry registers and fetches a hook" {
  let registry = @MoonHook.HookRegistry::new()
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders")
  @test.assert_eq(registry.register(hook), Ok(()))
  @test.assert_eq(registry.count(), 1)
  @test.assert_eq(registry.contains("orders"), true)
  @test.assert_eq(registry.get("orders"), Some(hook))
}

///|
test "registry rejects duplicates" {
  let registry = @MoonHook.HookRegistry::new()
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders")
  registry.register(hook) |> ignore
  guard registry.register(hook) is Err(message) else { fail("expected Err") }
  @test.assert_eq(message, "hook already registered: orders")
}

///|
test "registry rejects invalid hooks" {
  let registry = @MoonHook.HookRegistry::new()
  let hook = @MoonHook.Hook::new("", "https://example.com")
  guard registry.register(hook) is Err(message) else { fail("expected Err") }
  @test.assert_eq(message, "hook id is required")
  @test.assert_eq(registry.count(), 0)
}

///|
test "registry lists and unregisters hooks" {
  let registry = @MoonHook.HookRegistry::new()
  let first = @MoonHook.Hook::new("a", "https://example.com/a")
  let second = @MoonHook.Hook::new("b", "https://example.com/b")
  registry.register(first) |> ignore
  registry.register(second) |> ignore
  @test.assert_eq(registry.list().length(), 2)
  registry.unregister("a")
  @test.assert_eq(registry.count(), 1)
  @test.assert_eq(registry.get("a"), None)
}
