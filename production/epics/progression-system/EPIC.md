# Epic: 跨局元进度系统 (Progression System)

> **Layer**: Meta
> **GDD**: 无独立 GDD——ADR-0012 为权威源
> **Architecture Module**: 跨局元进度子系统 — ProgressionSystem Autoload #12
> **Status": Done
> **Stories**: 5 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 域存储 + initialize + serialize/deserialize | Logic | Done | ADR-0012 |
| 002 | achievements 领域 API（unlock/get/update_progress） | Logic | Done | ADR-0012 |
| 003 | talents 领域 API（points/purchase/grant/equip） | Logic | Done | ADR-0012 |
| 004 | endings + gallery + stats + meta 领域 API | Logic | Done | ADR-0012 |
| 005 | progression_updated 信号 + batch_update + SaveLoad 集成 | Integration | Done | ADR-0012 |

## Overview

实现 ProgressionSystem Autoload #12——拥有所有跨局元进度运行时数据（achievements / talents / card_gallery / endings / statistics / meta），使用直写缓存模型（API → 内部存储 → progression_updated 信号 → SaveLoadSystem 被动持久化）。取代 GSM 的 progression.* 域所有权。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0012: 跨局元进度系统 | ProgressionSystem Autoload #12 + 直写缓存 + 信号持久化 + 6 领域 API | LOW |

## Definition of Done

This epic is complete when:
- 全部 5 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- ADR-0012 验证标准全部通过
- 6 个领域 API 通过单元测试；SaveLoadSystem 集成通过集成测试
- Autoload #12 初始化顺序验证通过

## Next Step

Run `/dev-story production/epics/progression-system/story-001-domain-storage.md` 逐条填充 AC 并实现。
