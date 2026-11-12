///|
/// Builds an `@http` request handler that verifies incoming MoonHook requests.
///
/// The handler reads the request body, verifies the `X-MoonHook-Signature`
/// header against the shared secret, rejects timestamps outside
/// `tolerance_ms`, and forwards accepted payloads to `on_event`.
///
/// Mount it on a server:
///
/// ```moonbit nocheck
/// async fn main {
///   let server = @http.Server(@socket.Addr::parse("127.0.0.1:8080"))
///   server.run_forever(
///     @transport_http.webhook_receiver("shared-secret", 300_000, println),
///   )
/// }
/// ```
pub fn webhook_receiver(
  secret : String,
  tolerance_ms : Int32,
  on_event : (String) -> Unit,
) -> async (@http.Request, &@io.Reader, @http.ServerConnection) -> Unit {
  async fn(request, body, conn) {
    let payload = body.read_all().text()
    let headers : Array[(String, String)] = []
    for entry in request.headers {
      headers.push((entry.0.to_string(), entry.1))
    }
    let now_ms = @env.now().to_int()
    if @MoonHook.verify_webhook_request_with_timestamp(
        secret, headers, payload, now_ms, tolerance_ms,
      ) {
      on_event(payload)
      conn.send_response(200, "OK", extra_headers={
        "Content-Type": "text/plain",
      })
      conn.write_string("accepted")
    } else {
      conn.send_response(401, "Unauthorized", extra_headers={
        "Content-Type": "text/plain",
      })
      conn.write_string("invalid signature")
    }
    conn.end_response()
  }
}
