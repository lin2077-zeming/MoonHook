///|
/// GitHub's documented example from "Validating webhook deliveries":
/// secret `It's a Secret to Everybody`, body `Hello, World!`.
test "github signature matches the documented vector" {
  let provider = @MoonHook.SignatureProvider::GitHub
  let secret = "It's a Secret to Everybody"
  let payload = "Hello, World!"
  let expected = "757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"
  assert_eq(provider.sign_value(secret, payload, 0), expected)
  let headers = provider.sign_headers(secret, payload, 0)
  assert_eq(headers.length(), 1)
  assert_eq(headers[0].0, "X-Hub-Signature-256")
  assert_eq(headers[0].1, "sha256=" + expected)
  assert_true(provider.verify(secret, headers, payload, 0, -1))
  assert_false(provider.verify(secret, headers, "Hello, World?", 0, -1))
  assert_false(provider.verify("wrong secret", headers, payload, 0, -1))
}

///|
/// Stripe's `t=<unix_s>,v1=<hex>` scheme over `"<t>.<body>"`. The expected
/// values below were cross-checked against an independent HMAC-SHA256
/// implementation.
test "stripe signature matches the cross-checked vector" {
  let provider = @MoonHook.SignatureProvider::Stripe
  let secret = "whsec_test_secret"
  let payload = "{\"id\": \"evt_test_webhook\", \"object\": \"event\"}"
  let expected = "c137b1b62277d523cf8fed4dfbd0170a9a5b8a380e00cc3711d4bf0652f2ce7a"
  assert_eq(provider.sign_value(secret, payload, 1492774577), expected)
  let headers = provider.sign_headers(secret, payload, 1492774577)
  assert_eq(headers.length(), 1)
  assert_eq(headers[0].0, "Stripe-Signature")
  assert_eq(headers[0].1, "t=1492774577,v1=" + expected)
  assert_true(provider.verify(secret, headers, payload, 1492774577, 300))
  assert_true(provider.verify(secret, headers, payload, 1492774577 + 299, 300))
  assert_false(provider.verify(secret, headers, payload, 1492774577 + 301, 300))
  assert_false(
    provider.verify(
      secret, headers, "{\"id\": \"evt_test_webhook\"}", 1492774577, 300,
    ),
  )
}

///|
/// During secret rotation Stripe may send several `v1` values; any match counts.
test "stripe accepts one matching signature among several" {
  let provider = @MoonHook.SignatureProvider::Stripe
  let secret = "whsec_test_secret"
  let payload = "{\"id\": \"evt_test_webhook\", \"object\": \"event\"}"
  let valid = "c137b1b62277d523cf8fed4dfbd0170a9a5b8a380e00cc3711d4bf0652f2ce7a"
  let rotated = [("Stripe-Signature", "t=1492774577,v1=deadbeef,v1=" + valid)]
  assert_true(provider.verify(secret, rotated, payload, 1492774577, 300))
  let unknown = [("Stripe-Signature", "t=1492774577,v1=deadbeef")]
  assert_false(provider.verify(secret, unknown, payload, 1492774577, 300))
  let missing_timestamp = [("Stripe-Signature", "v1=" + valid)]
  assert_false(
    provider.verify(secret, missing_timestamp, payload, 1492774577, 300),
  )
}

