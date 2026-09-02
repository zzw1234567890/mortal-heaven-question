# Story 002：achievements 领域 API（unlock/get/update_progress）

> **Epic**: progression-system
> **Story**: 002
> **Type**: Logic
> **ADR**: ADR-0012
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 ProgressionSystem 的 achievements 领域 API——unlock_achievement（写入 unlocked_at + 发射 achievement_unlocked 信号）、get_achievement（返回成就状态 Dictionary）、get_achievements（按 category 过滤 + 已解锁优先排序）、update_achievement_progress（跨局累计递增 + 达到 target 时自动解锁）。

## 验收标准

| # | AC |
|---|---|
| 1 | unlock_achievement("ach_test") → {success: true}，写入 unlocked_at 时间戳 |
| 2 | unlock_achievement 重复解锁 → {success: false, reason: "already_unlocked"} |
| 3 | get_achievement("ach_test") 返回 {id, unlocked, unlocked_at} |
| 4 | get_achievements() 返回全部成就数组，已解锁按 unlocked_at DESC 排序 |
| 5 | get_achievements("combat") 按 category 过滤 |
| 6 | update_achievement_progress("ach_cumulative", 5) 递增进度 current=5 |
| 7 | update_achievement_progress 达到 target 时自动调用 unlock_achievement |
| 8 | unlock_achievement 后 _dirty = true |
| 9 | unlock_achievement 发射 achievement_unlocked(ach_id) 信号 |
| 10 | unlock_achievement("unknown") → {success: false, reason: "unknown_id"} |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/meta/progression_system.gd` | achievements 领域 API |
| `tests/unit/progression_system/test_achievements_api.gd` | 10 条 AC 测试 |

## GDD 来源

- ADR-0012 §关键接口（achievements 领域）
- GDD achievement-system.md §1 成就数据结构
