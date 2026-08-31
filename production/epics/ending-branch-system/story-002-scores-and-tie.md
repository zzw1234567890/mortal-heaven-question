# Story 002：_calculate_scores / _resolve_tie 评分与平局

> **Epic**: ending-branch-system
> **Story**: 002
> **Type**: Logic
> **ADR**: ADR-0029
> **Status**: Done
> **Estimate**: 0.5d

## 描述

补充 EndingEvaluator 的评分计算 `_calculate_scores()` 和平局解决 `_resolve_tie()` 专项测试覆盖——验证权重求和正确性、第 5 章偏斜加分、优先级打破平局。

## 验收标准

| # | AC |
|---|---|
| 1 | ch5=ascend (+30) + ch4=ascend_alone (+15) → ascend 得分含 45 |
| 2 | ch2=destroy_cave 给飞升线 +8，给守护线 +0 |
| 3 | ch1=accept_mo 给守护线 +8，给飞升线 +0 |
| 4 | run_data elites_killed=25 (≥20) → 飞升线 +5 |
| 5 | run_data elites_killed=5 (≤10) → 回归线 +8 |
| 6 | 飞升线=50 守护线=50 平局 + ch5=ascend → 偏斜 +5 → 飞升胜出 |
| 7 | 飞升线=55 守护线=50 + ch5=guard → 偏斜后 55=55 → 优先级飞升>守护 |
| 8 | 三线同分时优先级 ascend > guard > return |
| 9 | flag yinyue_alive=true → 守护线 +5 |
| 10 | ch3=neutral_mediate → 守护线 +15，飞升线 +0 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/ending_evaluator.gd` | _calculate_scores + _resolve_tie（已实现）|
| `tests/unit/ending_branch_system/test_scores_and_tie.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/ending-branch-system.md` §公式 1 评分、§3 平局解决
- ADR-0029 §评分计算算法