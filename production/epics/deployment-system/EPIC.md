# Epic: 角色上场与阵位系统 (Deployment System)

> **Layer**: Feature
> **GDD**: `design/gdd/deployment-system.md`
> **Architecture Module**: 战斗子系统 — DeploymentSystem Autoload #17
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 内部状态机 + 阵位数据管理（STANDBY→READY→ACTED） | Logic | Not Started | ADR-0016 |
| 002 | deploy / remove / is_targetable 前后排保护 O(1) | Logic | Not Started | ADR-0016 |
| 003 | 战斗结束 serialize_field 快照导出 GSM.battle.deployment_snapshot | Integration | Not Started | ADR-0016 |
| 004 | clear_standby_state + mark_unavailable + revive_character | Logic | Not Started | ADR-0016 |

## Overview

实现角色上场与 6 格阵位管理——阵位分布、角色在场状态、待命/已就绪标记、不可用角色列表均在 DeploymentSystem 内部 Dictionary 管理（战斗期间不经过 GSM），前后排保护 O(1) 查询，战斗结束导出阵位快照与不可用角色列表至 GSM 存档。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0016: 上场阵位系统 | 内部状态机 + GSM 快照持久化 + 前后排 O(1) 查询 | LOW |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/deployment-system.md` 验收标准全部通过
- 阵位状态机与前后排保护通过单元测试；快照导出通过集成测试

## Next Step

Run `/dev-story production/epics/deployment-system/story-001-internal-state-machine.md` 逐条填充 AC 并实现。
