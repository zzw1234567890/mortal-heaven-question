# Epic: 事件系统 (Event System)

> **Layer**: Foundation
> **GDD**: design/gdd/event-system.md
> **Architecture Module**: 运行时内容引擎 — Autoload #5
> **Status**: In Progress
> **Stories**: 5 stories created

## Stories

| # | Story | 类型 | 预估 | 依赖 | 状态 |
|---|-------|------|:--:|------|------|
| 001 | [EventTemplate Resource 数据模型](story-001-event-template-resource-model.md) | Logic | 3 | 无 | 待实现 |
| 002 | [EventInstance 运行时实例 + 触发/判定/结算](story-002-event-instance-trigger-resolve.md) | Logic | 5 | Story 001 | 待实现 |
| 003 | [story_flags 唯一运行时写入者 + 委托写入契约](story-003-story-flags-ownership-delegation.md) | Logic + Integration | 3 | Story 002 | 待实现 |
| 004 | [连锁事件 —— MAX_CHAIN_DEPTH=3 + 循环检测](story-004-chain-events-depth-cycle-detection.md) | Logic | 3 | Story 002 | 待实现 |
| 005 | [结果执行器 + ADD_CARD 信号委托](story-005-outcome-executor-add-card-delegation.md) | Integration | 4 | Story 002, 003, 004 | 待实现 |

**实现顺序**: 001 → 002 → 003 + 004（可并行）→ 005

## Overview

实现 6 种事件类型解析器 + 60-100 个事件模板的条件分支评估 + 概率结果结算（chance + [min, max] 随机范围） + story_flags 读写委托模型（剧情/对话/结局系统通过委托写入，禁止直接调用） + Resource 模板按需加载策略。事件系统是探索阶段的核心内容驱动引擎——每次节点停留触发一次 2-4 选 1 的决策事件。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0003: 事件系统 | 6 种事件类型 + story_flags 唯一运行时写入者 + 委托写入契约 + Outcome 模板 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-event-001 | 6 种事件类型 + 60-100 个事件模板的条件分支和结果数据 | ADR-0003 ✅ |
| TR-event-002 | story_flags 唯一运行时写入者 + 委托写入契约 | ADR-0003 ✅ |
| TR-event-003 | 概率结果结算——chance + [min, max] 随机值范围 | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/event-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- 事件模板解析器通过全部 6 种事件类型的测试夹具
- 委托写入模型验证：剧情/对话/结局系统通过 EventSystem.set_flag() 写入，无直接 GSM 写入

## Next Step

Run `/story-readiness story-001` to validate Story 001 before implementation.