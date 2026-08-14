# Epic: 炼丹炼器系统 (Alchemy & Crafting System)

> **Layer**: Feature
> **GDD**: `design/gdd/alchemy-crafting-system.md`
> **Architecture Module**: 探索与经济子系统 — AlchemySystem（RefCounted 非 Autoload）
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 配方表（const Dictionary, 8 配方）+ 查询 API | Logic | Not Started | ADR-0028 |
| 002 | craft_pill / craft_artifact 炼制编排 | Logic | Not Started | ADR-0028 |
| 003 | roll_quality / forge_artifact_stat 品质与属性 | Logic | Not Started | ADR-0028 |
| 004 | apply_reroll 品质重掷 + 独立 RNG 实例 | Logic | Not Started | ADR-0028 |

## Overview

实现炼丹与炼器——配方表 const Dictionary（8 配方）+ 独立 RNG 实例，品质判定、神器属性、品质重掷等纯逻辑方法（static 工具类模式，RefCounted 非 Autoload）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0028: 炼丹炼器系统 | 配方表 + 纯逻辑 static 方法 + 独立 RNG | LOW |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/alchemy-crafting-system.md` 验收标准全部通过
- 品质判定与炼制公式通过单元测试

## Next Step

Run `/dev-story production/epics/alchemy-crafting-system/story-001-recipe-table.md` 逐条填充 AC 并实现。
