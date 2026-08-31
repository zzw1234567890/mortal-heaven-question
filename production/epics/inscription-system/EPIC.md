# Epic: 法宝铭刻系统 (Inscription System)

> **Layer**: Feature
> **GDD**: `design/gdd/inscription-system.md`
> **Architecture Module**: 探索与经济子系统 — InscriptionSystem（RefCounted 非 Autoload）
> **Status**: Backlog
> **Stories**: 3 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | generate_candidates 候选属性生成 | Logic | Done | ADR-0030 |
| 002 | inscribe / apply_inscription 铭刻编排 | Logic | Done | ADR-0030 |
| 003 | inscription_cost / dismantle_inscription_refund 成本 | Logic | Done | ADR-0030 |

## Overview

实现法宝铭刻——铭刻候选属性生成、铭刻编排、铭刻成本与拆解返还等纯逻辑方法（static 工具类模式）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0030: 法宝铭刻系统 | 候选生成 + 铭刻编排 + 成本/返还 | LOW |

## Definition of Done

This epic is complete when:
- 全部 3 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/inscription-system.md` 验收标准全部通过
- 候选生成与成本公式通过单元测试

## Next Step

Run `/dev-story production/epics/inscription-system/story-001-candidate-generation.md` 逐条填充 AC 并实现。
