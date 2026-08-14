# Epic: 功法/法宝绑定系统 (Binding System)

> **Layer**: Feature
> **GDD**: `design/gdd/binding-system.md`
> **Architecture Module**: 战斗子系统 — BindingManager Autoload #13
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | BindingRecord RefCounted 实例模型 + 内部注册表 | Logic | Not Started | ADR-0013 |
| 002 | bind / unbind / get_bindings 查询 API | Logic | Not Started | ADR-0013 |
| 003 | 绑定生命周期信号总线（7 个 Cat 2b 信号） | Integration | Not Started | ADR-0013 |
| 004 | serialize_all 快照导出 + persistent effect 接口 | Integration | Not Started | ADR-0013 |

## Overview

实现功法/法宝与角色的绑定关系——BindingRecord RefCounted 实例存于 BindingManager 内部 Dictionary 注册表（非 GSM），战斗热路径 O(1) 查询，绑定生命周期通过专用 Cat 2b 信号总线通知 CombatUI，战斗结束 serialize_all 导出快照至 GSM.battle.bindings。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0013: 绑定系统 | RefCounted 实例模型 + 内部注册表 + 7 信号总线 + GSM 快照 | LOW |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/binding-system.md` 验收标准全部通过
- 绑定/解绑/查询通过单元测试；快照导出通过集成测试

## Next Step

Run `/dev-story production/epics/binding-system/story-001-refcounted-model.md` 逐条填充 AC 并实现。
