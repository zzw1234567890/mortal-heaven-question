# Story 003：roll_quality / forge_artifact_stat 品质与属性

> **Epic**: alchemy-crafting-system
> **Story**: 003
> **Type**: Logic
> **ADR**: ADR-0028
> **Status**: In Progress
> **Estimate**: 0.5d
> **Dependencies**: Story 001

## 描述

实现品质掷骰和法宝属性生成的纯函数公式——`quality_roll()`、`quality_reroll()`、`resolve_final_rarity()`、`pill_effect()`、`forge_artifact_stat()`、`jindan_cumulative_threshold()`。全部为 static func 纯函数，不修改状态，不发射信号。

## 验收标准

| # | AC |
|---|---|
| 1 | `quality_roll` 确定性——相同 seed 产出相同结果 |
| 2 | `quality_roll(rarity=1)` 永不返回 DOWNGRADE（白色不降品） |
| 3 | `quality_reroll` 降品概率 25%（确定性测试） |
| 4 | `pill_effect(4, 1.3, 0.0)` == 5（floor(4×1.3)） |
| 5 | `pill_effect(4, 0.8, 0.0)` == 3（floor(4×0.8)） |
| 6 | `pill_effect(1, 0.8, 0.0)` == 1（保底至少 1） |
| 7 | `forge_artifact_stat(4, 0.8)` == {atk:4, def:4} |
| 8 | `forge_artifact_stat(5, 1.0)` == {atk:10, def:8} |
| 9 | `forge_artifact_stat(1, 0.8)` == {atk:1, def:0}（白色降品保底） |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/alchemy_system.gd` | 已在 Story 6-5 实现 |
| `tests/unit/alchemy_system/test_quality_and_stats.gd` | 9 条 AC 测试 |

## GDD 来源

- `design/gdd/alchemy-crafting-system.md` §1 品质概率公式、§2 法宝属性生成、§2 丹药效果缩放
- ADR-0028 §关键接口 quality_roll / pill_effect / forge_artifact_stat