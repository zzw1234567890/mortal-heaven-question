# Story 001：Achievement 实例 + 解锁状态管理

> **Epic**: achievement-system
> **Story**: 001
> **Type**: Logic
> **ADR**: ADR-0012
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 AchievementSystem RefCounted 服务类——62 个成就定义 const Dictionary（7 类别：combat 12 + progression 10 + collection 10 + exploration 8 + narrative 8 + mastery 8 + challenge 6）、初始化时注册全部成就到 ProgressionSystem.register_achievement()、get_achievement_definition / get_all_definitions 查询 API。委托 ProgressionSystem 管理解锁状态。

## 验收标准

| # | AC |
|---|---|
| 1 | ACHIEVEMENT_DEFS const 包含 62 个成就定义 |
| 2 | 7 个类别的成就数量正确（combat 12 + progression 10 + collection 10 + exploration 8 + narrative 8 + mastery 8 + challenge 6）|
| 3 | get_achievement_definition("ach_first_realm_break") 返回 {id, name, description, category, tier} |
| 4 | get_all_definitions() 返回全部 62 个定义 |
| 5 | get_definitions_by_category("combat") 返回 12 个战斗成就 |
| 6 | 每个成就定义包含 hidden_until_unlocked 字段 |
| 7 | 每个成就定义包含 unlock_condition 字段（含 event + threshold）|
| 8 | 每个成就定义包含 tier 字段（bronze/silver/gold）|
| 9 | initialize() 调用 ProgressionSystem.register_achievement() 注册全部 62 个 |
| 10 | get_definitions_by_category("narrative") 返回 8 个叙事成就 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/achievement_system.gd` | AchievementSystem RefCounted + ACHIEVEMENT_DEFS |
| `tests/unit/achievement_system/test_achievement_defs.gd` | 10 条 AC 测试 |

## GDD 来源

- GDD achievement-system.md §1 成就数据结构、§2 分类体系、§3 详细列表
- ADR-0012 §achievements 领域 register_achievement
