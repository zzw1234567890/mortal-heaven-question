# Story 016: status_effect_system.gd 拆分——免疫机制+施加管线提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Core
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `status_effect_system.gd`（484 行）中的免疫机制（3 个方法）与施加管线（apply_status + _find_existing + _evict_lowest）提取到两个子模块，主文件降至 ~380 行。

## 技术需求

- **TR-ID**: TR-status（状态效果生命周期）
- **治理 ADR**: ADR-0011（StatusEffectSystem）

## 验收标准

- [x] `status_effect_immunity.gd` 纯 static 子模块：set_immunity / clear_immunity / check_immunity（_immunity_flags Dictionary 引用传递，注册表留在主文件）
- [x] `status_effect_lifecycle.gd` RefCounted 子模块：apply_status 完整管线 + find_existing + evict_lowest
- [x] 信号发射经 `_parent.get("signal_name").emit(...)`（信号声明仍在 StatusEffectSystem，Cat 2b）
- [x] `_register_instance` / `_remove_instance` 保留主文件（snapshot/suspend 子模块经 `_parent.call` 动态调用）
- [x] 主文件保留 `_check_immunity` / `_find_existing` / `_evict_lowest` 薄委托（suspend 子模块 `_parent.call("_evict_lowest")` 依赖）
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `status_effect_immunity.gd`（static） | 提取到 `status_effect_lifecycle.gd`（_parent） | 保留在 `status_effect_system.gd` |
|---|---|---|
| set_immunity / clear_immunity / check_immunity | apply_status 管线 / find_existing / evict_lowest | 4 信号 / 注册表 / _register_instance / _remove_instance / tick_all / 模板加载 / 快照+暂挂+管线+免疫委托 |

## 范围外

- 不修改叠加规则逻辑与免疫 3 级短路语义
- 不修改信号声明
- 不拆 status_effect_snapshot.gd / status_effect_suspend.gd（Sprint 10 已拆分）

## 变更文件

- `src/core/status_effect/status_effect_immunity.gd` — 新增（~62 行）
- `src/core/status_effect/status_effect_lifecycle.gd` — 新增（~142 行）
- `src/core/status_effect/status_effect_system.gd` — 修改（484→~380 行）
