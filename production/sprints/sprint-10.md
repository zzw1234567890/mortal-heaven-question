# Sprint 10: 继续技术债务清理——文件重构（第三轮）

> **Sprint**: 10
> **Start Date**: 2026-09-04
> **End Date**: 2026-09-11
> **Status**: Complete
> **Focus**: 继续清理超 300 行文件，将 17 个超限文件减少到 ~10 个
> **Milestone**: tech-debt-cleanup（技术债务清理）
> **Review Mode**: full
> **Last Updated**: 2026-09-04

## Sprint Goal

继续 Sprint 8+9 的文件重构工作，拆分 7 个中高收益文件（400-580 行区间）。零回归为硬约束——现有 2455 个测试全部通过。

## 容量

- 总天数：7（2026-09-04 至 2026-09-11）
- 缓冲（20%）：1.5 天
- 可用：5.5 天
- 速度基准：8 story / 6.5d ≈ 1.2 story/天

## Stories

### 必须完成（关键路径）—— 8 项

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | file-refactor | status_effect_system.gd 拆分 | `file-refactor/story-001-status-effect-split.md` | Refactor | 1.0d | — | Done |
| 2 | file-refactor | ai_system.gd 拆分 | `file-refactor/story-002-ai-roster-split.md` | Refactor | 1.0d | — | Done |
| 3 | file-refactor | deck_editing_system.gd 拆分 | `file-refactor/story-003-deck-shop-split.md` | Refactor | 0.5d | — | Done |
| 4 | file-refactor | inscription_system.gd 拆分 | `file-refactor/story-004-inscription-candidates-split.md` | Refactor | 0.5d | — | Done |
| 5 | file-refactor | story_system.gd 拆分 | `file-refactor/story-005-story-chapter-split.md` | Refactor | 1.0d | — | Done |
| 6 | file-refactor | card_system.gd 拆分 | `file-refactor/story-006-card-serializer-split.md` | Refactor | 1.0d | — | Done |
| 7 | file-refactor | scene_manager.gd 拆分 | `file-refactor/story-007-scene-transition-split.md` | Refactor | 1.0d | — | Done |
| 8 | qa | Sprint 10 QA 签收 | `qa/story-001-sprint-10-qa.md` | — | 0.5d | #1-7 | Done |

**总计**：8 story，预估 6.5d（含 QA）

## 关键决策

1. **拆分模式同 Sprint 8/9**——提取到 RefCounted 子模块，持有 `_parent: Node` 引用
2. **不新增 Autoload**——全部使用 RefCounted 子模块
3. **save_load_system.gd 继续推迟**——164 处测试调用私有方法，高风险低收益
4. **gsm_atomic_writes.gd 继续推迟**——922 行但本身已是子模块，按域再拆需大量测试调用点验证
5. **exploration_system.gd 继续推迟**——1010 行但 Sprint 8 已拆 DAG+经济委托

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| 文件重构引入回归 | 中 | 高 | 纯结构变更，不修改逻辑，现有测试验证行为不变 |
| scene_manager 异步转换管线拆分破坏场景切换 | 中 | 高 | 仅提取转换执行方法，保留编排逻辑在主文件 |
| ai_system 工厂逻辑拆分破坏敌方生成 | 低 | 中 | roster 工厂逻辑相对独立，已拆出 decision_engine + boss_phases |

## 全量测试基线（Sprint 9 结束）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195

## 此冲刺的完成定义

- [x] 所有必须完成的任务已完成（8 项）
- [x] 所有任务通过验收标准
- [x] 零回归——2455 个既有测试全部通过
- [x] 无新增 Autoload
- [x] QA 签收报告：APPROVED
