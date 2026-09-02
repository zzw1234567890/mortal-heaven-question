# Story 001：PlayerTalents 天赋树 + 查询 API

> **Epic**: reincarnation-talent-system
> **Story**: 001
> **Type**: Logic
> **ADR**: ADR-0012
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 ReincarnationTalentSystem RefCounted 服务类——20 个天赋节点 const Dictionary（5 分支 × 4 层）、get_talent_def / get_branch_talents / get_full_tree_state 查询 API、分支解锁规则校验（L2 需 L1、L3 需 L2 + 通关/死亡条件、L4 需 L3 + 境界条件）。天赋定义注册到 ProgressionSystem.register_talent()。

## 验收标准

| # | AC |
|---|---|
| 1 | TALENT_TREE const 包含 20 个天赋节点（5 分支 × 4 层）|
| 2 | get_talent_def("cultivation_1") 返回 {id, name, cost, branch, layer, effect} |
| 3 | get_branch_talents("cultivation") 返回 4 个天赋（L1~L4）|
| 4 | get_full_tree_state() 返回 {branches: {branch: layer}, unlocked: [], points, slots} |
| 5 | 5 个分支各有 4 层（cultivation/resource/combat/card/reincarnation）|
| 6 | L1 cost=8, L2 cost=12, L3 cost=18, L4 cost=25~35 |
| 7 | 天赋总成本 = 333 点 |
| 8 | can_unlock("cultivation_2") 在 L1 未解锁时返回 false（需前置）|
| 9 | can_unlock("cultivation_2") 在 L1 已解锁时返回 true |
| 10 | 初始化时调用 ProgressionSystem.register_talent() 注册全部 20 个天赋 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/reincarnation_talent_system.gd` | ReincarnationTalentSystem RefCounted |
| `tests/unit/reincarnation_talent_system/test_talent_tree.gd` | 10 条 AC 测试 |

## GDD 来源

- GDD reincarnation-talent-system.md §3 天赋树结构
- ADR-0012 §关键接口（talents 领域 register_talent）
