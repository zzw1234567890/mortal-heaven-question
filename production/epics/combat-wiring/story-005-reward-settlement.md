# Story 005：CombatSystem 战斗奖励结算 + is_kill 修正

> **Epic**: combat-wiring
> **Story**: 005
> **Type**: Logic
> **Status**: Done
> **Estimate**: 0.5d

## 描述

替换 _settle_result 桩为实际奖励计算（灵石+修为+卡牌掉落），通过 ResourceSystem.add_resource / CultivationSystem.gain_cultivation 写入。同时修正 _resolve_attack_queue 中 is_kill 的派生方式——从目标 HP 派生（final_damage >= target_hp）而非从队列条目 is_kill 字段读取。

## 验收标准

| # | AC |
|---|---|
| 1 | _settle_result(VICTORY) 返回包含 lingshi/cultivation/cards 的 rewards Dictionary |
| 2 | _settle_result(DEFEAT/RETREAT) 返回 retain_ratio=0.5 |
| 3 | _calculate_lingshi_reward 桩返回 0（不崩溃） |
| 4 | _calculate_cultivation_reward 桩返回 0（不崩溃） |
| 5 | _calculate_card_drops 桩返回空 Array（不崩溃） |
| 6 | _apply_victory_rewards 通过 ResourceSystem.add_resource 写入灵石 |
| 7 | _apply_victory_rewards 通过 CultivationSystem.gain_cultivation 写入修为 |
| 8 | ResourceSystem/CultivationSystem 不可用时静默跳过 |
| 9 | _resolve_attack_queue 中 is_kill 从 target_hp 派生（final_damage >= target_hp） |
| 10 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/combat_system.gd` | _settle_result 重写 + is_kill 派生修正 |
| `tests/unit/combat_system/test_reward_settlement.gd` | 10 条 AC 测试 |