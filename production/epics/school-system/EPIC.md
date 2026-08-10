# Epic: 流派系统 (School System)

> **Layer**: Core
> **GDD**: design/gdd/school-system.md
> **Architecture Module**: 静态数据表 + 查询接口 — Autoload #19
> **Status**: Ready
> **Stories**: 2 stories created — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | SchoolSystem Autoload #19 + SCHOOL_LIBRARY const + 纯查询接口 | Logic | Ready | ADR-0025 |
| 002 | 5 流派增益公式 + 不可驱散约束 + 流派切换清空 | Logic | Ready | ADR-0025 |

## Overview

实现 5 种流派方向（剑修/阵修/丹修/符修/器修）的定义数据——每种流派的增益公式、关联阵营、专属卡牌池。流派增益在战斗开始时注册到战斗上下文（不经过 StatusEffectSystem——流派增益是系统级效果，不可被敌方驱散，不占用状态槽位）。流派系统是纯数据层——运行时玩家当前的流派选择存储在 GSM 中。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0025: 流派系统 | const Dictionary + 纯查询接口 + 系统级增益（不可驱散） | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-school-001 | 5 流派定义库 + 优先级检测 + 匹配度计算（待 `/architecture-review` 注册） | ADR-0025 ✅ |
| TR-school-002 | 5 流派增益效果数值 + 系统级不可驱散 + 切换清空（待 `/architecture-review` 注册） | ADR-0025 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/school-system.md` are verified
- 5 种流派的增益公式通过单元测试（每种流派至少 3 个境界级别的增益验证）
- 流派增益不可被 StatusEffectSystem 驱散的约束通过集成测试

## Next Step

Run `/story-readiness [story-001-path]` then `/dev-story [story-001-path]` to begin implementation.
