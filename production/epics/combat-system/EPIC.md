# Epic: 战斗系统 (Combat System)

> **Layer**: Feature
> **GDD**: `design/gdd/combat-system.md`
> **Architecture Module**: 战斗子系统 — CombatSystem Autoload #9
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 7 阶段回合状态机（advance_phase 确定性推进 + 阶段转换校验） | Logic | Not Started | ADR-0008 |
| 002 | 战斗生命周期编排（battle_start / battle_end + GSM battle.* 域） | Integration | Not Started | ADR-0008 |
| 003 | play_card 出牌 + 目标解析 + 自动推进调度 | Logic | Not Started | ADR-0008 |
| 004 | 阶段转换 Cat 2b 信号通知 CombatUI | Integration | Not Started | ADR-0008 |

## Overview

实现回合制战斗流程——7 阶段状态机（准备/出牌/结算/结束等）的确定性推进，战斗生命周期通过 GSM `battle.*` 域管理，9 个子系统（费用/卡牌/AI/效果引擎/状态/上场/绑定/阵法/境界）通过直接方法调用编排，阶段转换通过 Cat 2b 信号通知 CombatUI。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0008: 战斗系统 | 7 阶段状态机 + 直接调用编排 9 子系统 + GSM battle.* 生命周期 | MEDIUM |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/combat-system.md` 验收标准全部通过
- 7 阶段状态机转换逻辑通过单元测试；战斗生命周期 GSM 集成通过集成测试

## Next Step

Run `/dev-story production/epics/combat-system/story-001-seven-phase-state-machine.md` 逐条填充 AC 并实现。
