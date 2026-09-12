///|
/// Outbound signing schemes of popular WebHook providers.
///
/// MoonHook is the delivery side, so each variant knows how to sign a raw
/// request body. Because the library also ships a minimal receiver, the same
/// variant can verify the matching provider header or body field again — the
/// sender and the receiver share one implementation.
///
/// - `GitHub`: `X-Hub-Signature-256: sha256=<hex>`, HMAC-SHA256 over the raw
///   body. Matches the example in GitHub's "Validating webhook deliveries".
/// - `Stripe`: `Stripe-Signature: t=<unix_s>,v1=<hex>`, HMAC-SHA256 over
///   `"<t>.<body>"`; several `v1` values may be present during secret rotation.
/// - `Slack`: `X-Slack-Signature: v0=<hex>` together with
///   `X-Slack-Request-Timestamp`, HMAC-SHA256 over `"v0:<t>:<body>"`.
/// - `FeishuBot`: the signature travels inside the JSON body as `timestamp`
///   and `sign`, where
///   `sign = base64(HMAC-SHA256(key = "<t>\n<secret>", message = ""))`, as in
///   the official custom-bot sample.
/// - `Shopify`: `X-Shopify-Hmac-Sha256: <base64>`, HMAC-SHA256 over the raw
///   body.
pub(all) enum SignatureProvider {
  GitHub
  Stripe
  Slack
  FeishuBot
  Shopify
} derive(Eq, @debug.Debug)

///|
/// The header GitHub uses for the raw-body HMAC-SHA256 signature.
pub const HEADER_GITHUB_SIGNATURE : String = "X-Hub-Signature-256"

///|
/// The header Stripe uses for `t=<unix_s>,v1=<hex>`.
pub const HEADER_STRIPE_SIGNATURE : String = "Stripe-Signature"

///|
/// The header Slack uses for `v0=<hex>`.
pub const HEADER_SLACK_SIGNATURE : String = "X-Slack-Signature"

///|
/// The header Slack uses for the request timestamp, in seconds.
pub const HEADER_SLACK_TIMESTAMP : String = "X-Slack-Request-Timestamp"

///|
/// The header Shopify uses for the raw-body HMAC-SHA256 signature, base64.
pub const HEADER_SHOPIFY_SIGNATURE : String = "X-Shopify-Hmac-Sha256"

///|
/// HMAC-SHA256 of `message` under `key`, lowercase hex.
fn hmac_hex(key : String, message : String) -> String {
  bytes_to_hex(hmac_sha256(@utf8.encode(key), @utf8.encode(message)))
}

///|
/// HMAC-SHA256 of `message` under `key`, standard base64 with padding.
fn hmac_base64(key : String, message : String) -> String {
  @base64.encode(
    Bytes::from_array(hmac_sha256(@utf8.encode(key), @utf8.encode(message))),
  )
}

///|
/// `"<timestamp>.<body>"`, the Stripe signed payload.
fn stripe_signed_payload(timestamp_s : Int, payload : String) -> String {
  timestamp_s.to_string() + "." + payload
}

///|
/// `"v0:<timestamp>:<body>"`, the Slack signed payload.
fn slack_signed_payload(timestamp_s : Int, payload : String) -> String {
  "v0:" + timestamp_s.to_string() + ":" + payload
}

///|
/// The Feishu custom-bot signature:
/// `base64(HMAC-SHA256(key = "<timestamp>\n<secret>", message = ""))`.
///
/// The timestamp is the HMAC *key* material here, not part of the message,
/// which is why this scheme does not reuse the signed-payload helpers.
fn feishu_bot_sign(secret : String, timestamp_s : Int) -> String {
  hmac_base64(timestamp_s.to_string() + "\n" + secret, "")
}

///|
/// Parses a timestamp expressed in seconds, accepting surrounding whitespace.
fn parse_seconds(value : String) -> Int? {
  let parsed = @string.parse_int(value.trim()) catch { _ => return None }
  Some(parsed)
}

///|
/// True when `timestamp_s` is inside the allowed window. A negative
/// `tolerance_s` disables the window check, which is useful for schemes
/// without a timestamp.
fn within_window(timestamp_s : Int, now_s : Int, tolerance_s : Int) -> Bool {
  if tolerance_s < 0 {
    true
  } else {
    let delta = if timestamp_s > now_s {
      timestamp_s - now_s
    } else {
      now_s - timestamp_s
    }
    delta <= tolerance_s
  }
}

