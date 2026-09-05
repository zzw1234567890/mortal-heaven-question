# Story 018: deployment_system.gd 拆分——信号发射包装提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Feature
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `deployment_system.gd`（594 行）中的 6 个 Cat 2b 信号发射包装方法提取到 `src/feature/deployment/deployment_emitter.gd` RefCounted 子模块。

## 技术需求

- **TR-ID**: TR-deploy-001（阵位布局与上场管理）
- **治理 ADR**: ADR-0016（DeploymentSystem）/ ADR-0007（_emit_signal_safe 路由）

## 验收标准

- [x] `deployment_emitter.gd` 子模块包含 6 个信号发射包装方法
- [x] `deployment_system.gd` 通过 `_get_emitter()` 惰性委托
- [x] 子模块持有 `_parent: Node` 引用，信号 owner 为 `_parent`
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `deployment_emitter.gd` | 保留在 `deployment_system.gd` |
|---|---|
| `emit_character_deployed` / `emit_character_removed` / `emit_front_line_breached` / `emit_standby_cleared` / `emit_character_unavailable` / `emit_character_revived` | 枚举/常量/信号声明/阵位数据/备战/查询/待命状态机/补位/保护查询/不可用生命周期 + 薄委托 |

## 范围外

- 不修改信号声明（信号仍声明在 DeploymentSystem 上）
- 不修改序列化子模块（deployment_serializer.gd）
- 不修改阵位分配子模块（deployment_slot_allocator.gd）

## 变更文件

- `src/feature/deployment/deployment_emitter.gd` — 新增（~60 行）
- `src/feature/deployment_system.gd` — 修改（594→~530 行）