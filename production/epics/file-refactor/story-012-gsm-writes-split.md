# Story 012: gsm_atomic_writes.gd 拆分——叙事域写入提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Foundation
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `gsm_atomic_writes.gd`（646 行）中的叙事域写入方法提取到 `src/foundation/gsm/gsm_narrative_writes.gd` RefCounted 子模块，主文件降至 553 行（代码随 3bd47f8 提交）。

## 技术需求

- **TR-ID**: TR-gsm（全局状态管理器）
- **治理 ADR**: ADR-0005（GameStateManager）

## 验收标准

- [x] `gsm_narrative_writes.gd` 子模块包含叙事域写入方法（set_narrative_flag / advance_chapter / add_required_event_completion / set_narrative_boss_unlocked / set_narrative_boss_defeated / set_ending_chosen）
- [x] 子模块持有 `_gsm: Node` 引用，直接访问 `GSM.narrative.*`
- [x] 主文件委托区块转发（叙事域写入语义不变）
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `gsm_narrative_writes.gd` | 保留在 `gsm_atomic_writes.gd` |
|---|---|
| set_narrative_flag / advance_chapter / add_required_event_completion / set_narrative_boss_unlocked / set_narrative_boss_defeated / set_ending_chosen | player/resource/deck/combat/exploration 域原子写入 |

## 范围外

- 不修改写入去重与 buffer_change 机制
- 不修改其他域写入方法

## 变更文件

- `src/foundation/gsm/gsm_narrative_writes.gd` — 新增
- `src/foundation/gsm/gsm_atomic_writes.gd` — 修改（646→553 行）
