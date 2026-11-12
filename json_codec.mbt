///|
/// Converts a `WebhookEvent` to a `Json` value.
pub fn event_to_json(event : WebhookEvent) -> Json {
  Json::object({
    "id": Json::string(event.id),
    "event_type": Json::string(event.event_type),
    "subject": Json::string(event.subject),
    "payload": Json::string(event.payload),
    "timestamp_ms": Json::number(event.timestamp_ms.to_double()),
    "idempotency_key": Json::string(event.idempotency_key),
  })
}

///|
pub fn event_to_json_string(event : WebhookEvent) -> String {
  event_to_json(event).stringify()
}

///|
fn json_string_field(map : Map[String, Json], key : String) -> String? {
  match map.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_timestamp_field(map : Map[String, Json], key : String) -> Int32? {
  match map.get(key) {
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
pub fn event_from_json(json : Json) -> Result[WebhookEvent, String] {
  match json {
    Object(map) =>
      match
        (
          json_string_field(map, "id"),
          json_string_field(map, "event_type"),
          json_string_field(map, "payload"),
          json_timestamp_field(map, "timestamp_ms"),
        ) {
        (Some(id), Some(event_type), Some(payload), Some(timestamp_ms)) => {
          let subject = match json_string_field(map, "subject") {
            Some(value) => value
            None => ""
          }
          let idempotency_key = match
            json_string_field(map, "idempotency_key") {
            Some(value) => value
            None => id + ":" + event_type
          }
          Ok(
            WebhookEvent::new(
              id, event_type, subject, payload, timestamp_ms, idempotency_key,
            ),
          )
        }
        _ => Err("invalid event json")
      }
    _ => Err("expected json object")
  }
}

///|
pub fn event_from_json_string(input : String) -> Result[WebhookEvent, String] {
  let json = @json.parse(input) catch { _ => return Err("invalid json") }
  event_from_json(json)
}

///|
fn json_int_field(map : Map[String, Json], key : String) -> Int32? {
  match map.get(key) {
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
fn json_double_field(map : Map[String, Json], key : String) -> Double? {
  match map.get(key) {
    Some(Number(value, ..)) => Some(value)
    _ => None
  }
}

///|
fn json_bool_field(map : Map[String, Json], key : String) -> Bool? {
  match map.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn json_headers_field(
  map : Map[String, Json],
  key : String,
) -> Array[(String, String)]? {
  match map.get(key) {
    Some(Array(items)) => {
      let headers : Array[(String, String)] = []
      for item in items {
        match item {
          Object(fields) =>
            match
              (
                json_string_field(fields, "name"),
                json_string_field(fields, "value"),
              ) {
              (Some(name), Some(value)) => headers.push((name, value))
              _ => return None
            }
          _ => return None
        }
      }
      Some(headers)
    }
    _ => None
  }
}

///|
/// Converts a `RetryPolicy` to a `Json` value.
pub fn retry_policy_to_json(policy : RetryPolicy) -> Json {
  match policy {
    None => Json::object({ "kind": Json::string("none") })
    Fixed(delay_ms) =>
      Json::object({
        "kind": Json::string("fixed"),
        "delay_ms": Json::number(delay_ms.to_double()),
      })
    Exponential(initial_ms, multiplier, max_ms) =>
      Json::object({
        "kind": Json::string("exponential"),
        "initial_ms": Json::number(initial_ms.to_double()),
        "multiplier": Json::number(multiplier),
        "max_ms": Json::number(max_ms.to_double()),
      })
  }
}

///|
pub fn retry_policy_from_json(json : Json) -> Result[RetryPolicy, String] {
  match json {
    Object(map) =>
      match json_string_field(map, "kind") {
        Some("none") => Ok(None)
        Some("fixed") =>
          match json_int_field(map, "delay_ms") {
            Some(delay_ms) => Ok(Fixed(delay_ms))
            None => Err("invalid retry policy json")
          }
        Some("exponential") =>
          match
            (
              json_int_field(map, "initial_ms"),
              json_double_field(map, "multiplier"),
              json_int_field(map, "max_ms"),
            ) {
            (Some(initial_ms), Some(multiplier), Some(max_ms)) =>
              Ok(Exponential(initial_ms, multiplier, max_ms))
            _ => Err("invalid retry policy json")
          }
        _ => Err("invalid retry policy json")
      }
    _ => Err("invalid retry policy json")
  }
}

///|
/// Converts a `Hook` to a `Json` value.
pub fn hook_to_json(hook : Hook) -> Json {
  let header_json = hook.headers.map(fn(item) {
    Json::object({ "name": Json::string(item.0), "value": Json::string(item.1) })
  })
  Json::object({
    "id": Json::string(hook.id),
    "url": Json::string(hook.url),
    "secret": Json::string(hook.secret),
    "headers": Json::array(header_json),
    "active": Json::boolean(hook.active),
    "max_attempts": Json::number(hook.max_attempts.to_double()),
    "retry_policy": retry_policy_to_json(hook.retry_policy),
    "timeout_ms": Json::number(hook.timeout_ms.to_double()),
  })
}

///|
pub fn hook_from_json(json : Json) -> Result[Hook, String] {
  match json {
    Object(map) =>
      match
        (
          json_string_field(map, "id"),
          json_string_field(map, "url"),
          json_string_field(map, "secret"),
          json_headers_field(map, "headers"),
          json_bool_field(map, "active"),
          json_int_field(map, "max_attempts"),
          json_int_field(map, "timeout_ms"),
        ) {
        (
          Some(id),
          Some(url),
          Some(secret),
          Some(headers),
          Some(active),
          Some(max_attempts),
          Some(timeout_ms),
        ) => {
          let retry_policy = match map.get("retry_policy") {
            Some(policy_json) =>
              match retry_policy_from_json(policy_json) {
                Ok(policy) => policy
                Err(message) => return Err(message)
              }
            None => Fixed(100)
          }
          Ok({
            id,
            url,
            secret,
            headers,
            active,
            max_attempts,
            retry_policy,
            timeout_ms,
          })
        }
        _ => Err("invalid hook json")
      }
    _ => Err("expected json object")
  }
}

///|
pub fn hook_to_json_string(hook : Hook) -> String {
  hook_to_json(hook).stringify()
}

///|
pub fn hook_from_json_string(input : String) -> Result[Hook, String] {
  let json = @json.parse(input) catch { _ => return Err("invalid json") }
  hook_from_json(json)
}

///|
/// Converts a `PendingDelivery` to a `Json` value.
pub fn pending_delivery_to_json(item : PendingDelivery) -> Json {
  Json::object({
    "hook_id": Json::string(item.hook_id),
    "event": event_to_json(item.event),
    "queued_at_ms": Json::number(item.queued_at_ms.to_double()),
    "attempts_used": Json::number(item.attempts_used.to_double()),
  })
}

///|
pub fn pending_delivery_from_json(
  json : Json,
) -> Result[PendingDelivery, String] {
  match json {
    Object(map) =>
      match
        (
          json_string_field(map, "hook_id"),
          json_int_field(map, "queued_at_ms"),
          json_int_field(map, "attempts_used"),
        ) {
        (Some(hook_id), Some(queued_at_ms), Some(attempts_used)) =>
          match map.get("event") {
            Some(event_json) =>
              match event_from_json(event_json) {
                Ok(event) =>
                  Ok({ hook_id, event, queued_at_ms, attempts_used, })
                Err(_) => Err("invalid pending delivery json")
              }
            None => Err("invalid pending delivery json")
          }
        _ => Err("invalid pending delivery json")
      }
    _ => Err("expected json object")
  }
}

///|
pub fn pending_delivery_to_json_string(item : PendingDelivery) -> String {
  pending_delivery_to_json(item).stringify()
}

///|
pub fn pending_delivery_from_json_string(
  input : String,
) -> Result[PendingDelivery, String] {
  let json = @json.parse(input) catch { _ => return Err("invalid json") }
  pending_delivery_from_json(json)
}

///|
/// Converts a `DeadLetterEntry` to a `Json` value.
pub fn dead_letter_to_json(entry : DeadLetterEntry) -> Json {
  Json::object({
    "hook_id": Json::string(entry.hook_id),
    "event": event_to_json(entry.event),
    "reason": Json::string(entry.reason),
    "failed_at_ms": Json::number(entry.failed_at_ms.to_double()),
    "attempts": Json::number(entry.attempts.to_double()),
  })
}

///|
pub fn dead_letter_from_json(json : Json) -> Result[DeadLetterEntry, String] {
  match json {
    Object(map) =>
      match
        (
          json_string_field(map, "hook_id"),
          json_string_field(map, "reason"),
          json_int_field(map, "failed_at_ms"),
          json_int_field(map, "attempts"),
        ) {
        (Some(hook_id), Some(reason), Some(failed_at_ms), Some(attempts)) =>
          match map.get("event") {
            Some(event_json) =>
              match event_from_json(event_json) {
                Ok(event) =>
                  Ok({ hook_id, event, reason, failed_at_ms, attempts, })
                Err(_) => Err("invalid dead letter json")
              }
            None => Err("invalid dead letter json")
          }
        _ => Err("invalid dead letter json")
      }
    _ => Err("expected json object")
  }
}

///|
pub fn dead_letter_to_json_string(entry : DeadLetterEntry) -> String {
  dead_letter_to_json(entry).stringify()
}

///|
pub fn dead_letter_from_json_string(
  input : String,
) -> Result[DeadLetterEntry, String] {
  let json = @json.parse(input) catch { _ => return Err("invalid json") }
  dead_letter_from_json(json)
}
