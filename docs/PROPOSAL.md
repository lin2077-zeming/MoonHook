# MoonHook 项目申报书

## 基本信息

项目名称：MoonHook：轻量级 WebHook 投递框架

参赛者：lin2077-zeming

联系方式：438051102@qq.com

GitHub 仓库链接：https://github.com/lin2077-zeming/MoonHook

Gitlink 仓库链接：https://gitlink.org.cn/linDavid/MoonHook.git

项目方向：Web 与网络基础设施 / 轻量 WebHook 处理框架

是否为移植项目：否（原创项目）

## 项目简介

MoonHook 计划以 MoonBit 为唯一实现语言，构建一个轻量、可靠、可扩展的
WebHook 投递框架，为支付回调、CI/CD 通知、SaaS 集成、消息推送、事件驱动
应用等场景提供开箱即用的投递基础设施。项目面向需要在 MoonBit 中接收或转发
WebHook 的库作者、工具开发者和应用开发者，提供事件建模、Hook 注册、
HMAC-SHA256 签名与验签、重试策略、投递引擎、Outbox、死信队列、幂等去重和
审计日志等能力。核心代码全部为纯 MoonBit 实现，不依赖 C FFI，便于在
native、wasm-gc、js 等目标上复用。

## 核心功能范围

- 提供 `WebhookEvent` / `Hook` 数据模型与校验式 Builder，明确事件 ID、类型、
  主题、载荷、时间戳和幂等键；
- 提供 `HookRegistry` 注册表，支持注册、查询、去重、启停状态与配置校验；
- 提供纯 MoonBit SHA-256 与 HMAC-SHA256 签名/验签，并通过 RFC 4231 标准测试
  向量；
- 提供 `RetryPolicy`：不重试、固定间隔、指数退避，支持退避延迟计算与最大尝试
  次数；
- 提供统一投递入口 `DeliveryEngine::deliver(...)`，支持首投成功、重试后成功、
  耗尽后死信、非可重试失败和跳过；
- 提供 `Transport` 传输抽象，测试替身与真实 HTTP 适配器可平滑替换；
- 提供 `InMemoryOutbox` 与 `InMemoryDeadLetter`，支持待投递队列与死信回放；
- 提供 `IdempotencyStore`，支持 TTL 幂等去重与过期清理；
- 提供 `AuditLog`，记录每次投递尝试的状态、错误与耗时；
- 提供演示 CLI，覆盖 `demo`、`sign`、`verify` 命令；
- 提供 README 示例、GitHub Actions CI、单元测试与 mooncakes 发布元数据；
- 后续计划补充 HTTP 传输适配、文件/SQLite 持久化、退避调度器和 WebHook
  管理 API。

## 移植或参考说明

本项目为原创 MoonBit 项目，不移植或复制其他语言实现。

- 原项目名称：无（原创）
- 参考标准：FIPS 180-4（SHA-256）、RFC 2104（HMAC）、RFC 4231
  （HMAC-SHA256 测试向量）
- 本项目许可证：Apache-2.0

与参考标准相比，本项目做了以下 MoonBit 化设计：

- 使用 MoonBit 原生包结构、类型系统、Builder 与测试方式组织代码，而不是依赖
  外部密码库；
- 以 `Transport` 函数类型作为投递边界，把 HTTP、测试替身和进程内 Sink 统一为
  同一接口；
- 以同步投递引擎配合退避策略计算作为当前交付形态，后续由调度器按策略延迟重试；
- 以内存 Outbox / 死信作为默认实现，存储层可替换为文件或 SQLite；
- 允许合理使用 AI 辅助代码生成、测试补全与文档撰写，最终由参赛者负责代码质量、
  功能边界与开源合规。

## 验收计划

- 有效 MoonBit 代码与单元测试，`moon test` 可运行；
- README 说明项目用途、主要功能与使用方法；
- GitHub Actions CI 执行 `moon check` 与 `moon test`；
- 演示 CLI `moon run cmd/main -- demo` 可直接运行；
- GitHub 仓库保持 10-20 个有效提交，提交按功能模块拆分；
- `moon publish --dry-run` 通过，最终发布至 mooncakes.io；
- Gitlink 仓库与 GitHub 保持同步。
