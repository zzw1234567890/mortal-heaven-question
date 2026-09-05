# Story 011: exploration_system.gd 拆分——结算刷新提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Feature
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `exploration_system.gd`（681 行）中的探索结算/资源刷新逻辑提取到 `src/feature/exploration/exploration_map_flush.gd` RefCounted 子模块，主文件降至 ~560 行。

## 技术需求

- **TR-ID**: TR-explore-003（地图经济模型——重入传送费 + 境界差额惩罚 + 永久免费地图安全阀）
- **治理 ADR**: ADR-0014（ExplorationSystem Autoload）

## 验收标准

- [x] `exploration_map_flush.gd` 子模块包含资源收集/刷新/结算方法
- [x] `exploration_system.gd` 通过 `_get_map_flush()` 惰性委托给子模块
- [x] 子模块持有 `_parent: Node` 引用
- [x] 现有测试全部通过（零回归）
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `exploration_map_flush.gd` | 保留在 `exploration_system.gd` |
|---|---|
| `collect_resource` / `_flush_map_state` / `_flush_map_state_half_cultivation` / `end_exploration` / `_is_map_cleared` / `_mark_map_cleared` / `_get_player_realm` / `_get_map_max_realm` | 枚举/常量/状态/DAG 生成委托/导航/经济计算委托 + 薄委托 |

## 范围外

- 不修改 DAG 生成逻辑
- 不修改导航逻辑（move_to_node / can_move_to / resolve_node）
- 不修改经济计算子模块（exploration_economy.gd）

## 变更文件

- `src/feature/exploration/exploration_map_flush.gd` — 新增
- `src/feature/exploration_system.gd` — 修改（委托给子模块）