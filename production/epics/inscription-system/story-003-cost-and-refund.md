# Story 003：inscription_cost / dismantle_inscription_refund 成本与返还

> **Epic**: inscription-system
> **Story**: 003
> **Type**: Logic
> **ADR**: ADR-0030
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 InscriptionSystem 的铭刻递增成本公式 `inscription_cost(N) = min(N+1, 5)` 和拆解返还公式 `dismantle_inscription_refund(total) = max(1, floor(total × 0.5))`（total=0 时返回 0）。这两个纯函数已在 Story 6-9 中一并实现，本 story 补充专项测试覆盖。

## 验收标准

| # | AC |
|---|---|
| 1 | `inscription_cost(0)` = 1（首次铭刻） |
| 2 | `inscription_cost(1)` = 2（第二次） |
| 3 | `inscription_cost(4)` = 5（第五次） |
| 4 | `inscription_cost(5)` = 5（软上限——第六次及以后固定 5） |
| 5 | `inscription_cost(100)` = 5（极大值仍受软上限钳制） |
| 6 | `dismantle_inscription_refund(0)` = 0（从未铭刻不返还） |
| 7 | `dismantle_inscription_refund(1)` = 1（至少返 1） |
| 8 | `dismantle_inscription_refund(6)` = 3（floor(6×0.5)=3） |
| 9 | `dismantle_inscription_refund(3)` = 1（floor(3×0.5)=1，max(1,...)） |
| 10 | `dismantle_inscription_refund(15)` = 7（floor(15×0.5)=7） |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/inscription_system.gd` | inscription_cost + dismantle_inscription_refund 纯函数（已实现） |
| `tests/unit/inscription_system/test_cost_and_refund.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/inscription-system.md` §1 递增成本、§4 拆解返还
- ADR-0030 §inscription_cost / §dismantle_inscription_refund