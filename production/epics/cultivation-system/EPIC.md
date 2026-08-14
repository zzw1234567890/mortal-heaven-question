# Epic: 修为养成系统 (Cultivation System)

> **Layer**: Feature
> **GDD**: `design/gdd/cultivation-system.md`
> **Architecture Module**: 成长与元进度子系统 — CultivationSystem Autoload #20
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | gain_cultivation 统一获取入口 + 溢出判定 | Logic | Not Started | ADR-0020 |
| 002 | GSM player.* 数据存储 + batch_updated 传播 | Integration | Not Started | ADR-0020 |
| 003 | settle_overflow + 突破后溢出结算 | Logic | Not Started | ADR-0020 |
| 004 | realm_upgraded 信号订阅 + check_breakthrough | Integration | Not Started | ADR-0020 |

## Overview

实现修为获取与溢出——gain_cultivation 统一获取逻辑与溢出判定，数据存储 GSM player.* 域，修为变更通过 GSM batch_updated 传播，突破后溢出结算通过订阅 RealmSystem realm_upgraded 信号触发。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0020: 修为养成系统 | 统一获取接口 + GSM 存储 + 信号订阅结算 | LOW |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/cultivation-system.md` 验收标准全部通过
- 溢出判定与统一获取通过单元测试；GSM 集成通过集成测试

## Next Step

Run `/dev-story production/epics/cultivation-system/story-001-gain-cultivation.md` 逐条填充 AC 并实现。
