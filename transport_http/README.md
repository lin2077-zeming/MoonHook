# MoonHook / transport_http

`transport_http` 把 MoonHook 的投递抽象接到真实 HTTP 上：签名请求会真正 POST
出去，重试会按 `RetryPolicy` 真实等待，接收端可以直接把验签处理器挂到
`@http.Server`。

实现基于 [`moonbitlang/async`](https://mooncakes.io/docs/moonbitlang/async)，
因此本包声明 `supported_targets = "+native"`，只在 native 目标上参与构建。核心包
保持平台无关，wasm-gc 与 js 上仍可正常使用 `DeliveryEngine` 与验签 API。

## 发送端：真实投递

`http_transport()` 会为每个事件调用 `build_signed_request` 生成签名请求；
`AsyncDeliveryEngine` 的语义与同步 `DeliveryEngine` 一致（查找 Hook、重试、死信），
区别是它会等待每次 HTTP 尝试，并在两次尝试之间按策略真正 sleep：

```moonbit nocheck
///|
async fn main {
  let registry = @MoonHook.HookRegistry::new()
  let hook = @MoonHook.Hook::new("orders", "https://example.com/hooks/orders")
    .with_secret("shared-secret")
    .with_retry_policy(@MoonHook.RetryPolicy::Exponential(200, 2.0, 5_000))
    .with_max_attempts(5)
  registry.register(hook) |> ignore
  let engine = @transport_http.AsyncDeliveryEngine::new(
    registry,
    @transport_http.http_transport(),
  )
  let outcome = engine.deliver("orders", event)
  println(outcome.status.describe())
}
```

需要复用连接或走代理时，也可以只取单次尝试：

```moonbit nocheck
///|
let result = @transport_http.post_signed_request(
  @MoonHook.build_signed_request(hook, event),
)
```

## 接收端：验签

`webhook_receiver` 读取请求体、校验 `X-MoonHook-Signature` 与
`X-MoonHook-Timestamp` 时间窗口，通过则回 `200` 并把 payload 交给回调，
否则回 `401`：

```moonbit nocheck
///|
async fn main {
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:8080"))
  server.run_forever(
    @transport_http.webhook_receiver("shared-secret", 300_000, payload => {
      println("verified webhook: \{payload}")
    }),
  )
}
```

## 重试语义

| 响应 | 处理 |
| --- | --- |
| 2xx | 成功，记录接收端返回的状态码与耗时 |
| 408 / 425 / 429 / 5xx | 可重试失败，按 `RetryPolicy::next_delay_ms` 等待后重试 |
| 其他 4xx | 终止，直接进入死信 |
| DNS、拒绝连接等连接层错误 | 可重试失败 |

每次尝试的状态码与耗时都记录在 `DeliveryOutcome::attempts` 中。

## 端到端演示

仓库自带一个不依赖外部服务的演示：它在同一进程里启动 MoonHook 接收端，再通过
HTTP 投递一个签名事件，并打印收发两侧结果。

```bash
moon run cmd/httpdemo -- e2e
```

```text
[receiver] listening on http://127.0.0.1:18080/hooks/orders
[sender]   POST http://127.0.0.1:18080/hooks/orders
[sender]   attempt 1: HTTP 200 in 2ms
[sender]   status: success
[receiver] verified payloads: 1
[receiver] payload: {"order_id": "A-1001", "total": 99}
```

也可以拆成两个进程：一个 `serve`，另一个 `deliver`。

## 测试

`transport_http` 的集成测试会启动真实的本地 HTTP 服务端，覆盖成功投递并验签、
500 之后重试成功、错误 secret 被拒绝、超窗重放被拒绝。

```bash
moon test
```
