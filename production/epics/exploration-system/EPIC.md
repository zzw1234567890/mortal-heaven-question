# Epic: 探索系统 (Exploration System)

> **Layer**: Feature
> **GDD**: `design/gdd/exploration-system.md`
> **Architecture Module**: 探索与经济子系统 — ExplorationSystem Autoload #14
> **Status**: Backlog
> **Stories**: 5 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 程序化 DAG 地图生成（generate_map） | Logic | Not Started | ADR-0014 |
| 002 | 导航状态 GSM exploration.* 主存储 | Integration | Not Started | ADR-0014 |
| 003 | move_to_node / resolve_node 节点推进 | Logic | Not Started | ADR-0014 |
| 004 | DAG 缓存重建 + _dag_ready 就绪标志 | Integration | Not Started | ADR-0014 |
| 005 | 事件节点分配 + 经济计算 | Integration | Not Started | ADR-0014 |

## Overview

实现探索地图——DAG 程序化生成，导航状态（current_map/node_position/visited_nodes/action_points/map_entry_count）通过 GSM exploration.* 域存储支持存档，DAG 计算中间产物作为内部成员变量不持久化（读档后从 map_state 重建），事件节点分配与触发时机由探索系统管理。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0014: 探索系统 | GSM 主存储 + 程序化 DAG + 内部缓存重建 + 信号委托 | MEDIUM |

## Definition of Done

This epic is complete when:
- 全部 5 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/exploration-system.md` 验收标准全部通过
- DAG 生成与导航通过单元测试；GSM 持久化往返通过集成测试

## Next Step

Run `/dev-story production/epics/exploration-system/story-001-procedural-dag.md` 逐条填充 AC 并实现。
