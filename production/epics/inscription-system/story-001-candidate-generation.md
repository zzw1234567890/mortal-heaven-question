# Story 001：generate_candidates 候选属性生成

> **Epic**: inscription-system
> **Story**: 001
> **Type**: Logic
> **ADR**: ADR-0030
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 InscriptionSystem RefCounted 工具类的 11 种副属性权重表和 `generate_candidates()` 候选生成算法（6 步权重变换管线：定向加权→境界加成/T4移除→费用-1特殊处理→已有属性减半→不放回抽取）。

## 验收标准

| # | AC |
|---|---|
| 1 | `SUBSTAT_WEIGHTS` 包含 11 种副属性 |
| 2 | `generate_candidates(realm=1)` 不含 T4 属性 |
| 3 | `generate_candidates(realm=2)` 含全部 4 个 T4 属性，bonus=4 |
| 4 | `direction=ATTACK` 时 atk+1=33, crit+3=22, crit_dmg+5=18 |
| 5 | `direction=DEFENSE, realm=1` 时 def+1=27, hp+2=15 |
| 6 | 已有 atk+1 时权重减半为 11，def+1 不受影响 |
| 7 | 三叠同属性时权重保底为 1 |
| 8 | 已有 cost-1 时完全移除（不减半） |
| 9 | `generate_candidates` 返回恰好 3 个互不相同的候选 |
| 10 | `direction=NONE` 时所有权重保持基础值 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/inscription_system.gd` | 权重表 + generate_candidates + _weighted_sample_without_replacement |
| `tests/unit/inscription_system/test_candidate_generation.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/inscription-system.md` §2 副属性池、§3 品质梯级与权重规则
- ADR-0030 §关键接口 generate_candidates / SUBSTAT_WEIGHTS