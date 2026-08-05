# Epic: 资源系统 (Resource System)

> **Layer**: Core
> **GDD**: design/gdd/resource-system.md
> **Architecture Module**: 经济引擎 — Autoload #16
> **Status**: In Progress
> **Stories**: 2 stories created — see table below

## Overview

实现灵石和灵材的资源管理——灵石（通用货币）和灵材（炼丹炼器的原材料）的获取、存储和消耗逻辑。资源数量通过 GSM 第二层原子方法写入——ResourceSystem 提供交易验证（余额检查）和资源变更信号（spirit_stones_changed、materials_changed）。支持 HUD 灵石计数器的实时更新和获得/消费时的 ±xx 跳动动画。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0019: 资源系统 | 灵石 + 灵材双轨管理 + GSM 原子写入 + 交易验证层 | LOW |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/resource-system.md` are verified
- 灵石增加/减少通过单元测试（含溢出边界：≥9999 显示 "9.9k"）
- 资源变更信号正确通知 HUD（灵石跳动动画触发）

## Next Step

All 2 stories created. Run `/story-readiness production/epics/resource-system/story-001-resource-system-autoload-read-write-api.md` to verify, then `/dev-story` to implement.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | ResourceSystem Autoload + LingCaiQuality 枚举 + GSM 第二层扩展 + 读写 API | Integration | Ready | ADR-0019 |
| 002 | 资源公式纯函数（拆解/出售/删卡/境界惩罚/天赋加成） | Logic | Ready | ADR-0019 |