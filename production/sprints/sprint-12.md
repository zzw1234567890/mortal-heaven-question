# Sprint 12: 技术债务清理最终轮——所有剩余超限文件拆分

> **Sprint**: 12
> **Start Date**: 2026-09-04
> **End Date**: 2026-09-15
> **Status**: Active
> **Focus**: 拆分所有剩余可拆分的超 300 行文件（11 个文件）
> **Milestone**: tech-debt-cleanup（技术债务清理）
> **Review Mode**: full
> **Last Updated**: 2026-09-05

## Sprint Goal

将 11 个剩余超限文件全部拆分，预期超限文件从 10 个减少到 3 个（combat_system / save_load_system / progression_system 不拆）。零回归为硬约束——现有 2455 个测试全部通过。

## 容量

- 总天数：12（2026-09-04 至 2026-09-15）
- 缓冲（20%）：2.5 天
- 可用：9.5 天
- 速度基准：11 story / 8.0d ≈ 1.4 story/天

## Stories

### 必须完成（关键路径）—— 12 项

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | file-refactor | alchemy_system.gd 拆分 | `story-009-alchemy-recipes-split.md` | Refactor | 0.5d | — | Done |
| 2 | file-refactor | binding_manager.gd 拆分 | `story-010-binding-slot-ops-split.md` | Refactor | 1.0d | — | Done |
| 3 | file-refactor | exploration_system.gd 拆分 | `story-011-exploration-map-flush-split.md` | Refactor | 1.0d | — | Done |
| 4 | file-refactor | gsm_atomic_writes.gd 拆分 | `story-012-gsm-writes-split.md` | Refactor | 1.0d | — | Done |
| 5 | file-refactor | identity_selection_system.gd 拆分 | `story-013-identity-queries-split.md` | Refactor | 0.5d | — | Done |
| 6 | file-refactor | school_system.gd 流派库拆分 | `story-014-school-condition-faction-split.md` | Refactor | 0.5d | — | Done |
| 7 | file-refactor | ai_system.gd 拆分 | `story-015-ai-boss-phases-split.md` | Refactor | 1.0d | — | Done |
| 8 | file-refactor | status_effect_system.gd 拆分 | `story-016-status-effect-immunity-split.md` | Refactor | 0.5d | — | Done |
| 9 | file-refactor | tribulation_system.gd 拆分 | `story-017-tribulation-combat-split.md` | Refactor | 0.5d | — | Done |
| 10 | file-refactor | deployment_system.gd 拆分 | `story-018-deployment-emitter-split.md` | Refactor | 0.5d | — | Done |
| 11 | file-refactor | formation_system.gd 拆分 | `story-019-formation-conditions-split.md` | Refactor | 0.5d | — | Done |
| 12 | qa | Sprint 12 QA 签收 | `story-020-sprint-12-qa.md` | — | 0.5d | #1-11 | Not Started |

**总计**：12 story，预估 8.5d（含 QA）

## 关键决策

1. **拆分模式同 Sprint 8-11**——提取到 RefCounted 子模块，持有 `_parent: Node` 引用
2. **不新增 Autoload**——全部使用 RefCounted 子模块
3. **3 个文件不拆**——combat_system（已深拆 3 个子模块，剩余高度耦合）、save_load_system（测试大量调用私有方法）、progression_system（已拆序列化，剩余核心内聚）
4. **预期结果**——超限文件从 10 个减少到 3 个

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| 文件重构引入回归 | 低 | 高 | 纯结构变更，不修改逻辑，现有测试验证行为不变 |
| binding_manager 拆分风险较高 | 中 | 中 | 槽位查询逻辑相对独立，但需注意 _parent 引用链路 |
| ai_system 二次拆分风险 | 中 | 中 | Boss 阶段逻辑已独立，但与 decision_engine 边界需厘清 |

## 全量测试基线（Sprint 11 结束）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195

## 此冲刺的完成定义

- [ ] 所有必须完成的任务已完成（12 项）
- [ ] 所有任务通过验收标准
- [ ] 零回归——2455 个既有测试全部通过
- [ ] 无新增 Autoload
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS
