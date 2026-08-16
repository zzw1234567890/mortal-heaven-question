# Epic: 卡牌效果解析引擎 (Card Effect Engine)

> **Layer**: Feature
> **GDD**: `design/gdd/card-effect-engine.md`
> **Architecture Module**: 战斗子系统 — CardEffectEngine Autoload #10
> **Status**: Ready
> **Stories**: 5 stories（AC 已由 `/create-stories` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | EffectTemplate/EffectInstance 双层对象模型（4 种子类） | Logic | Ready | ADR-0009 |
| 002 | ResolutionStack 栈式结算引擎（优先级队列 + LIFO + 中断插入） | Logic | Ready | ADR-0009 |
| 003 | 触发链硬限制 10 层 + visited_card_ids 循环检测 | Logic | Ready | ADR-0009 |
| 004 | PRD 伪随机分布引擎（5% 步进 + 怜悯保护） | Logic | Ready | ADR-0009 |
| 005 | AI 干跑评估接口（GameStateSnapshot 不可变纯计算） | Logic | Ready | ADR-0009 |

## Overview

实现卡牌效果解析——Resource 子类（EffectTemplate，`.tres`）+ RefCounted 子类层级（Instant/Persistent/Triggered/Replacement），栈式结算引擎（优先级队列 + LIFO 出栈 + 中断插入），触发链硬限制 10 层 + visited_card_ids 循环检测，PRD 伪随机分布，以及供 AI 干跑评估的不可变快照接口。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0009: 卡牌效果引擎 | 双层对象模型 + 栈式结算 + 10 层触发链 + PRD + AI 干跑评估 | MEDIUM |

## Definition of Done

This epic is complete when:
- 全部 5 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/card-effect-engine.md` 验收标准全部通过
- 效果结算/触发链/PRD 通过单元测试；AI 干跑评估接口通过集成测试

## Next Step

Run `/story-readiness production/epics/card-effect-engine/story-001-template-instance-model.md` 验证故事就绪，然后 `/dev-story` 逐条实现。
