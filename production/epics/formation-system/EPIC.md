# Epic: 阵法系统 (Formation System)

> **Layer**: Feature
> **GDD**: `design/gdd/formation-system.md`
> **Architecture Module**: 战斗子系统 — FormationSystem Autoload #23
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 内部条件状态机 + 阵法位管理 | Logic | Ready | ADR-0024 |
| 002 | 激活条件实时重判（订阅 deployment 信号） | Integration | Ready | ADR-0024 |
| 003 | get_aura_bonus O(1) 查询 + 梯度光环计算 | Logic | Ready | ADR-0024 |
| 004 | serialize_all 快照导出 GSM.battle.formation_snapshot | Integration | Ready | ADR-0024 |

## Overview

实现阵法位数据与光环效果——阵法位状态、激活判定、角色归属在 FormationSystem 内部 Dictionary 管理（战斗期间不经过 GSM），激活条件通过订阅 DeploymentSystem 信号实时重判，光环效果 get_aura_bonus O(1) 查询供伤害计算与属性显示，战斗结束导出阵位快照至 GSM。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0024: 阵法系统 | 内部条件状态机 + 信号实时重判 + 梯度光环 + GSM 快照 | LOW |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/formation-system.md` 验收标准全部通过
- 光环计算与激活重判通过单元测试；快照导出通过集成测试

## Next Step

Run `/dev-story production/epics/formation-system/story-001-internal-state-machine.md` 逐条填充 AC 并实现。