///|
/// Splits `k=v` pairs separated by commas, lowercasing the key.
fn split_signed_header(value : String) -> Array[(String, String)] {
  let parts : Array[(String, String)] = []
  for part in value.split(",") {
    match part.trim().split_once("=") {
      Some((key, raw)) =>
        parts.push((key.to_owned().to_lower(), raw.to_owned()))
      None => ()
    }
  }
  parts
}

///|
/// Strips a `prefix` such as `v0=` when present.
fn strip_signature_scheme(value : String, prefix : String) -> String {
  let trimmed = value.trim()
  if trimmed.has_prefix(prefix) {
    trimmed[prefix.length():].to_owned()
  } else {
    trimmed.to_owned()
  }
}

///|
/// The signature value for `payload`, without any scheme prefix: lowercase hex
/// for GitHub, Stripe and Slack, standard base64 for Shopify and Feishu.
///
/// `timestamp_s` is only used by the schemes that bind a timestamp (Stripe,
/// Slack, Feishu); GitHub and Shopify sign the raw body alone.
pub fn SignatureProvider::sign_value(
  self : SignatureProvider,
  secret : String,
  payload : String,
  timestamp_s : Int,
) -> String {
  match self {
    GitHub => hmac_hex(secret, payload)
    Shopify => hmac_base64(secret, payload)
    Slack => hmac_hex(secret, slack_signed_payload(timestamp_s, payload))
    Stripe => hmac_hex(secret, stripe_signed_payload(timestamp_s, payload))
    FeishuBot => feishu_bot_sign(secret, timestamp_s)
  }
}

///|
/// The request headers a delivery must carry for this scheme, already formatted
/// the way the provider expects.
///
/// `FeishuBot` returns no header: its signature lives in the JSON body, which
/// `feishu_bot_text_body` builds.
pub fn SignatureProvider::sign_headers(
  self : SignatureProvider,
  secret : String,
  payload : String,
  timestamp_s : Int,
) -> Array[(String, String)] {
  let headers : Array[(String, String)] = []
  match self {
    GitHub =>
      headers.push(
        (HEADER_GITHUB_SIGNATURE, "sha256=" + hmac_hex(secret, payload)),
      )
    Shopify =>
      headers.push((HEADER_SHOPIFY_SIGNATURE, hmac_base64(secret, payload)))
    Slack => {
      headers.push((HEADER_SLACK_TIMESTAMP, timestamp_s.to_string()))
      headers.push(
        (
          HEADER_SLACK_SIGNATURE,
          "v0=" + hmac_hex(secret, slack_signed_payload(timestamp_s, payload)),
        ),
      )
    }
    Stripe =>
      headers.push(
        (
          HEADER_STRIPE_SIGNATURE,
          "t=" +
          timestamp_s.to_string() +
          ",v1=" +
          hmac_hex(secret, stripe_signed_payload(timestamp_s, payload)),
        ),
      )
    FeishuBot => ()
  }
  headers
}

///|
/// The header names this scheme uses, in the order `sign_headers` produces
/// them. `FeishuBot` returns an empty array.
pub fn SignatureProvider::header_names(
  self : SignatureProvider,
) -> Array[String] {
  let names : Array[String] = []
  for header in self.sign_headers("", "", 0) {
    names.push(header.0)
  }
  names
}

///|
/// A short human readable description, used by the CLI and diagnostics.
pub fn SignatureProvider::describe(self : SignatureProvider) -> String {
  match self {
    GitHub => "github (sha256=<hex> over the raw body)"
    Stripe => "stripe (t=<unix_s>,v1=<hex> over \"<t>.<body>\")"
    Slack => "slack (v0=<hex> over \"v0:<t>:<body>\")"
    FeishuBot => "feishu-bot (base64 sign in the JSON body)"
    Shopify => "shopify (base64 over the raw body)"
  }
}

///|
/// Parses a provider name, case insensitively: `github`, `stripe`, `slack`,
/// `feishu` (also `feishu-bot` / `lark`) and `shopify`.
pub fn SignatureProvider::parse(name : String) -> SignatureProvider? {
  match name.trim().to_lower() {
    "github" => Some(GitHub)
    "stripe" => Some(Stripe)
    "slack" => Some(Slack)
    "feishu" | "feishu-bot" | "lark" => Some(FeishuBot)
    "shopify" => Some(Shopify)
    _ => None
  }
}

///|
/// Every supported provider, useful for help output and iteration.
pub fn signature_providers() -> Array[SignatureProvider] {
  [GitHub, Stripe, Slack, FeishuBot, Shopify]
}

