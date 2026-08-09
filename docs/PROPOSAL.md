# MoonHook 项目申报书

## 项目名称

MoonHook：轻量级 WebHook 投递框架

## 项目简介

MoonHook 是一个使用 MoonBit 编写的 WebHook 投递框架，覆盖事件建模、Hook
注册、HMAC-SHA256 签名、重试投递、Outbox、死信、幂等去重与审计日志的完整
链路。核心代码为纯 MoonBit 实现，不依赖 C FFI，可用于支付回调、CI 通知、
SaaS 集成、消息推送等场景。

## 项目方向与适用场景

- 官方方向：Web 与网络基础设施 / 轻量 WebHook 处理框架
- 适用场景：需要可靠投递、签名校验、重试与失败回放的 WebHook 服务

## 拟实现的核心功能

- 事件与 Hook 数据模型、校验与注册表
- 纯 MoonBit SHA-256 与 HMAC-SHA256 签名/验签
- 固定与指数退避重试策略
- 同步投递引擎、Outbox 与死信队列
- TTL 幂等去重与审计日志
- 演示 CLI、README、CI 与单元测试

## 原创/移植说明

本项目为原创 MoonBit 项目，不直接移植或复制其他语言实现。SHA-256 与 HMAC
按照公开标准（FIPS 180-4 / RFC 2104）重新实现，并通过 RFC 4231 测试向量。

## 仓库链接

- GitHub：https://github.com/lin2077-zeming/MoonHook
- Gitlink：待同步（与 GitHub 保持镜像一致）

## 验收计划

- 有效 MoonBit 代码与单元测试，`moon test` 可运行
- README 说明用途、功能与使用方法
- GitHub Actions CI 执行 `moon check` 与 `moon test`
- 演示 CLI `moon run cmd/main -- demo` 可直接运行
- 后续发布至 mooncakes.io，并补充 HTTP 传输适配与持久化存储
