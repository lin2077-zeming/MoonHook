///|
/// Shared secret used by the self-contained end-to-end demo.
const DEMO_SECRET : String = "moonhook-demo-secret"

///|
fn print_usage() -> Unit {
  println("MoonHook HTTP demo")
  println("  moon run cmd/http --target native -- e2e [port]")
  println("  moon run cmd/http --target native -- serve <addr> <secret>")
  println(
    "  moon run cmd/http --target native -- deliver <url> <secret> <payload>",
  )
  println("  moon run cmd/http --target native -- help")
}

///|
fn build_event(payload : String) -> @MoonHook.WebhookEvent {
  let built = @MoonHook.EventBuilder::new()
    .with_id("evt-http-demo")
    .with_event_type("order.created")
    .with_subject("order/42")
    .with_timestamp_ms(@env.now().to_int())
    .with_payload(payload)
    .build()
  match built {
    Ok(event) => event
    Err(message) => abort(message)
  }
}

///|
fn build_engine(
  url : String,
  secret : String,
  retry_ms : Int,
  max_attempts : Int,
) -> @transport_http.AsyncDeliveryEngine {
  let registry = @MoonHook.HookRegistry::new()
  let hook = @MoonHook.Hook::new("orders", url)
    .with_secret(secret)
    .with_retry_policy(@MoonHook.RetryPolicy::Fixed(retry_ms))
    .with_max_attempts(max_attempts)
  registry.register(hook) |> ignore
  @transport_http.AsyncDeliveryEngine::new(
    registry,
    @transport_http.http_transport(),
  )
}

///|
fn report(outcome : @MoonHook.DeliveryOutcome) -> Unit {
  for attempt in outcome.attempts {
    println(
      "[sender]   attempt \{attempt.attempt}: HTTP \{attempt.status_code} in \{attempt.duration_ms}ms",
    )
  }
  println("[sender]   status: \{outcome.status.describe()}")
}

///|
async fn run_e2e(port : Int) -> Unit {
  let received : Array[String] = []
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:\{port}"))
    let bound_port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever(
        @transport_http.webhook_receiver(DEMO_SECRET, 300_000, payload => {
          received.push(payload)
        }),
      )
    }
    let url = "http://127.0.0.1:\{bound_port}/hooks/orders"
    println("[receiver] listening on \{url}")
    let engine = build_engine(url, DEMO_SECRET, 50, 3)
    let payload = "{\"order_id\": \"A-1001\", \"total\": 99}"
    println("[sender]   POST \{url}")
    let outcome = engine.deliver("orders", build_event(payload))
    report(outcome)
    println("[receiver] verified payloads: \{received.length()}")
    if received.length() > 0 {
      println("[receiver] payload: \{received[0]}")
    }
  }
}

///|
async fn run_serve(addr : String, secret : String) -> Unit {
  let server = @http.Server(@socket.Addr::parse(addr))
  println("MoonHook receiver listening on \{addr}; press Ctrl+C to stop")
  server.run_forever(
    @transport_http.webhook_receiver(secret, 300_000, payload => {
      println("[receiver] accepted: \{payload}")
    }),
  )
}

///|
async fn run_deliver(url : String, secret : String, payload : String) -> Unit {
  let engine = build_engine(url, secret, 200, 3)
  let outcome = engine.deliver("orders", build_event(payload))
  report(outcome)
}

///|
async fn main {
  let args = @env.args()
  let command = if args.length() > 1 { args[1] } else { "" }
  match command {
    "e2e" => {
      let port = if args.length() > 2 {
        @string.parse_int(args[2]) catch {
          _ => 18080
        }
      } else {
        18080
      }
      run_e2e(port)
    }
    "serve" =>
      if args.length() > 3 {
        run_serve(args[2], args[3])
      } else {
        print_usage()
      }
    "deliver" =>
      if args.length() > 4 {
        run_deliver(args[2], args[3], args[4])
      } else {
        print_usage()
      }
    _ => print_usage()
  }
}
