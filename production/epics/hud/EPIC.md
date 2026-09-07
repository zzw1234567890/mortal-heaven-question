# Epic: HUD 系统

> **Layer**: Presentation
> **GDD**: design/gdd/hud-system.md
> **Architecture Module**: HUD 系统（顶部/底部信息条——`update_resources()` / `update_realm()` / `update_ap()`）
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories hud`

## Overview

HUD 系统实现游戏中始终可见的全局信息层——境界/修为条、灵石计数、卡组数量、行动力（探索中）以及通知/提示系统。它是表现层的依赖枢纽：combat-ui 与 exploration-ui 都消费 HUD 的子组件与数据流模式。按 ADR-0031，HUD 以 CanvasLayer 由 SceneManager 挂载（探索可见/战斗隐藏），零状态所有权，Cat 1 信号驱动更新。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0031: 表现层架构基线 | 场景内 Control + 零状态所有权 + 事件驱动 + 双焦点双视觉 + PersistentLayer/CanvasLayer 挂载 | HIGH（4.6 双焦点） |
| ADR-0007: 信号驱动通信分类法 | UI 更新仅连接 Cat 1/Cat 2b 信号 | LOW |
| ADR-0005: 场景管理器 | HUD CanvasLayer 挂载/保留编排 | LOW |

## GDD Requirements

TR 注册表暂无表现层条目——需求以 GDD 验收标准编号占位（`/architecture-review` 生成 TR-ID 后回填）：

| AC 编号 | Requirement | ADR Coverage |
|-------|-------------|--------------|
| AC-hud-001~011 | hud-system.md §验收标准（11 条 GIVEN/WHEN/THEN） | ADR-0031 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/hud-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- HUD 在探索场景可见、战斗场景隐藏的切换正确（ADR-0031 验证标准）

## Next Step

Run `/create-stories hud` to break this epic into implementable stories.

**排期提示**（PR-EPIC 2026-09-07）：Sprint 13 必须完成——依赖枢纽，越早交付下游越早解锁。
