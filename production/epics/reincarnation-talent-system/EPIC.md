# Epic: 轮回天赋系统 (Reincarnation Talent System)

> **Layer**: Feature
> **GDD**: `design/gdd/reincarnation-talent-system.md`
> **Architecture Module**: 成长与元进度子系统 — 跨局元进度（经 ProgressionSystem）
> **Status**: Done
> **Stories**: 3 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | PlayerTalents 天赋树 + 查询 API | Logic | Done | ADR-0012 |
| 002 | unlock_talent / get_active_talents | Logic | Done | ADR-0012 |
| 003 | settle_run 轮回结算（跨局天赋继承） | Integration | Done | ADR-0012 |

## Overview

实现轮回天赋——天赋树、轮回结算与跨局天赋继承。跨局元进度数据经 ProgressionSystem（ADR-0012）直写 API 管理，本系统负责天赋领域逻辑与结算编排。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0012: 跨局元进度系统 | ProgressionSystem Autoload #12 + 直写缓存 + 信号持久化 | LOW |

## Definition of Done

This epic is complete when:
- 全部 3 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/reincarnation-talent-system.md` 验收标准全部通过
- 天赋解锁/轮回结算通过单元测试；ProgressionSystem 集成通过集成测试

## Next Step

Run `/dev-story production/epics/reincarnation-talent-system/story-001-talent-tree.md` 逐条填充 AC 并实现。