///|
/// Verifies an incoming request that was signed with this scheme.
///
/// Header lookup is case insensitive. `tolerance_s` bounds the age of the
/// signature for the timestamped schemes; pass a negative value to skip the
/// window check (GitHub and Shopify carry no timestamp at all). Verification is
/// always a constant-time comparison and never throws: malformed input simply
/// fails.
pub fn SignatureProvider::verify(
  self : SignatureProvider,
  secret : String,
  headers : Array[(String, String)],
  payload : String,
  now_s : Int,
  tolerance_s : Int,
) -> Bool {
  match self {
    GitHub =>
      match find_header(headers, HEADER_GITHUB_SIGNATURE) {
        Some(value) => verify_signature_header(secret, payload, value)
        None => false
      }
    Shopify =>
      match find_header(headers, HEADER_SHOPIFY_SIGNATURE) {
        Some(value) =>
          constant_time_eq(
            hmac_base64(secret, payload),
            strip_signature_scheme(value, ""),
          )
        None => false
      }
    Slack =>
      match
        (
          find_header(headers, HEADER_SLACK_SIGNATURE),
          find_header(headers, HEADER_SLACK_TIMESTAMP),
        ) {
        (Some(signature), Some(timestamp)) =>
          match parse_seconds(timestamp) {
            Some(timestamp_s) =>
              within_window(timestamp_s, now_s, tolerance_s) &&
              constant_time_eq(
                hmac_hex(secret, slack_signed_payload(timestamp_s, payload)),
                strip_signature_scheme(signature, "v0="),
              )
            None => false
          }
        _ => false
      }
    Stripe =>
      match find_header(headers, HEADER_STRIPE_SIGNATURE) {
        Some(value) => {
          let mut timestamp_s : Int? = None
          let candidates : Array[String] = []
          for part in split_signed_header(value) {
            if part.0 == "t" {
              timestamp_s = parse_seconds(part.1)
            }
            if part.0 == "v1" {
              candidates.push(part.1)
            }
          }
          match timestamp_s {
            None => false
            Some(timestamp_s) =>
              if !within_window(timestamp_s, now_s, tolerance_s) {
                false
              } else {
                let expected = hmac_hex(
                  secret,
                  stripe_signed_payload(timestamp_s, payload),
                )
                let mut matched = false
                for candidate in candidates {
                  if constant_time_eq(expected, candidate) {
                    matched = true
                  }
                }
                matched
              }
          }
        }
        None => false
      }
    FeishuBot => {
      let json = @json.parse(payload) catch { _ => return false }
      guard json is Object(map) else { return false }
      let timestamp = match json_string_field(map, "timestamp") {
        Some(value) => Some(value)
        None =>
          match json_timestamp_field(map, "timestamp") {
            Some(value) => Some(value.to_string())
            None => None
          }
      }
      match (timestamp, json_string_field(map, "sign")) {
        (Some(timestamp), Some(sign)) =>
          match parse_seconds(timestamp) {
            Some(timestamp_s) =>
              within_window(timestamp_s, now_s, tolerance_s) &&
              constant_time_eq(feishu_bot_sign(secret, timestamp_s), sign)
            None => false
          }
        _ => false
      }
    }
  }
}

///|
/// Builds the JSON body of a Feishu custom-bot text message, including the
/// `timestamp` and `sign` fields the bot expects.
pub fn feishu_bot_text_body(
  secret : String,
  text : String,
  timestamp_s : Int,
) -> String {
  Json::object({
    "timestamp": Json::string(timestamp_s.to_string()),
    "sign": Json::string(feishu_bot_sign(secret, timestamp_s)),
    "msg_type": Json::string("text"),
    "content": Json::object({ "text": Json::string(text) }),
  }).stringify()
}

///|
/// Returns a copy of `request` with this provider's signature headers appended.
///
/// The body and the MoonHook native signature are left untouched, so a delivery
/// can satisfy the provider scheme and MoonHook's own receiver at the same
/// time. For `FeishuBot` the signature belongs in the body: build it with
/// `feishu_bot_text_body` and use that as the event payload.
pub fn SignedRequest::with_provider_signature(
  self : SignedRequest,
  provider : SignatureProvider,
  secret : String,
  timestamp_s : Int,
) -> SignedRequest {
  let headers = self.headers.copy()
  for header in provider.sign_headers(secret, self.body, timestamp_s) {
    headers.push(header)
  }
  {
    http_method: self.http_method,
    url: self.url,
    headers,
    body: self.body,
    signature: self.signature,
  }
}
