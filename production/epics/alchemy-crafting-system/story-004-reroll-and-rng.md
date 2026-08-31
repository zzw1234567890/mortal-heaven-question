# Story 004：apply_reroll 品质重掷 + 独立 RNG 实例

> **Epic**: alchemy-crafting-system
> **Story**: 004
> **Type**: Logic
> **ADR**: ADR-0028
> **Status**: In Progress
> **Estimate**: 0.5d
> **Dependencies**: Story 003

## 描述

实现 `apply_reroll()` 品质重掷编排——玩家选择重掷后的二次掷骰。重掷不额外消耗灵材（灵材已在首次炼制时扣除），使用 `quality_reroll()` 公式（升品+15%，降品升至25%），结果必须接受（不可再次重掷）。

## 验收标准

| # | AC |
|---|---|
| 1 | `apply_reroll(有效配方)` 返回 `result=SUCCESS` |
| 2 | apply_reroll 返回 `can_reroll=false`（不可再次重掷） |
| 3 | apply_reroll 返回 `final_roll` 非 null |
| 4 | apply_reroll 返回 `final_rarity` 在 [1,5] 范围 |
| 5 | `apply_reroll(无效配方)` 返回 `INVALID_RECIPE` |
| 6 | `quality_reroll` 独立 RNG——相同 seed 产出相同结果 |
| 7 | `quality_reroll` 升品概率比 `quality_roll` 高（+15%） |
| 8 | `jindan_cumulative_threshold(1)` == 1, `jindan_cumulative_threshold(3)` == 6 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/alchemy_system.gd` | apply_reroll 方法 |
| `tests/unit/alchemy_system/test_reroll_and_rng.gd` | 8 条 AC 测试 |

## GDD 来源

- `design/gdd/alchemy-crafting-system.md` §1b 品质重掷公式、§5 九转金丹递减收益
- ADR-0028 §apply_reroll / §quality_reroll