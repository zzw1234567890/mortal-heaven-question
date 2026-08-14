# Epic: AI 系统（敌方 AI） (AI System)

> **Layer**: Feature
> **GDD**: `design/gdd/ai-system.md`
> **Architecture Module**: 战斗子系统 — AISystem Autoload #18
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | EnemyTemplate Resource + EnemyFactory + EnemyBattleState | Logic | Not Started | ADR-0017 |
| 002 | execute_turn 决策主循环（普通/精英/Boss 分支） | Logic | Not Started | ADR-0017 |
| 003 | BossPhaseMgr 阶段转换内部状态机 | Logic | Not Started | ADR-0017 |
| 004 | 难度缩放 + register_preconfigured_bindings | Logic | Not Started | ADR-0017 |

## Overview

实现敌方 AI 决策——EnemyTemplate 用 `.tres` Resource 供策划 Inspector 编辑，EnemyFactory 创建轻量级 EnemyBattleState RefCounted，技能效果统一走 CardEffectEngine.resolve() 结算路径，Boss 阶段转换由内部状态机管理，决策在主线程同步执行。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0017: AI 系统 | EnemyTemplate Resource + 决策主循环 + Boss 状态机 + 复用效果引擎 | LOW |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/ai-system.md` 验收标准全部通过
- 决策分支与 Boss 阶段转换通过单元测试；EnemyTemplate 加载通过集成测试

## Next Step

Run `/dev-story production/epics/ai-system/story-001-enemy-template-factory.md` 逐条填充 AC 并实现。
