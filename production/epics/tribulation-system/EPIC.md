# Epic: 渡劫突破系统 (Tribulation System)

> **Layer**: Feature
> **GDD**: `design/gdd/tribulation-system.md`
> **Architecture Module**: 成长与元进度子系统 — TribulationSystem Autoload #24
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 渡劫流程编排 + TribulationState 状态机 | Logic | Not Started | ADR-0021 |
| 002 | check_tribulation_ready / trigger_tribulation | Logic | Not Started | ADR-0021 |
| 003 | 渡劫战斗启动 + 天雷 debuff 注册 | Integration | Not Started | ADR-0021 |
| 004 | 渡劫成功/失败处理 + use_tribulation_pill | Logic | Not Started | ADR-0021 |

## Overview

实现渡劫突破——渡劫流程编排与 TribulationState 状态机，渡劫战斗通过 CombatSystem 启动，天雷 debuff 通过 StatusEffectSystem 注册，成功/失败分支处理，渡劫丹辅助。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0021: 渡劫突破系统 | 流程编排状态机 + 渡劫战斗 + 天雷 debuff + 成败分支 | MEDIUM |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/tribulation-system.md` 验收标准全部通过
- 状态机与成败分支通过单元测试；渡劫战斗集成通过集成测试

## Next Step

Run `/dev-story production/epics/tribulation-system/story-001-tribulation-state-machine.md` 逐条填充 AC 并实现。
