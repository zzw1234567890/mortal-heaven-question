# Story 017: tribulation_system.gd 拆分——渡劫战斗委托提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Feature
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `tribulation_system.gd`（437 行）中的渡劫战斗委托域（start_tribulation_combat / _build_tribulation_config / _on_battle_ended）提取到 `src/feature/tribulation/tribulation_combat.gd` RefCounted 子模块，主文件降至 ~400 行。

## 技术需求

- **TR-ID**: TR-tribulation（渡劫突破流程）
- **治理 ADR**: ADR-0021（TribulationSystem）

## 验收标准

- [x] `tribulation_combat.gd` 子模块包含战斗委托 3 方法（start_tribulation_combat / build_tribulation_config / on_battle_ended）
- [x] 子模块自带 TribulationState/TribulationType 枚举值常量（避免依赖父节点枚举）
- [x] 主文件保留 3 个薄委托（测试经 `ts.call("start_tribulation_combat")` / `_on_battle_ended` 动态分派）
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `tribulation_combat.gd` | 保留在 `tribulation_system.gd` |
|---|---|
| start_tribulation_combat / build_tribulation_config / on_battle_ended | 枚举/常量/5 信号/状态机（_set_state/_validate）/触发/取消/查询/渡劫丹/结算+雷伤+Boss 配置委托 |

## 范围外

- 不修改战斗委托逻辑（battle_start 调用契约）
- 不修改结算子模块（tribulation_settlement.gd）
- 不修改信号声明

## 变更文件

- `src/feature/tribulation/tribulation_combat.gd` — 新增（~94 行）
- `src/feature/tribulation_system.gd` — 修改（437→~400 行）
