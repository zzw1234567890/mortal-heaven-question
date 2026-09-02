# Epic: 成就系统 (Achievement System)

> **Layer**: Feature
> **GDD**: `design/gdd/achievement-system.md`
> **Architecture Module**: 成长与元进度子系统 — 跨局元进度（经 ProgressionSystem）
> **Status**: Done
> **Stories**: 3 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Achievement 实例 + 解锁状态管理 | Logic | Done | ADR-0012 |
| 002 | check(criteria) 判定引擎 | Logic | Done | ADR-0012 |
| 003 | get_achievements 查询 + 图鉴集成 | Integration | Done | ADR-0012 |

## Overview

实现成就系统——成就实例、解锁状态与判定引擎。跨局解锁状态经 ProgressionSystem（ADR-0012）直写 API 管理，本系统负责成就领域逻辑与判定。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0012: 跨局元进度系统 | ProgressionSystem Autoload #12 + 直写缓存 + 信号持久化 | LOW |

## Definition of Done

This epic is complete when:
- 全部 3 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/achievement-system.md` 验收标准全部通过
- 判定引擎通过单元测试；ProgressionSystem 集成通过集成测试

## Next Step

Run `/dev-story production/epics/achievement-system/story-001-achievement-instance.md` 逐条填充 AC 并实现。
