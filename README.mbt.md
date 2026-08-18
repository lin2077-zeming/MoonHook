# MoonHook

![CI](https://github.com/lin2077-zeming/MoonHook/actions/workflows/ci.yml/badge.svg)

轻量级 WebHook 投递框架，使用 MoonBit 编写。核心能力包括事件建模、Hook
注册、HMAC-SHA256 签名与验签、时间戳防重放、重试策略、投递引擎、Outbox、
死信队列、幂等去重和审计日志，全部为纯 MoonBit 实现，不依赖 FFI。

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
- 演示 CLI：完整流水线、签名、验签、请求构建

## 快速开始

```bash
moon test
moon run cmd/main -- demo
moon run cmd/main -- sign <secret> <payload>
moon run cmd/main -- verify <secret> <payload> <signature>
moon run cmd/main -- request <hook-id> <url> <secret> <payload>
```

`demo` 命令会在内存中完成“注册 Hook -> 构建事件 -> 签名 -> 投递 -> 审计”
的完整流程；`request` 命令会打印一个带签名和时间戳 header 的 HTTP 请求。

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
cmd/main/         # 演示 CLI
```

## 设计说明

投递链路以 `Transport` 函数为边界，HTTP、测试替身或进程内 Sink 都可以接入：

```moonbit nocheck
///|
pub type Transport = (Hook, WebhookEvent) -> DeliveryResult
```

`DeliveryEngine` 根据 Hook 的 `RetryPolicy` 和 `max_attempts` 决定继续重试
还是进入死信。当前引擎是同步执行，退避延迟由 `RetryPolicy::next_delay_ms`
提供给外部调度器。

## Roadmap

- HTTP 传输适配（`moonbitlang/async` / `mooncat`）
- 文件或 SQLite 持久化 Outbox / 死信（JSON 序列化已就绪）
- 定时调度器按退避策略执行重试
- WebHook 注册与管理的 HTTP API
- 发布到 mooncakes.io 并补充 CI 覆盖

## License

Apache-2.0
