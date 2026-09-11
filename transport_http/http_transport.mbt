///|
/// A transport that performs one delivery attempt across an async IO boundary.
///
/// The synchronous `Transport` in the core package is driven by
/// `DeliveryEngine`; this async variant lets the same hook and event be
/// delivered over `moonbitlang/async` based HTTP clients.
pub type AsyncTransport = async (@MoonHook.Hook, @MoonHook.WebhookEvent) -> @MoonHook.DeliveryResult

///|
/// True when the receiver accepted the delivery.
fn is_success_status(status_code : Int) -> Bool {
  status_code >= 200 && status_code <= 299
}

///|
/// True for status codes that are worth another attempt: request timeout,
/// too early, rate limiting, and every server error.
fn is_retryable_status(status_code : Int) -> Bool {
  status_code == 408 ||
  status_code == 425 ||
  status_code == 429 ||
  (status_code >= 500 && status_code <= 599)
}

///|
/// Converts MoonHook's ordered header list into the case-insensitive header map
/// expected by `moonbitlang/async/http`.
fn to_http_headers(
  headers : Array[(String, String)],
) -> Map[@http.CaseInsensitiveString, String] {
  let result : Map[@http.CaseInsensitiveString, String] = Map([])
  for header in headers {
    result.set(@http.CaseInsensitiveString(header.0), header.1)
  }
  result
}

///|
/// Performs one signed POST attempt over HTTP and classifies the response.
///
/// 2xx responses report success. Timeouts, rate limits and server errors are
/// reported as retryable failures, so the retry policy of the hook decides
/// whether another attempt happens. Connection level errors, such as DNS or
/// refused connections, are retryable as well.
pub async fn post_signed_request(
  request : @MoonHook.SignedRequest,
) -> @MoonHook.DeliveryResult {
  let headers = to_http_headers(request.headers)
  let started = @async.now()
  let (response, body) = @http.post(request.url, request.body, headers~) catch {
    error =>
      return @MoonHook.DeliveryResult::failure(
        0,
        error.to_string(),
        (@async.now() - started).to_int(),
        true,
      )
  }
  ignore(body)
  let duration_ms = (@async.now() - started).to_int()
  let status_code = response.code
  if is_success_status(status_code) {
    @MoonHook.DeliveryResult::success_with_status(status_code, duration_ms)
  } else {
    @MoonHook.DeliveryResult::failure(
      status_code,
      "HTTP \{status_code} \{response.reason}",
      duration_ms,
      is_retryable_status(status_code),
    )
  }
}

///|
/// The default HTTP transport: signs each event and POSTs it with
/// `moonbitlang/async/http`.
pub fn http_transport() -> AsyncTransport {
  async fn(hook, event) {
    let request = @MoonHook.build_signed_request(hook, event)
    post_signed_request(request)
  }
}

///|
/// Async counterpart of `DeliveryEngine`.
///
/// It applies the same lookup, retry and dead letter semantics, but awaits
/// every attempt and sleeps for `RetryPolicy::next_delay_ms` between attempts.
/// The synchronous engine retries back to back and leaves the delay to an
/// external scheduler; this engine performs the wait itself, which is what a
/// real HTTP delivery needs.
pub struct AsyncDeliveryEngine {
  registry : @MoonHook.HookRegistry
  transport : AsyncTransport
}

///|
pub fn AsyncDeliveryEngine::new(
  registry : @MoonHook.HookRegistry,
  transport : AsyncTransport,
) -> AsyncDeliveryEngine {
  { registry, transport, }
}

///|
pub async fn AsyncDeliveryEngine::deliver(
  self : AsyncDeliveryEngine,
  hook_id : String,
  event : @MoonHook.WebhookEvent,
) -> @MoonHook.DeliveryOutcome {
  let attempts : Array[@MoonHook.DeliveryAttempt] = []
  match self.registry.get(hook_id) {
    None =>
      {
        hook_id,
        event_id: event.id,
        status: @MoonHook.DeliveryStatus::Skipped,
        attempts,
      }
    Some(hook) =>
      if !hook.active {
        {
          hook_id,
          event_id: event.id,
          status: @MoonHook.DeliveryStatus::Skipped,
          attempts,
        }
      } else {
        let max_attempts = hook.max_attempts
        let mut attempt_number = 1
        let mut final_status = @MoonHook.DeliveryStatus::DeadLetter
        while attempt_number <= max_attempts {
          let result = (self.transport)(hook, event)
          attempts.push({
            attempt: attempt_number,
            status_code: result.status_code,
            error: result.error,
            duration_ms: result.duration_ms,
          })
          if result.ok {
            final_status = @MoonHook.DeliveryStatus::Success
            break
          } else if !result.retryable ||
            !hook.retry_policy.should_retry(attempt_number, max_attempts) {
            final_status = @MoonHook.DeliveryStatus::DeadLetter
            break
          } else {
            let delay_ms = hook.retry_policy.next_delay_ms(attempt_number)
            if delay_ms > 0 {
              @async.sleep(delay_ms)
            }
            attempt_number = attempt_number + 1
          }
        }
        { hook_id, event_id: event.id, status: final_status, attempts, }
      }
  }
}
