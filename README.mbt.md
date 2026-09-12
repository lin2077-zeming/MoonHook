# MoonHook

![CI](https://github.com/lin2077-zeming/MoonHook/actions/workflows/ci.yml/badge.svg)

**WebHook 投递（出站）框架**，使用 MoonBit 编写：把事件可靠、可验证地送到接收端，
并记录每一次尝试。核心能力包括事件建模、Hook 注册、HMAC-SHA256 签名与验签、
时间戳防重放、重试策略、投递引擎、Outbox、死信队列、幂等去重和审计日志。
核心代码为纯 MoonBit 实现，不依赖 FFI，也不依赖第三方密码学库。

在此之上，`transport_http` 包基于 `moonbitlang/async` 提供**真实 HTTP 投递**：
签名请求会真正 POST 到接收端，重试会按退避策略真实等待，接收端可以直接用
`webhook_receiver` 挂到 `@http.Server` 上完成验签。

本项目专注**投递侧**：入站只提供最小验签处理器，不做路由、中间件与平台入站适配。
功能边界、与生态中相邻项目的关系见 [docs/SCOPE.md](./docs/SCOPE.md)。

## 工程验证

```bash
moon check --deny-warn                      # 三个目标均 0 warning
moon test --deny-warn                       # 66 个测试
moon check --target wasm-gc --deny-warn     # 核心包保持可移植
moon check --target js --deny-warn
moon test --enable-coverage                 # 覆盖率：库代码约 91%
moon coverage report -f summary
moon run cmd/httpdemo -- e2e                # 真实 HTTP 投递 + 验签，端到端
```

CI 在 native / wasm-gc / js 三个目标上执行 `check` 与 `test`，并校验
`moon fmt --check`、`moon info` 生成的接口与仓库一致，最后跑一遍 `e2e` 冒烟测试。

## 核心功能

- `WebhookEvent` / `Hook` 数据模型与校验式 Builder
- `HookRegistry` 注册表：注册、查询、去重、校验
- 纯 MoonBit SHA-256，通过标准测试向量
- HMAC-SHA256 签名与常量时间验签
- 时间戳签名 `sign_webhook` / `verify_webhook`，支持防重放窗口
- 接收端验签：大小写不敏感 header、`sha256=` 前缀兼容
- `RetryPolicy`：不重试、固定间隔、指数退避，参数校验
- `DeliveryEngine`：首投成功、重试后成功、耗尽后死信、非可重试失败、跳过
- `InMemoryOutbox` / `InMemoryDeadLetter`：待投递队列与死信队列
- `IdempotencyStore`：TTL 幂等去重与过期清理
- `AuditLog`：投递尝试审计与最近记录查询
- Hook / 待投递 / 死信 JSON 序列化与反序列化
- `transport_http`：基于 `moonbitlang/async/http` 的真实 HTTP 投递
  （`post_signed_request`、`http_transport`）
- `AsyncDeliveryEngine`：异步投递引擎，按 `RetryPolicy::next_delay_ms`
  在两次尝试之间真正 sleep，而不是背靠背重试
- `webhook_receiver`：接收端处理器，读 body、验签、校验时间戳窗口并回 200/401
- 演示 CLI：内存流水线、签名、验签、请求构建，以及 HTTP 收发演示

## 快速开始

```bash
moon test                          # 核心测试 + HTTP 集成测试
moon run cmd/main -- demo          # 内存流水线演示
moon run cmd/main -- sign <secret> <payload>
moon run cmd/main -- verify <secret> <payload> <signature>
moon run cmd/main -- request <hook-id> <url> <secret> <payload>

moon run cmd/httpdemo -- e2e       # 起接收端 + 真实投递 + 验签，一条命令跑通
moon run cmd/httpdemo -- serve 127.0.0.1:8080 <secret>
moon run cmd/httpdemo -- deliver <url> <secret> <payload>
```

`demo` 命令会在内存中完成“注册 Hook -> 构建事件 -> 签名 -> 投递 -> 审计”
的完整流程；`request` 命令会打印一个带签名和时间戳 header 的 HTTP 请求。

`e2e` 命令在同一个进程里启动 MoonHook 接收端，再通过 HTTP 投递一个签名事件，
并把收发两侧的结果都打印出来：

```text
[receiver] listening on http://127.0.0.1:18080/hooks/orders
[sender]   POST http://127.0.0.1:18080/hooks/orders
[sender]   attempt 1: HTTP 200 in 2ms
[sender]   status: success
[receiver] verified payloads: 1
[receiver] payload: {"order_id": "A-1001", "total": 99}
```

## 真实 HTTP 投递

发送端把 `Hook` 和 `WebhookEvent` 交给 `AsyncDeliveryEngine`，每次尝试都会通过
`http_transport()` 真正发出请求：

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

接收端把 `webhook_receiver` 直接挂到 `@http.Server` 上，验签和时间戳窗口由
MoonHook 负责：

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

重试语义：2xx 视为成功；408、425、429 与 5xx 视为可重试失败；其他 4xx 直接进入
死信；连接层错误（DNS、拒绝连接等）同样可重试。每次尝试的状态码与耗时都会记录
在 `DeliveryOutcome::attempts` 中。

### 目标平台

- 核心包（事件、签名、重试、引擎、存储）保持平台无关，CI 额外验证 `wasm-gc`
  与 `js`，`DeliveryEngine` 在这些目标上照常可用。
- `transport_http` 依赖 `moonbitlang/async` 的原生 IO，因此声明
  `supported_targets = "+native"`，只在 native 目标上参与构建。

## 收发两侧验签

发送方用 `build_signed_request` 构建请求，签名覆盖
`"<timestamp_ms>.<payload>"`，并携带 `X-MoonHook-Timestamp`：

```moonbit nocheck
///|
let request = @MoonHook.build_signed_request(hook, event)
```

接收方用同一个 secret 校验签名和时间窗口：

```moonbit nocheck
///|
let valid = @MoonHook.verify_webhook_request_with_timestamp(
  secret, headers, body, now_ms, 300_000,
)
```

如果接入 GitHub 等外部 WebHook，签名通常是原始 body 的 `sha256=<hex>`
形式，可用 `verify_webhook_request` 直接校验：

```moonbit nocheck
///|
let valid = @MoonHook.verify_webhook_request(secret, headers, body)
```

## 代码结构

```text
event.mbt         # 事件模型与 EventBuilder
hook.mbt          # Hook 模型与配置 Builder
registry.mbt      # Hook 注册表
retry.mbt         # 重试策略、退避计算与参数校验
sha256.mbt        # 纯 MoonBit SHA-256
hmac.mbt          # HMAC-SHA256 签名与验签
transport.mbt     # 投递结果与 Transport 抽象
engine.mbt        # DeliveryEngine 投递引擎
store.mbt         # Outbox 与死信队列
idempotency.mbt   # 幂等键存储
audit.mbt         # 审计日志
request.mbt       # 签名请求构建与接收端验签
json_codec.mbt    # 领域模型 JSON 序列化
coordinator.mbt   # MoonHook 高层门面
transport_http/   # 真实 HTTP 投递适配（native）：传输、异步引擎、接收端处理器
cmd/main/         # 内存演示 CLI
cmd/httpdemo/     # HTTP 收发演示 CLI（native）
```

## 设计说明

投递链路以 `Transport` 函数为边界，HTTP、测试替身或进程内 Sink 都可以接入：

```moonbit nocheck
///|
pub type Transport = (Hook, WebhookEvent) -> DeliveryResult
```

`DeliveryEngine` 根据 Hook 的 `RetryPolicy` 和 `max_attempts` 决定继续重试
还是进入死信。同步引擎背靠背执行尝试，退避延迟由
`RetryPolicy::next_delay_ms` 提供给外部调度器；需要真实网络投递时改用
`transport_http` 中的 `AsyncDeliveryEngine`，它会等待每次 HTTP 尝试完成，并在
两次尝试之间按同一个策略真正 sleep。

接收端与发送端共用一套验签实现：`build_signed_request` 签名
`"<timestamp_ms>.<payload>"`，`webhook_receiver` 用同一个 secret 校验签名和
时间窗口，因此“自己发、自己收”的端到端演示和接入外部系统走的是同一条代码路径。

## Roadmap

- [x] HTTP 传输适配与端到端示例（`transport_http`，基于 `moonbitlang/async`）
- [ ] 文件或 SQLite 持久化 Outbox / 死信（JSON 序列化已就绪）
- [ ] 定时调度器按退避策略执行重试（`AsyncDeliveryEngine` 已支持等待退避）
- [ ] WebHook 注册与管理的 HTTP API
- [ ] 连接复用（`@http.Client`）与代理支持
- [ ] 错误类型化与覆盖率补强

## License

Apache-2.0
