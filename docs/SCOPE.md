# MoonHook 功能边界与定位

## 一句话定位

MoonHook 是一个 **WebHook 投递（出站 / egress）框架**：把事件可靠地、可验证地
送到接收端，并记录每一次尝试。

## 在范围内

- 出站投递链路：事件建模 → 签名 → 投递 → 重试 → 死信 → 审计
- 真实 HTTP 投递（`transport_http`，基于 `moonbitlang/async`，native 目标）
- 收发两侧共用的签名与验签：HMAC-SHA256、时间戳防重放、常量时间比较
- 出站平台签名适配：GitHub、Stripe、Slack、飞书自定义机器人、Shopify，
  一键生成平台要求的签名头（`SignatureProvider`）
- 可靠性组件：`InMemoryOutbox`、死信队列、TTL 幂等去重、审计日志、JSON 序列化
- 接收端最小处理器 `webhook_receiver`：验签 + 时间窗校验 + `200` / `401`

## 明确不在范围内

- **入站路由与中间件管线**：不做 `router` / `middleware` / 平台事件分发
- **多平台入站载荷适配**：不解析 GitHub / GitLab / 飞书 / 企业微信 / Stripe 的
  业务字段；载荷由调用方定义，项目只提供通用的 `WebhookEvent` 模型。
  平台适配在本项目里指**出站签名**与**验签**，不含事件语义解析
- **不绑定运行时**：不在库内启动 HTTP 服务器或事件循环，服务器由调用方提供
  （仓库内的演示 CLI 只是为了可复现地展示投递链路）
- **持久化后端**：当前提供内存 Outbox / 死信与 JSON 编解码，文件或 SQLite
  后端在 `docs/ROADMAP.md` 中

## 与生态中相邻项目的关系

MoonBit 生态中已经有面向**入站处理**（接收、验签、路由、平台载荷适配）的
WebHook 项目。MoonHook 的定位与之互补而非重叠：

| | 入站处理类项目 | MoonHook |
| --- | --- | --- |
| 方向 | 请求进来 → 业务事件 | 事件出去 → 可靠送达 |
| 要解决的核心问题 | 如何安全地解析与分发 | 如何不丢、不重、可追溯地送达 |
| 网络能力 | 通常只做协议解析 | 真实 HTTP 投递，含退避重试 |
| 可靠性组件 | 幂等、路由 | Outbox、死信、重试退避、审计 |

因此：需要"整套入站框架"时 MoonHook 不是替代品；需要把事件**发出去并保证送达**
时，MoonHook 提供完整的投递语义，并附带一个最小接收端验签处理器用于自测与对接。
`webhook_receiver` 的存在是为了让"自己发、自己收"这条链路可端到端验证，而不是要把
项目扩展成入站框架。

## 平台与依赖边界

- 核心包（事件、签名、重试、引擎、存储、审计、编解码）与平台无关，CI 在
  `wasm-gc` 与 `js` 上执行 `check` / `test`。
- `transport_http` 依赖 `moonbitlang/async` 的原生 IO，声明
  `supported_targets = "+native"`，只在 native 目标参与构建。
- 核心包不依赖第三方密码学库：SHA-256 与 HMAC 为纯 MoonBit 实现，并附带
  RFC 4231 测试向量。
- 唯一的第三方依赖是 `moonbitlang/async`（Apache-2.0），且只被 native HTTP
  适配层使用；`wasm-gc` / `js` 使用者不会引入它。
