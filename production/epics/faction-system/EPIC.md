# Epic: 阵营系统 (Faction System)

> **Layer**: Core
> **GDD**: design/gdd/faction-system.md
> **Architecture Module**: 静态数据表 + 查询接口 — Autoload #15
> **Status**: In Progress
> **Stories**: 2 stories created — see table below

## Overview

实现阵营数据模型——const Dictionary 存储阵营定义（名称、克制关系、所属流派） + 纯查询接口。阵营决定阵法系统的兼容性（同阵营角色可组成阵法）和流派系统的归属（每个阵营关联 1 个流派方向）。阵营系统是纯数据层——不持有运行时状态。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0018: 阵营系统 | const Dictionary + 纯查询接口 + 阵法和流派的数据基础 | LOW |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/faction-system.md` are verified
- 阵营克制关系查询接口通过单元测试
- 阵营数据表可通过 FormationSystem 和 SchoolSystem 正确消费

## Next Step

All 2 stories created. Run `/story-readiness production/epics/faction-system/story-001-faction-system-autoload-library-query-api.md` to verify, then `/dev-story` to implement.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | FactionSystem Autoload + const FACTION_LIBRARY 标签库 + 标签查询 API | Logic | Ready | ADR-0018 |
| 002 | 场上阵营实时统计 + 阵法条件判定 + 阵营关系判定 | Integration | Ready | ADR-0018 |