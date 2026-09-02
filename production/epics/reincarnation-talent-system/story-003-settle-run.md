# Story 003：settle_run 轮回结算（跨局天赋继承）

> **Epic**: reincarnation-talent-system
> **Story**: 003
> **Type**: Integration
> **ADR**: ADR-0012
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 ReincarnationTalentSystem 的轮回结算编排——calculate_reincarnation_points（境界²×2 + 通关 +10 + 击杀上限 + 收集 + 炼制 + 超脱轮回×1.2 + 死亡保底 3）、settle_run（计算轮回点 → add_talent_points → 递增 total_reincarnations → 返回结算摘要 Dictionary）。委托 ProgressionSystem.add_talent_points + set_meta_value。

## 验收标准

| # | AC |
|---|---|
| 1 | calculate_reincarnation_points 炼气死亡(1) → 境界²×2=2 + 保底 max(3,2) = 3 |
| 2 | calculate_reincarnation_points 筑基通关(2) → 8 + 通关10 + 击杀/收集/炼制 |
| 3 | calculate_reincarnation_points 化神通关(5) → 50 + 10 + 击杀/收集/炼制 |
| 4 | calculate_reincarnation_points 死亡保底 → 至少 3 点 |
| 5 | 超脱轮回（reincarnation_4 已解锁）→ points × 1.2（四舍五入）|
| 6 | settle_run 返回 {points_earned, realm_reached, result, total_reincarnations} |
| 7 | settle_run 调用 ProgressionSystem.add_talent_points |
| 8 | settle_run 递增 ProgressionSystem._meta["total_reincarnations"] |
| 9 | settle_run 通关时递增 _meta["total_completions"]（通过 set_meta_value）|
| 10 | settle_run 通关时设置 _meta["highest_realm_ever"]（通过 set_meta_value）|

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/reincarnation_talent_system.gd` | calculate_reincarnation_points + settle_run |
| `tests/unit/reincarnation_talent_system/test_settle_run.gd` | 10 条 AC 测试 |

## GDD 来源

- GDD reincarnation-talent-system.md §1 轮回触发时机、§2 轮回点获取公式
- ADR-0012 §talents 领域 add_talent_points + §meta 领域
