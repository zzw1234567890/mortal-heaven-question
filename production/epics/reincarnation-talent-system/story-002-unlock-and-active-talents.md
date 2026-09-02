# Story 002：unlock_talent / get_active_talents

> **Epic**: reincarnation-talent-system
> **Story**: 002
> **Type**: Logic
> **ADR**: ADR-0012
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 ReincarnationTalentSystem 的解锁编排和装备查询——unlock_talent（委托 ProgressionSystem.purchase_talent + 软解锁条件校验）、get_equipped_talents（返回当前装备的天赋定义列表）、get_active_talents（返回装备天赋的 effect 列表供下游系统应用）、set_equipped（委托 ProgressionSystem.set_equipped_talents + 槽位校验）。

## 验收标准

| # | AC |
|---|---|
| 1 | unlock_talent("cultivation_1") 点数充足 + 前置满足 → {success: true} |
| 2 | unlock_talent("cultivation_2") L1 未解锁 → {success: false, reason: "prerequisite_locked"} |
| 3 | unlock_talent 点数不足 → {success: false, reason: "insufficient_points"} |
| 4 | unlock_talent L4 未满足软解锁条件 → {success: false, reason: "condition_not_met"} |
| 5 | unlock_talent("cultivation_1") 委托 ProgressionSystem.purchase_talent |
| 6 | get_equipped_talents() 返回装备天赋的完整定义列表 |
| 7 | get_active_talents() 返回装备天赋的 effect 列表 |
| 8 | set_equipped(["cultivation_1"]) 槽位合法 → {success: true} |
| 9 | set_equipped 超出槽位 → {success: false, reason: "slot_exceeded"} |
| 10 | get_active_talents 未装备任何天赋时返回空数组 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/reincarnation_talent_system.gd` | unlock_talent + get_active_talents |
| `tests/unit/reincarnation_talent_system/test_unlock_and_equip.gd` | 10 条 AC 测试 |

## GDD 来源

- GDD reincarnation-talent-system.md §5 天赋生效时机、§6 软解锁条件
- ADR-0012 §talents 领域 purchase_talent / set_equipped_talents
