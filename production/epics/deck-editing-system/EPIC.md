# Epic: 卡组编辑系统 (Deck Editing System)

> **Layer**: Feature
> **GDD**: `design/gdd/deck-editing-system.md`
> **Architecture Module**: 探索与经济子系统 — DeckEditingSystem Autoload #22
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 卡组验证器（卡组上限/添加/移除校验） | Logic | Not Started | ADR-0023 |
| 002 | execute_delete / execute_sell 战利品编排 | Logic | Not Started | ADR-0023 |
| 003 | generate_loot_options + apply_loot_choice | Logic | Not Started | ADR-0023 |
| 004 | initialize_initial_deck + 角色位替换 | Integration | Not Started | ADR-0023 |

## Overview

实现卡组编辑与战利品编排——卡组验证器、删卡/售卡、战利品生成与选择、初始卡组初始化与角色位替换，协调 CardSystem/ResourceSystem/GSM 等子系统。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0023: 卡组编辑系统 | 卡组验证器 + 战利品编排 + 删卡/售卡 | LOW |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/deck-editing-system.md` 验收标准全部通过
- 验证器与战利品生成通过单元测试；初始卡组集成通过集成测试

## Next Step

Run `/dev-story production/epics/deck-editing-system/story-001-deck-validator.md` 逐条填充 AC 并实现。
