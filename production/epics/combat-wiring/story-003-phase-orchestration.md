# Story 003：CombatSystem _enter_phase 子系统编排接线

> **Epic**: combat-wiring
> **Story**: 003
> **Type**: Integration
> **Status**: In Progress
> **Estimate**: 0.5d

## 描述

替换 CombatSystem `_enter_phase` 中的桩注释为实际子系统编排调用。接线 StatusEffectSystem.tick_all（PREPARATION）、CostSystem.reset_for_turn（END）、DeploymentSystem.clear_standby_state（END）到对应阶段。保留自动推进调度不变。

## 验收标准

| # | AC |
|---|---|
| 1 | PREPARATION 阶段调用 StatusEffectSystem.tick_all（field_characters, _turn） |
| 2 | StatusEffectSystem 不可用时静默跳过（不崩溃） |
| 3 | END 阶段调用 CostSystem.reset_for_turn |
| 4 | CostSystem 不可用时静默跳过 |
| 5 | END 阶段调用 DeploymentSystem.clear_standby_state |
| 6 | DeploymentSystem 不可用时静默跳过 |
| 7 | PREPARATION 阶段编排顺序：tick_all → _schedule_auto_advance |
| 8 | END 阶段编排顺序：reset_for_turn → clear_standby_state → _schedule_auto_advance |
| 9 | 自动推进链不受影响（_schedule_auto_advance 仍正常调用） |
| 10 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/combat_system.gd` | _enter_phase 桩替换为子系统调用 |
| `tests/unit/combat_system/test_phase_orchestration.gd` | 10 条 AC 测试 |
