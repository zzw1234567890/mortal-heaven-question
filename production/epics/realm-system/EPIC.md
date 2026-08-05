# Epic: 境界系统 (Realm System)

> **Layer**: Core
> **GDD**: design/gdd/realm-system.md
> **Architecture Module**: 静态数据表 + 查询接口 — Autoload #11
> **Status**: In Progress
> **Stories**: 3 stories created — see table below

## Overview

实现 5 级境界（炼气→筑基→金丹→元婴→化神）× 15+ 项属性表（基础攻击、防御、速度、HP 倍率、费用上限、行动力上限等）——采用 const Dictionary + 纯查询接口模式（无运行时状态）。提供境界压制规则（delta=1 压制 20%、delta>=2 压制 50%）和境界提升流程（realm_up() 协调多方状态变更）。境界系统是纯数据层——不持有运行时玩家状态（那是 CultivationSystem 的职责）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0010: 境界系统 | const Dictionary + 纯查询接口 + 5 境界数据表 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-realm-001 | 5 级境界 × 15+ 项属性表——所有其他系统通过查询接口访问 | ADR-0010 ✅ |
| TR-realm-002 | 境界压制规则——delta=1 压制 20%、delta>=2 压制 50% | ADR-0010 ✅ |
| TR-realm-003 | 境界提升流程——突破成功后 realm_up() 协调多方状态变更 | ADR-0010 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/realm-system.md` are verified
- 5 境界数据表通过单元测试（每个境界的所有属性字段验证）
- 境界压制计算通过边界测试：delta=0（无压制）、delta=1（20%）、delta=2（50%）、delta>=3（50%）
- realm_up() 集成测试：境界提升后所有依赖系统（GSM、行动力、费用上限）状态一致

## Next Step

All 3 stories created. Run `/story-readiness production/epics/realm-system/story-001-realm-system-autoload-realm-table-query.md` to verify, then `/dev-story` to implement.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | RealmSystem Autoload + realm_table 数据表 + 查询接口 | Logic | Ready | ADR-0010 |
| 002 | 境界压制计算 + 地图境界压制 + 稀有度权重 | Logic | Ready | ADR-0010 |
| 003 | realm_up() 突破编排 + realm_upgraded 信号 + GSM 集成 | Integration | Ready | ADR-0010 |