# Story 003：get_achievements 查询 + 图鉴集成

> **Epic**: achievement-system
> **Story**: 003
> **Type**: Integration
> **ADR**: ADR-0012
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 AchievementSystem 的查询和图鉴集成 API——get_unlocked_achievements（委托 ProgressionSystem.get_achievements 按 unlocked 过滤）、get_achievement_summary（返回 {total, unlocked, categories: {category: {unlocked, total}}}）、get_hidden_achievements（返回 hidden_until_unlocked=true 且未解锁的成就列表）、get_achievement_progress（返回进度条数据）。

## 验收标准

| # | AC |
|---|---|
| 1 | get_unlocked_achievements() 返回已解锁成就列表（从 ProgressionSystem 读取）|
| 2 | get_achievement_summary() 返回 {total: 62, unlocked: N, categories: {...}} |
| 3 | summary 中每个 category 含 {unlocked, total} |
| 4 | get_hidden_achievements() 返回 hidden_until_unlocked=true 且未解锁的成就 |
| 5 | get_hidden_achievements 不包含已解锁的隐藏成就 |
| 6 | get_achievement_progress("ach_elite_hunter") 返回 {current, target} |
| 7 | get_achievement_progress 无进度的成就返回 null |
| 8 | summary 中 total = 62 |
| 9 | get_unlocked_achievements 按 unlocked_at DESC 排序 |
| 10 | get_achievement_progress("ach_elite_hunter") 达到 target 时 progress.current = target |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/achievement_system.gd` | 查询 + 图鉴集成 API |
| `tests/unit/achievement_system/test_query_and_gallery.gd` | 10 条 AC 测试 |

## GDD 来源

- GDD achievement-system.md §5 图鉴集成
- ADR-0012 §achievements 领域 get_achievements
