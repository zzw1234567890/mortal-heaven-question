# Epic: 费用系统 (Cost System)

> **Layer**: Core
> **GDD**: design/gdd/cost-system.md
> **Architecture Module**: 战斗子模块 — Autoload #7
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories cost-system`

## Overview

实现战斗灵力（费用）管理——每回合费用上限 = 当前上场角色费用总和（境界决定）、每回合全额恢复不累积、消耗时即时检查可用性。支持临时费用（+N 临时）和费用不足时卡牌灰度（40% 透明度 + 不可拖拽）。费用系统通过 batch_updated 信号向 HUD 报告变更——同时也提供 cost_changed 信号用于战斗热路径的即时响应。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0015: 费用系统 | 境界决定上限 + 全额恢复 + 双重信号路径（cost_changed + batch_updated） | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-cost-001 | 费用上限 = 上场角色总和 + 每回合全额恢复 + 临时费用调整 | ADR-0015 ✅ |

（注：费用系统的 TR 条目在 regstry 中可能未完成——需 `/architecture-review` 补全）

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/cost-system.md` are verified
- 费用消耗/恢复通过单元测试：消耗后上限不变、回合结束全额恢复、临时费用正确叠加
- HUD 费用栏正确响应 cost_changed 和 batch_updated 信号

## Next Step

Run `/create-stories cost-system` to break this epic into implementable stories.