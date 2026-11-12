///|
/// A fully formed webhook HTTP request ready to be sent by an HTTP transport.
#derive(Eq, @debug.Debug)
pub(all) struct SignedRequest {
  http_method : String
  url : String
  headers : Array[(String, String)]
  body : String
  signature : String
}

///|
/// HTTP header names used by MoonHook signed requests.
pub const HEADER_SIGNATURE : String = "X-MoonHook-Signature"

///|
pub const HEADER_EVENT_ID : String = "X-MoonHook-Event-Id"

///|
pub const HEADER_EVENT_TYPE : String = "X-MoonHook-Event-Type"

///|
pub const HEADER_SUBJECT : String = "X-MoonHook-Subject"

///|
pub const HEADER_TIMESTAMP : String = "X-MoonHook-Timestamp"

///|
pub const HEADER_IDEMPOTENCY_KEY : String = "X-MoonHook-Idempotency-Key"

///|
pub const HEADER_CONTENT_TYPE : String = "Content-Type"

///|
/// Builds a signed POST request from a Hook and an event. The signature is an
/// HMAC-SHA256 digest of `"<timestamp_ms>.<payload>"`, sent together with the
/// timestamp in `X-MoonHook-Timestamp` so receivers can reject replays.
pub fn build_signed_request(hook : Hook, event : WebhookEvent) -> SignedRequest {
  let signature = sign_webhook(hook.secret, event.timestamp_ms, event.payload)
  let headers = hook.headers.copy()
  headers.push((HEADER_SIGNATURE, signature))
  headers.push((HEADER_EVENT_ID, event.id))
  headers.push((HEADER_EVENT_TYPE, event.event_type))
  headers.push((HEADER_SUBJECT, event.subject))
  headers.push((HEADER_TIMESTAMP, event.timestamp_ms.to_string()))
  headers.push((HEADER_IDEMPOTENCY_KEY, event.idempotency_key))
  headers.push((HEADER_CONTENT_TYPE, "application/json"))
  {
    http_method: "POST",
    url: hook.url,
    headers,
    body: event.payload,
    signature,
  }
}

///|
/// Compares two HTTP header names case-insensitively.
fn header_name_matches(left : String, right : String) -> Bool {
  left.to_lower() == right.to_lower()
}

///|
/// Finds a header value by name, returning the last match. Header names are
/// matched case-insensitively, following HTTP semantics.
pub fn find_header(headers : Array[(String, String)], name : String) -> String? {
  let mut found : String? = None
  for item in headers {
    if header_name_matches(item.0, name) {
      found = Some(item.1)
    }
  }
  found
}

///|
/// Strips the common `sha256=` prefix from a signature header value after
/// trimming surrounding whitespace. Raw hex signatures are returned unchanged.
fn strip_signature_prefix(value : String) -> String {
  let trimmed = value.trim().to_owned()
  match trimmed.split_once("=") {
    Some((scheme, rest)) if scheme.to_owned().to_lower() == "sha256" =>
      rest.to_owned()
    _ => trimmed
  }
}

///|
/// Verifies an incoming webhook signature header, accepting either a raw
/// lowercase hex digest or a GitHub-style `sha256=<hex>` value.
pub fn verify_signature_header(
  secret : String,
  body : String,
  header_value : String,
) -> Bool {
  verify_hmac_sha256(secret, body, strip_signature_prefix(header_value))
}

///|
/// Verifies an incoming webhook request using the shared secret, raw body, and
/// the `X-MoonHook-Signature` header.
pub fn verify_webhook_request(
  secret : String,
  headers : Array[(String, String)],
  body : String,
) -> Bool {
  match find_header(headers, HEADER_SIGNATURE) {
    Some(signature) => verify_signature_header(secret, body, signature)
    None => false
  }
}

///|
/// Signs a webhook payload with HMAC-SHA256 over `"<timestamp_ms>.<payload>"`.
/// Including the timestamp lets receivers reject replayed requests.
pub fn sign_webhook(
  secret : String,
  timestamp_ms : Int32,
  payload : String,
) -> String {
  sign_hmac_sha256(secret, timestamp_ms.to_string() + "." + payload)
}

///|
/// Verifies a timestamped webhook signature and requires the timestamp to fall
/// inside `[now_ms - tolerance_ms, now_ms + tolerance_ms]`.
pub fn verify_webhook(
  secret : String,
  timestamp_ms : Int32,
  payload : String,
  signature : String,
  now_ms : Int32,
  tolerance_ms : Int32,
) -> Bool {
  let tolerance = if tolerance_ms < 0 { 0 } else { tolerance_ms }
  let in_window = timestamp_ms >= now_ms - tolerance &&
    timestamp_ms <= now_ms + tolerance
  in_window &&
  verify_hmac_sha256(
    secret,
    timestamp_ms.to_string() + "." + payload,
    signature,
  )
}

///|
/// Verifies a MoonHook native signed request using `X-MoonHook-Timestamp` and
/// the signature header, rejecting messages outside the freshness window.
pub fn verify_webhook_request_with_timestamp(
  secret : String,
  headers : Array[(String, String)],
  body : String,
  now_ms : Int32,
  tolerance_ms : Int32,
) -> Bool {
  match find_header(headers, HEADER_TIMESTAMP) {
    None => false
    Some(timestamp) => {
      let timestamp_ms = @string.parse_int(timestamp.trim()) catch {
        _ => return false
      }
      match find_header(headers, HEADER_SIGNATURE) {
        Some(signature) =>
          verify_webhook(
            secret,
            timestamp_ms,
            body,
            strip_signature_prefix(signature),
            now_ms,
            tolerance_ms,
          )
        None => false
      }
    }
  }
}

///|
pub fn verify_signed_request(secret : String, request : SignedRequest) -> Bool {
  match find_header(request.headers, HEADER_TIMESTAMP) {
    None => false
    Some(timestamp) => {
      let timestamp_ms = @string.parse_int(timestamp.trim()) catch {
        _ => return false
      }
      verify_hmac_sha256(
        secret,
        timestamp_ms.to_string() + "." + request.body,
        request.signature,
      )
    }
  }
}
