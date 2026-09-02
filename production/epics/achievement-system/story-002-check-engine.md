# Story 002：check(criteria) 判定引擎

> **Epic**: achievement-system
> **Story**: 002
> **Type**: Logic
> **ADR**: ADR-0012
> **Status": Done
> **Estimate**: 0.5d

## 描述

实现 AchievementSystem 的判定引擎——check_achievements(event_name, current_value) 扫描全部成就定义，匹配 unlock_condition.event + threshold 的成就，达到阈值时调用 ProgressionSystem.unlock_achievement 或 update_achievement_progress。支持 extra_checks 精确匹配（如结局线 ID、流派 ID）。跨局累计型成就使用 update_achievement_progress 递增。

## 验收标准

| # | AC |
|---|---|
| 1 | check_achievements("elite_defeated", 1) 触发 ach_first_elite_kill 解锁 |
| 2 | check_achievements("elite_defeated", 50) 触发 ach_elite_hunter 解锁 |
| 3 | check_achievements("realm_upgraded", 3) 触发 ach_realm_golden_core 解锁 |
| 4 | check_achievements("elite_defeated", 5) 递增 ach_elite_hunter 进度到 5/50 |
| 5 | check_achievements 未匹配任何成就时无操作 |
| 6 | check_achievements("ending_unlocked", 1, "ascend") 使用 extra 匹配 ach_ending_ascension |
| 7 | check_achievements("ending_unlocked", 1, "guard") 匹配 ach_ending_guardian 而非 ach_ending_ascension |
| 8 | check_achievements 返回已解锁的 ach_id 列表 |
| 9 | 已解锁的成就不重复解锁（幂等）|
| 10 | 跨局累计型成就使用 update_achievement_progress 而非 unlock_achievement |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/achievement_system.gd` | check_achievements 判定引擎 |
| `tests/unit/achievement_system/test_check_engine.gd` | 10 条 AC 测试 |

## GDD 来源

- GDD achievement-system.md §4 成就触发机制
- ADR-0012 §achievements 领域 unlock_achievement / update_achievement_progress