///|
/// Slack's `v0=<hex>` scheme over `"v0:<t>:<body>"`; the expected value was
/// cross-checked against an independent HMAC-SHA256 implementation.
test "slack signature matches the cross-checked vector" {
  let provider = @MoonHook.SignatureProvider::Slack
  let secret = "8f742231b10e8888abcd99yyyzzz85a5"
  let body = "token=xyzz0WbapA4vBCDEFasx0q6G&team_id=T1DC2JH3J&team_domain=testteamnow&channel_id=G8PSS9T3V&channel_name=foobar&user_id=U2CERLKJA&user_name=roadrunner&command=%2Fwebhook-collect&text=&response_url=https%3A%2F%2Fhooks.slack.com%2Fcommands%2FT1DC2JH3J%2F397700885554%2F96rGlfmibIGlgcZRskXaIFfN&trigger_id=398738663015.47445629121.803a0bc887a14d10d2c447fce8b6703c"
  let expected = "a2114d57b48eac39b9ad189dd8316235a7b4a8d21a10bd27519666489c69b503"
  assert_eq(provider.sign_value(secret, body, 1531420618), expected)
  let headers = provider.sign_headers(secret, body, 1531420618)
  assert_eq(headers.length(), 2)
  assert_eq(headers[0].0, "X-Slack-Request-Timestamp")
  assert_eq(headers[0].1, "1531420618")
  assert_eq(headers[1].0, "X-Slack-Signature")
  assert_eq(headers[1].1, "v0=" + expected)
  assert_true(provider.verify(secret, headers, body, 1531420618 + 60, 300))
  assert_false(provider.verify(secret, headers, body, 1531420618 - 3600, 300))
  let lowercased = [
    ("x-slack-signature", "v0=" + expected),
    ("X-SLACK-REQUEST-TIMESTAMP", "1531420618"),
  ]
  assert_true(provider.verify(secret, lowercased, body, 1531420618, 300))
}

///|
/// Shopify signs the raw body with base64 instead of hex. Cross-checked against
/// an independent HMAC-SHA256 implementation.
test "shopify signature matches the cross-checked vector" {
  let provider = @MoonHook.SignatureProvider::Shopify
  let payload = "{\"id\":1234}"
  let expected = "hqshSVej2gPnBo3UvyGMbZ8zuh79mY0OQ2EtG972/3Y="
  assert_eq(provider.sign_value("hush", payload, 0), expected)
  let headers = provider.sign_headers("hush", payload, 0)
  assert_eq(headers.length(), 1)
  assert_eq(headers[0].0, "X-Shopify-Hmac-Sha256")
  assert_eq(headers[0].1, expected)
  assert_true(provider.verify("hush", headers, payload, 0, -1))
  assert_false(provider.verify("hush2", headers, payload, 0, -1))
}

///|
/// Feishu custom-bot signature:
/// `base64(HMAC-SHA256(key = "<t>\n<secret>", message = ""))`. Cross-checked
/// against an independent HMAC-SHA256 implementation.
test "feishu bot signature matches the cross-checked vector" {
  let provider = @MoonHook.SignatureProvider::FeishuBot
  let expected = "mYHw2R2SOm8Rw/sne3lQdmz4sOfntKR+1P/8RKKTwmA="
  assert_eq(provider.sign_value("demo-secret", "", 1700000000), expected)
  assert_eq(provider.sign_headers("demo-secret", "", 1700000000).length(), 0)
  let body = @MoonHook.feishu_bot_text_body(
    "demo-secret", "deploy finished", 1700000000,
  )
  assert_true(body.contains(expected))
  assert_true(provider.verify("demo-secret", [], body, 1700000000, 3600))
  assert_false(provider.verify("other-secret", [], body, 1700000000, 3600))
  assert_false(
    provider.verify("demo-secret", [], body, 1700000000 + 7200, 3600),
  )
  // A rewritten sign or timestamp no longer verifies.
  let rewritten = "{\"timestamp\":\"1700000000\",\"sign\":\"AAAA\",\"msg_type\":\"text\",\"content\":{\"text\":\"deploy finished\"}}"
  assert_false(provider.verify("demo-secret", [], rewritten, 1700000000, 3600))
  let stale = "{\"timestamp\":\"1700009999\",\"sign\":\"" +
    expected +
    "\",\"msg_type\":\"text\",\"content\":{\"text\":\"deploy finished\"}}"
  assert_false(provider.verify("demo-secret", [], stale, 1700009999, 3600))
}

