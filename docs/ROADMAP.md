# MoonHook 完善路线

当前版本已经具备事件模型、签名与验签、时间戳防重放、重试策略、投递引擎、
Outbox、死信、幂等、审计、JSON 序列化、高层门面，以及基于
`moonbitlang/async` 的真实 HTTP 投递。已完成：

- [x] 签名请求构建与接收端验签，让库真正可用于收发两侧。
- [x] JSON 序列化与导出/导入，为持久化和 HTTP API 打基础。
- [x] 高层 `MoonHook` 门面与队列调度，把注册、投递、死信、审计串成一条链。
- [x] 真实 HTTP 投递与端到端示例：`transport_http` 包提供 `http_transport`、
      `AsyncDeliveryEngine` 与 `webhook_receiver`，重试按退避策略真实等待，
      接收端验签可直接挂到 `@http.Server`。

下一阶段按价值排序：

1. 文件/SQLite 持久化 Outbox，支持重启恢复。
2. WebHook 注册与管理的 HTTP API。
3. 连接复用（`@http.Client`）、代理与 TLS 选项透传。
4. 错误类型化，用带上下文的错误类型替代字符串消息。
5. 包结构拆分与覆盖率补强。
