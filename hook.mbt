///|
/// A Hook describes one webhook destination and its delivery policy.
pub(all) struct Hook {
  id : String
  url : String
  secret : String
  headers : Array[(String, String)]
  active : Bool
  max_attempts : Int
  retry_policy : RetryPolicy
  timeout_ms : Int
} derive(Eq, @debug.Debug)

///|
/// Creates a Hook with safe defaults: active, three attempts, fixed 100ms
/// retry delay, and a 5 second timeout.
pub fn Hook::new(id : String, url : String) -> Hook {
  {
    id,
    url,
    secret: "",
    headers: [],
    active: true,
    max_attempts: 3,
    retry_policy: Fixed(100),
    timeout_ms: 5000,
  }
}

///|
pub fn Hook::with_secret(self : Hook, secret : String) -> Hook {
  {
    id: self.id,
    url: self.url,
    secret,
    headers: self.headers,
    active: self.active,
    max_attempts: self.max_attempts,
    retry_policy: self.retry_policy,
    timeout_ms: self.timeout_ms,
  }
}

///|
pub fn Hook::with_header(
  self : Hook,
  name : String,
  value : String,
) -> Hook {
  let headers = self.headers.copy()
  headers.push((name, value))
  {
    id: self.id,
    url: self.url,
    secret: self.secret,
    headers,
    active: self.active,
    max_attempts: self.max_attempts,
    retry_policy: self.retry_policy,
    timeout_ms: self.timeout_ms,
  }
}

///|
pub fn Hook::with_active(self : Hook, active : Bool) -> Hook {
  {
    id: self.id,
    url: self.url,
    secret: self.secret,
    headers: self.headers,
    active,
    max_attempts: self.max_attempts,
    retry_policy: self.retry_policy,
    timeout_ms: self.timeout_ms,
  }
}

///|
pub fn Hook::with_max_attempts(self : Hook, max_attempts : Int) -> Hook {
  {
    id: self.id,
    url: self.url,
    secret: self.secret,
    headers: self.headers,
    active: self.active,
    max_attempts,
    retry_policy: self.retry_policy,
    timeout_ms: self.timeout_ms,
  }
}

///|
pub fn Hook::with_retry_policy(self : Hook, retry_policy : RetryPolicy) -> Hook {
  {
    id: self.id,
    url: self.url,
    secret: self.secret,
    headers: self.headers,
    active: self.active,
    max_attempts: self.max_attempts,
    retry_policy,
    timeout_ms: self.timeout_ms,
  }
}

///|
pub fn Hook::with_timeout_ms(self : Hook, timeout_ms : Int) -> Hook {
  {
    id: self.id,
    url: self.url,
    secret: self.secret,
    headers: self.headers,
    active: self.active,
    max_attempts: self.max_attempts,
    retry_policy: self.retry_policy,
    timeout_ms,
  }
}

///|
pub fn Hook::validate(self : Hook) -> Result[Unit, String] {
  if self.id == "" {
    Err("hook id is required")
  } else if self.url == "" {
    Err("hook url is required")
  } else if self.max_attempts < 1 {
    Err("max attempts must be at least 1")
  } else if self.timeout_ms <= 0 {
    Err("timeout must be positive")
  } else {
    Ok(())
  }
}

///|
/// Looks up a header value by name, returning the last match.
pub fn Hook::header_value(self : Hook, name : String) -> String? {
  let mut found : String? = None
  for item in self.headers {
    if item.0 == name {
      found = Some(item.1)
    }
  }
  found
}
