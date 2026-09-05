# Story 019: formation_system.gd 拆分——部署/覆盖/条件重判提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Feature
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `formation_system.gd`（535 行）中的阵法部署域（deploy_formation / overwrite_formation / recheck_all_conditions / _on_field_changed）提取到 `src/feature/formation/formation_slot_ops.gd` RefCounted 子模块，主文件降至 ~435 行。

## 技术需求

- **TR-ID**: TR-formation（阵法系统）
- **治理 ADR**: ADR-0024（FormationSystem）

## 验收标准

- [x] `formation_slot_ops.gd` 子模块包含部署域 4 方法（deploy_formation / overwrite_formation / recheck_all_conditions / on_field_changed）
- [x] 子模块自带 SlotState 枚举值常量（避免依赖父节点枚举）
- [x] 信号发射经 `_parent.call("_emit_safe", ...)` 路由（信号声明仍在 FormationSystem，Cat 2b）
- [x] 效果注册/移除经 `_parent.call("_invoke_cb", _parent.get("effect_register_cb"), ...)` 访问可注入存根
- [x] 主文件保留 4 个薄委托（测试经 `fs.call("deploy_formation")` / `_on_field_changed` 动态分派）
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `formation_slot_ops.gd` | 保留在 `formation_system.gd` |
|---|---|
| deploy_formation / overwrite_formation / recheck_all_conditions / on_field_changed | 枚举/6 信号/7 可注入存根/归属管理/查询 API/_check_condition/序列化+光环委托/_emit_safe |

## 范围外

- 不修改归属管理逻辑（set/clear_character_affilation）
- 不修改查询 API 与光环子模块
- 不修改信号声明与可注入存根定义

## 变更文件

- `src/feature/formation/formation_slot_ops.gd` — 新增（~161 行）
- `src/feature/formation_system.gd` — 修改（535→~435 行）
