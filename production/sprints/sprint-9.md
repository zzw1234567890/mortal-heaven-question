# Sprint 9: 继续技术债务清理——文件重构

> **Sprint**: 9
> **Start Date**: 2026-09-03
> **End Date**: 2026-09-10
> **Status**: Complete
> **Focus**: 继续清理超 300 行文件，将 25 个超限文件减少到 ~17 个
> **Milestone**: tech-debt-cleanup（技术债务清理）
> **Review Mode**: full
> **Last Updated**: 2026-09-03

## Sprint Goal

继续 Sprint 8 的文件重构工作，拆分 7 个高收益文件 + combat_system.gd 深拆。零回归为硬约束——现有 2455 个测试全部通过。

## 容量

- 总天数：7（2026-09-03 至 2026-09-10）
- 缓冲（20%）：1.5 天
- 可用：5.5 天
- 速度基准：9 story / 8.0d ≈ 1.5 story/天

## Stories

### 必须完成（关键路径）—— 9 项

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | file-refactor | deployment_system.gd 拆分 | `file-refactor/story-001-deployment-split.md` | Refactor | 1.0d | — | Done |
| 2 | file-refactor | school_system.gd 拆分 | `file-refactor/story-002-school-split.md` | Refactor | 1.0d | — | Done |
| 3 | file-refactor | formation_system.gd 拆分 | `file-refactor/story-003-formation-split.md` | Refactor | 1.0d | — | Done |
| 4 | file-refactor | identity_selection_system.gd 拆分 | `file-refactor/story-004-identity-split.md` | Refactor | 1.0d | — | Done |
| 5 | file-refactor | alchemy_system.gd 拆分 | `file-refactor/story-005-alchemy-split.md` | Refactor | 1.0d | — | Done |
| 6 | file-refactor | progression_system.gd 拆分 | `file-refactor/story-006-progression-split.md` | Refactor | 1.0d | — | Done |
| 7 | file-refactor | tribulation_system.gd 拆分 | `file-refactor/story-007-tribulation-split.md` | Refactor | 1.0d | — | Done |
| 8 | file-refactor | combat_system.gd 阶段管理深拆 | `file-refactor/story-008-combat-deep-split.md` | Refactor | 1.5d | — | Done |
| 9 | qa | Sprint 9 QA 签收 | `qa/story-001-sprint-9-qa.md` | — | 0.5d | #1-8 | Done |

**总计**：9 story，预估 8.0d（含 QA）

## 关键决策

1. **拆分模式同 Sprint 8**——提取到 RefCounted 子模块，持有 `_parent: Node` 引用
2. **不新增 Autoload**——全部使用 RefCounted 子模块
3. **save_load_system.gd 继续推迟**——164 处测试调用私有方法，高风险低收益
4. **combat_system.gd 深拆放最后**——风险最高，与内部状态紧耦合

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| 文件重构引入回归 | 中 | 高 | 纯结构变更，不修改逻辑，现有测试验证行为不变 |
| combat_system.gd 深拆破坏战斗流程 | 高 | 高 | 放最后执行，如有回归可回退 |
| formation_system _on_field_changed 测试直接调用 | 中 | 中 | 保留在主文件，不提取到子模块 |

## 全量测试基线（Sprint 8 结束）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195

## 此冲刺的完成定义

- [x] 所有必须完成的任务已完成（9 项）
- [x] 所有任务通过验收标准
- [x] 零回归——2455 个既有测试全部通过
- [x] 无新增 Autoload
- [x] QA 签收报告：APPROVED
