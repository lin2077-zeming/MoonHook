///|
fn arg_at(args : Array[String], index : Int) -> String? {
  if index < args.length() {
    Some(args[index])
  } else {
    None
  }
}

///|
fn print_usage() -> Unit {
  println("MoonHook demo CLI")
  println("  moon run cmd/main -- demo")
  println("  moon run cmd/main -- sign <secret> <payload>")
  println("  moon run cmd/main -- verify <secret> <payload> <signature>")
  println("  moon run cmd/main -- request <hook-id> <url> <secret> <payload>")
  println("  moon run cmd/main -- help")
}

///|
fn run_request(
  hook_id : String,
  url : String,
  secret : String,
  payload : String,
) -> Unit {
  let hook = @MoonHook.Hook::new(hook_id, url).with_secret(secret)
  let event_result = @MoonHook.EventBuilder::new()
    .with_id("evt-cli")
    .with_event_type("cli.request")
    .with_payload(payload)
    .build()
  let event = match event_result {
    Ok(event) => event
    Err(message) => abort(message)
  }
  let request = @MoonHook.build_signed_request(hook, event)
  println("method: \{request.http_method}")
  println("url: \{request.url}")
  for item in request.headers {
    println("\{item.0}: \{item.1}")
  }
  println("body: \{request.body}")
  println("signature: \{request.signature}")
}

///|
fn run_demo() -> Unit {
  let registry = @MoonHook.HookRegistry::new()
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders")
    .with_secret("demo-secret")
    .with_header("X-Team", "payments")
  registry.register(hook) |> ignore

  let event_result = @MoonHook.EventBuilder::new()
    .with_id("evt-demo-1")
    .with_event_type("order.created")
    .with_subject("order/42")
    .with_payload("{\"total\": 99}")
    .build()
  let event = match event_result {
    Ok(event) => event
    Err(message) => abort(message)
  }

  let signature = @MoonHook.sign_hmac_sha256(hook.secret, event.payload)
  let mock = @MoonHook.MockTransport::new([@MoonHook.DeliveryResult::success(6)])
  let engine = @MoonHook.DeliveryEngine::new(registry, mock.as_transport())
  let outcome = engine.deliver("orders", event)
  println("event: \{event.id} (\{event.event_type})")
  println("signature: \{signature}")
  println("status: \{outcome.status.describe()}")
  println("attempts: \{outcome.attempts.length()}")
}

///|
fn main {
  let args = @env.args()
  let command = if args.length() > 1 { args[1] } else { "" }
  match command {
    "demo" => run_demo()
    "sign" =>
      match (arg_at(args, 2), arg_at(args, 3)) {
        (Some(secret), Some(payload)) =>
          println(@MoonHook.sign_hmac_sha256(secret, payload))
        _ => print_usage()
      }
    "verify" =>
      match (arg_at(args, 2), arg_at(args, 3), arg_at(args, 4)) {
        (Some(secret), Some(payload), Some(signature)) =>
          println(
            @MoonHook.verify_hmac_sha256(secret, payload, signature).to_string(),
          )
        _ => print_usage()
      }
    "request" =>
      match
        (arg_at(args, 2), arg_at(args, 3), arg_at(args, 4), arg_at(args, 5)) {
        (Some(hook_id), Some(url), Some(secret), Some(payload)) =>
          run_request(hook_id, url, secret, payload)
        _ => print_usage()
      }
    "help" => print_usage()
    _ => print_usage()
  }
}
