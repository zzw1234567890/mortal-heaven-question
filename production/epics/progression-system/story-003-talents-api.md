# Story 003：talents 领域 API（points/purchase/grant/equip）

> **Epic**: progression-system
> **Story**: 003
> **Type**: Logic
> **ADR**: ADR-0012
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 ProgressionSystem 的 talents 领域 API——get_talent_points / add_talent_points（轮回结算时调用）、purchase_talent（扣除轮回点 + 解锁 + 发射信号）、grant_talent（直接授予，不扣点，幂等）、get_talent_tree_state（完整天赋树状态）、set_equipped_talents（槽位校验）、get_active_slot_count（N = 5 + floor(unlocked/4)）。

## 验收标准

| # | AC |
|---|---|
| 1 | get_talent_points() 返回 _talents["points_available"] |
| 2 | add_talent_points(10) 递增 points_available + total_earned，_dirty=true |
| 3 | purchase_talent("t1") 点数充足 → {success: true}，扣除点数，写入 unlocked 列表 |
| 4 | purchase_talent 点数不足 → {success: false, reason: "insufficient_points"} |
| 5 | purchase_talent 已解锁 → {success: false, reason: "already_unlocked"} |
| 6 | grant_talent("t1") 直接授予不扣点，幂等（重复授予返回 success: true） |
| 7 | get_active_slot_count() 返回 N = 5 + floor(unlocked_count / 4) |
| 8 | set_equipped_talents 槽位数合法 → {success: true}，写入 equipped 列表 |
| 9 | set_equipped_talents 超出槽位 → {success: false, reason: "slot_exceeded"} |
| 10 | purchase_talent 发射 talent_purchased(id, points_remaining) 信号 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/meta/progression_system.gd` | talents 领域 API |
| `tests/unit/progression_system/test_talents_api.gd` | 10 条 AC 测试 |

## GDD 来源

- ADR-0012 §关键接口（talents 领域）
- GDD reincarnation-talent-system.md §3 天赋树结构、§4 轮回点存储与消费
