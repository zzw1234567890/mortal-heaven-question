# Story 004：CombatSystem AISystem + DeploymentSystem 接线

> **Epic**: combat-wiring
> **Story**: 004
> **Type**: Logic
> **Status**: In Progress
> **Estimate**: 0.5d

## 描述

接线 AISystem.execute_turn 到 ENEMY_TURN 阶段。替换 _can_afford_any_card 桩为遍历手牌调用 CostSystem.can_afford。替换 _all_characters_targeted 桩为 DeploymentSystem 待命状态查询。

## 验收标准

| # | AC |
|---|---|
| 1 | ENEMY_TURN 阶段调用 AISystem.execute_turn（field_state） |
| 2 | AISystem 不可用时静默跳过（不崩溃） |
| 3 | _can_afford_any_card 遍历手牌调用 CostSystem.can_afford |
| 4 | CostSystem 不可用时回退旧逻辑（手牌非空即 true） |
| 5 | 手牌为空时 _can_afford_any_card 返回 false |
| 6 | 所有手牌费用均不足时 _can_afford_any_card 返回 false |
| 7 | _all_characters_targeted 查询 DeploymentSystem 待命角色 |
| 8 | DeploymentSystem 不可用时回退旧逻辑（空队列 true） |
| 9 | ENEMY_TURN 编排顺序：AISystem.execute_turn → _schedule_auto_advance |
| 10 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/combat_system.gd` | AISystem + DeploymentSystem 接线 |
| `tests/unit/combat_system/test_ai_deployment_wiring.gd` | 10 条 AC 测试 |
