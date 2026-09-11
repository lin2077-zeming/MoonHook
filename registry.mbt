///|
/// An in-memory registry of registered webhook destinations.
pub struct HookRegistry {
  hooks : @map.HashMap[String, Hook]
} derive(@debug.Debug)

///|
pub fn HookRegistry::new() -> HookRegistry {
  { hooks: @map.HashMap([]), }
}

///|
/// Registers a validated Hook. Duplicate ids are rejected.
pub fn HookRegistry::register(
  self : HookRegistry,
  hook : Hook,
) -> Result[Unit, String] {
  let validation = hook.validate()
  match validation {
    Err(message) => Err(message)
    Ok(_) =>
      if self.hooks.contains(hook.id) {
        Err("hook already registered: " + hook.id)
      } else {
        self.hooks.set(hook.id, hook)
        Ok(())
      }
  }
}

///|
pub fn HookRegistry::unregister(self : HookRegistry, id : String) -> Unit {
  self.hooks.remove(id)
}

///|
pub fn HookRegistry::get(self : HookRegistry, id : String) -> Hook? {
  self.hooks.get(id)
}

///|
pub fn HookRegistry::list(self : HookRegistry) -> Array[Hook] {
  self.hooks.values().to_array()
}

///|
pub fn HookRegistry::count(self : HookRegistry) -> Int {
  self.hooks.length()
}

///|
pub fn HookRegistry::contains(self : HookRegistry, id : String) -> Bool {
  self.hooks.contains(id)
}
