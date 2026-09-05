# Story 010: binding_manager.gd 拆分——槽位操作提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Feature
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `binding_manager.gd` 中的槽位查询与本命判定逻辑提取到 `src/feature/binding/binding_slot_ops.gd` RefCounted 子模块（代码随 3bd47f8 提交）。

## 技术需求

- **TR-ID**: TR-binding（绑定系统）
- **治理 ADR**: ADR-0012（BindingManager）

## 验收标准

- [x] `binding_slot_ops.gd` 子模块包含槽位查询/本命判定方法
- [x] 子模块持有 `_parent: Node` 引用，通过 `_parent.get()` / `_parent.call()` 访问绑定注册表
- [x] 主文件保留薄委托（绑定核心 CRUD 逻辑不变）
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `binding_slot_ops.gd` | 保留在 `binding_manager.gd` |
|---|---|
| 槽位查询 / 本命判定 | 绑定 CRUD / 信号发射 / 序列化 / 挂起恢复 |

## 范围外

- 不修改绑定 CRUD 逻辑
- 不修改信号声明（Cat 2b 信号仍在 BindingManager）

## 变更文件

- `src/feature/binding/binding_slot_ops.gd` — 新增
- `src/feature/binding/binding_manager.gd` — 修改（700 行）
