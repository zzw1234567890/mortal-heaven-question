# Story 002：inscribe / apply_inscription 铭刻编排

> **Epic**: inscription-system
> **Story**: 002
> **Type**: Logic
> **ADR**: ADR-0030
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 InscriptionSystem 的铭刻编排流程：`inscribe()` 校验法宝类型→计算费用→校验灵材→扣减灵材→生成候选→返回结果；`apply_inscription()` 玩家选择候选后写入 CardInstance 的 inscriptions/inscription_count/total_materials_spent 字段。

## 验收标准

| # | AC |
|---|---|
| 1 | `inscribe()` 校验法宝类型——非法宝返回 NOT_ARTIFACT |
| 2 | `inscribe()` 灵材不足返回 INSUFFICIENT_MATERIALS + cost 字段 |
| 3 | `inscribe()` 成功返回 SUCCESS + candidates(3个) + cost + is_replace |
| 4 | `inscribe()` 确认即扣灵材——ResourceSystem.spend_resource 被调用 |
| 5 | `inscribe()` 境界 L=1 时候选不含 T4 |
| 6 | `inscribe()` to_replace_idx=-1 时 is_replace=false |
| 7 | `inscribe()` to_replace_idx>=0 时 is_replace=true |
| 8 | `apply_inscription()` 新增模式——inscriptions 数组长度+1 |
| 9 | `apply_inscription()` 替换模式——指定索引被替换，数组长度不变 |
| 10 | `apply_inscription()` 后 inscription_count +1，total_materials_spent += cost |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/inscription_system.gd` | inscribe + apply_inscription 编排方法 |
| `tests/unit/inscription_system/test_inscribe_orchestration.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/inscription-system.md` §1 铭刻基本规则、§4 已满法宝替换
- ADR-0030 §关键接口 inscribe / apply_inscription