///|
test "provider metadata is reportable" {
  assert_eq(@MoonHook.SignatureProvider::GitHub.header_names().length(), 1)
  assert_eq(
    @MoonHook.SignatureProvider::GitHub.header_names()[0],
    "X-Hub-Signature-256",
  )
  assert_eq(@MoonHook.SignatureProvider::Slack.header_names().length(), 2)
  assert_eq(@MoonHook.SignatureProvider::FeishuBot.header_names().length(), 0)
  assert_true(@MoonHook.SignatureProvider::Stripe.describe().contains("stripe"))
}

///|
/// Provider headers can be attached to a MoonHook signed request, so one
/// delivery satisfies both the provider scheme and MoonHook's own receiver.
test "provider headers can be attached to a signed request" {
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders").with_secret(
    "whsec_test_secret",
  )
  let built = @MoonHook.EventBuilder::new()
    .with_id("evt-1")
    .with_event_type("order.created")
    .with_payload("{\"id\": \"evt_test_webhook\", \"object\": \"event\"}")
    .build()
  let event = match built {
    Ok(event) => event
    Err(message) => abort(message)
  }
  let request = @MoonHook.build_signed_request(hook, event)
  let signed = request.with_provider_signature(
    @MoonHook.SignatureProvider::Stripe,
    "whsec_test_secret",
    1492774577,
  )
  assert_true(
    @MoonHook.find_header(signed.headers, "Stripe-Signature") is Some(_),
  )
  assert_true(
    @MoonHook.find_header(signed.headers, "X-MoonHook-Signature") is Some(_),
  )
  assert_eq(signed.body, request.body)
  assert_eq(signed.headers.length(), request.headers.length() + 1)
}

///|
/// Missing or malformed signatures must fail closed instead of throwing.
test "malformed provider input is rejected" {
  let secret = "shared-secret"
  let payload = "{\"id\":1}"
  assert_false(
    @MoonHook.SignatureProvider::GitHub.verify(secret, [], payload, 0, -1),
  )
  assert_false(
    @MoonHook.SignatureProvider::Shopify.verify(secret, [], payload, 0, -1),
  )
  assert_false(
    @MoonHook.SignatureProvider::Slack.verify(
      secret,
      [("X-Slack-Signature", "v0=deadbeef")],
      payload,
      0,
      300,
    ),
  )
  assert_false(
    @MoonHook.SignatureProvider::Slack.verify(
      secret,
      [("X-Slack-Request-Timestamp", "not-a-number")],
      payload,
      0,
      300,
    ),
  )
  assert_false(
    @MoonHook.SignatureProvider::Stripe.verify(
      secret,
      [("Stripe-Signature", "garbage")],
      payload,
      0,
      300,
    ),
  )
  assert_false(
    @MoonHook.SignatureProvider::FeishuBot.verify(
      secret,
      [],
      "not json",
      0,
      300,
    ),
  )
  assert_false(
    @MoonHook.SignatureProvider::FeishuBot.verify(secret, [], "[]", 0, 300),
  )
  assert_false(
    @MoonHook.SignatureProvider::FeishuBot.verify(
      secret,
      [],
      "{\"timestamp\":\"abc\",\"sign\":\"x\"}",
      0,
      300,
    ),
  )
  assert_false(
    @MoonHook.SignatureProvider::FeishuBot.verify(
      secret,
      [],
      "{\"sign\":\"x\"}",
      0,
      300,
    ),
  )
}

///|
test "provider names can be parsed" {
  assert_eq(
    @MoonHook.SignatureProvider::parse("Stripe"),
    Some(@MoonHook.SignatureProvider::Stripe),
  )
  assert_eq(
    @MoonHook.SignatureProvider::parse(" feishu "),
    Some(@MoonHook.SignatureProvider::FeishuBot),
  )
  assert_eq(
    @MoonHook.SignatureProvider::parse("LARK"),
    Some(@MoonHook.SignatureProvider::FeishuBot),
  )
  assert_eq(@MoonHook.SignatureProvider::parse("nope"), None)
  assert_eq(@MoonHook.signature_providers().length(), 5)
}
