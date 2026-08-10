# Epic: 状态效果系统 (Status Effect System)

> **Layer**: Core
> **GDD**: design/gdd/status-system.md
> **Architecture Module**: 战斗子模块 — Autoload #8
> **Status**: Ready
> **Stories**: 3 stories created — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | StatusTemplate/Instance 双层模型 + 8 阶段管线核心 | Integration | Ready | ADR-0011 |
| 002 | 3 叠加规则 + 免疫多级检查 + 20 活跃上限 | Logic | Ready | ADR-0011 |
| 003 | 战斗结束 snapshot 导出 GSM + 暂挂/恢复排序 | Integration | Ready | ADR-0011 |

## Overview

实现状态效果生命周期的 8 阶段管线（施加/合并/跟踪/倒计时/触发/暂挂/恢复/移除）——采用 Template/Instance 分离模式（StatusTemplate=Resource + StatusInstance=RefCounted）。支持 3 种叠加规则（独立/刷新/叠加上限）+ 免疫多级检查 + 20 个活跃状态上限。战斗热路径期间子系统内部管理（O(1) 查询），战斗结束导出快照至 GSM。状态效果的暂挂/恢复在角色离场/上场时独立处理——与 BindingManager 的暂挂/恢复并行（先 BindingManager、后 StatusEffectSystem）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0011: 状态效果系统 | Template/Instance 分离 + 8 阶段管线 + 战斗热路径 O(1) + GSM 例外模式 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-status-001 | 状态效果生命周期——8 个阶段的施加/合并/跟踪/倒计时/触发/暂挂/恢复/移除管线 | ADR-0011 ✅ |
| TR-status-002 | 3 种叠加规则（独立/刷新/叠加上限）+ 免疫多级检查 + 20 个活跃状态上限 | ADR-0011 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/status-system.md` are verified
- 8 阶段管线通过集成测试——每种叠加规则至少一个测试夹具
- 战斗结束 snapshot 导出到 GSM 的完整性验证
- 暂挂/恢复与 BindingManager 的排序契约通过测试

## Next Step

Run `/story-readiness [story-001-path]` then `/dev-story [story-001-path]` to begin implementation.
