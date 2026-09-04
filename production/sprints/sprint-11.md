# Sprint 11: 技术债务清理——文件重构（第四轮）

> **Sprint**: 11
> **Start Date**: 2026-09-04
> **End Date**: 2026-09-11
> **Status**: Complete
> **Focus**: 拆分最后 3 个未拆分的超 300 行文件
> **Milestone**: tech-debt-cleanup（技术债务清理）
> **Review Mode**: full
> **Last Updated**: 2026-09-04

## Sprint Goal

拆分 input_manager / faction_system / ending_evaluator 三个剩余未拆分超限文件。零回归为硬约束——现有 2455 个测试全部通过。

## 容量

- 总天数：7（2026-09-04 至 2026-09-11）
- 缓冲（20%）：1.5 天
- 可用：5.5 天
- 速度基准：4 story / 4.0d ≈ 1.0 story/天

## Stories

### 必须完成（关键路径）—— 4 项

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | file-refactor | input_manager.gd 拆分 | `file-refactor/story-001-input-lock-split.md` | Refactor | 1.0d | — | Done |
| 2 | file-refactor | faction_system.gd 拆分 | `file-refactor/story-002-faction-stats-split.md` | Refactor | 1.0d | — | Done |
| 3 | file-refactor | ending_evaluator.gd 拆分 | `file-refactor/story-003-ending-epilogue-split.md` | Refactor | 1.0d | — | Done |
| 4 | qa | Sprint 11 QA 签收 | `qa/story-001-sprint-11-qa.md` | — | 0.5d | #1-3 | Done |

**总计**：4 story，预估 3.5d（含 QA）

## 关键决策

1. **拆分模式同 Sprint 8/9/10**——提取到 RefCounted 子模块，持有 `_parent: Node` 引用
2. **不新增 Autoload**——全部使用 RefCounted 子模块
3. **仅拆从未拆分文件**——input_manager / faction_system / ending_evaluator

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| 文件重构引入回归 | 低 | 高 | 纯结构变更，不修改逻辑，现有测试验证行为不变 |

## 全量测试基线（Sprint 10 结束）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195

## 此冲刺的完成定义

- [x] 所有必须完成的任务已完成（4 项）
- [x] 所有任务通过验收标准
- [x] 零回归——2455 个既有测试全部通过
- [x] 无新增 Autoload
- [x] QA 签收报告：APPROVED