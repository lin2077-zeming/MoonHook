///|
/// A webhook event is the immutable payload delivered to a Hook.
pub(all) struct WebhookEvent {
  id : String
  event_type : String
  subject : String
  payload : String
  timestamp_ms : Int
  idempotency_key : String
} derive(Eq, @debug.Debug)

///|
/// Constructs a `WebhookEvent` directly. Prefer `EventBuilder` for validation.
pub fn WebhookEvent::new(
  id : String,
  event_type : String,
  subject : String,
  payload : String,
  timestamp_ms : Int,
  idempotency_key : String,
) -> WebhookEvent {
  { id, event_type, subject, payload, timestamp_ms, idempotency_key }
}

///|
/// Builder for `WebhookEvent` with validation in `build`.
pub(all) struct EventBuilder {
  id : String
  event_type : String
  subject : String
  payload : String
  timestamp_ms : Int
  idempotency_key : String
} derive(Eq, @debug.Debug)

///|
pub fn EventBuilder::new() -> EventBuilder {
  {
    id: "",
    event_type: "",
    subject: "",
    payload: "{}",
    timestamp_ms: 0,
    idempotency_key: "",
  }
}

///|
pub fn EventBuilder::with_id(self : EventBuilder, id : String) -> EventBuilder {
  {
    id,
    event_type: self.event_type,
    subject: self.subject,
    payload: self.payload,
    timestamp_ms: self.timestamp_ms,
    idempotency_key: self.idempotency_key,
  }
}

///|
pub fn EventBuilder::with_event_type(
  self : EventBuilder,
  event_type : String,
) -> EventBuilder {
  {
    id: self.id,
    event_type,
    subject: self.subject,
    payload: self.payload,
    timestamp_ms: self.timestamp_ms,
    idempotency_key: self.idempotency_key,
  }
}

///|
pub fn EventBuilder::with_subject(self : EventBuilder, subject : String) -> EventBuilder {
  {
    id: self.id,
    event_type: self.event_type,
    subject,
    payload: self.payload,
    timestamp_ms: self.timestamp_ms,
    idempotency_key: self.idempotency_key,
  }
}

///|
pub fn EventBuilder::with_payload(self : EventBuilder, payload : String) -> EventBuilder {
  {
    id: self.id,
    event_type: self.event_type,
    subject: self.subject,
    payload,
    timestamp_ms: self.timestamp_ms,
    idempotency_key: self.idempotency_key,
  }
}

///|
pub fn EventBuilder::with_timestamp_ms(
  self : EventBuilder,
  timestamp_ms : Int,
) -> EventBuilder {
  {
    id: self.id,
    event_type: self.event_type,
    subject: self.subject,
    payload: self.payload,
    timestamp_ms,
    idempotency_key: self.idempotency_key,
  }
}

///|
pub fn EventBuilder::with_idempotency_key(
  self : EventBuilder,
  idempotency_key : String,
) -> EventBuilder {
  {
    id: self.id,
    event_type: self.event_type,
    subject: self.subject,
    payload: self.payload,
    timestamp_ms: self.timestamp_ms,
    idempotency_key,
  }
}

///|
/// Validates required fields and falls back to a deterministic
/// idempotency key based on event id and type.
pub fn EventBuilder::build(self : EventBuilder) -> Result[WebhookEvent, String] {
  if self.id == "" {
    Err("event id is required")
  } else if self.event_type == "" {
    Err("event type is required")
  } else {
    let key = if self.idempotency_key == "" {
      self.id + ":" + self.event_type
    } else {
      self.idempotency_key
    }
    Ok(
      WebhookEvent::new(
        self.id,
        self.event_type,
        self.subject,
        self.payload,
        self.timestamp_ms,
        key,
      )
    )
  }
}
