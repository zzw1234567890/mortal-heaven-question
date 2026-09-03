# Sprint 8: 技术债务清理——桩接线 + 文件重构

> **Sprint**: 8
> **Start Date**: 2026-09-03
> **End Date**: 2026-09-10
> **Status**: Complete
> **Focus**: 清理关键桩接线（CombatSystem / BindingManager / CardEffectEngine）+ 文件超 300 行重构，为 UI 层构建稳固逻辑基础
> **Milestone**: tech-debt-cleanup（技术债务清理）
> **Review Mode**: full
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-09-03

## Sprint Goal

清理 Sprint 1-7 积累的技术债务：121 处桩/stub/placeholder 代码接线 + 24 个超 300 行文件重构。零回归为硬约束——现有 2367 个测试全部通过。

## 容量

- 总天数：7（2026-09-03 至 2026-09-10，日历日）
- 缓冲（20%）：1.5 天
- 可用：5.5 天
- 速度基准：日历日——Sprint 7 为 14 story / 5.5 天 ≈ 2.5 story/天；本冲刺 14 story / 5.5 天 ≈ 2.5 story/天——重构类 Story 预估 1.0d，桩接线类 0.5d

## Stories

### 必须完成（关键路径）—— 14 项

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | combat-wiring | CombatSystem 牌库管理内建 | `combat-wiring/story-001-deck-management.md` | Logic | 0.5d | — | Done |
| 2 | combat-wiring | CombatSystem 回调接线 CardEffectEngine+CardSystem | `combat-wiring/story-002-callback-wiring.md` | Logic | 0.5d | #1 | Done |
| 3 | combat-wiring | CombatSystem _enter_phase 子系统编排接线 | `combat-wiring/story-003-phase-orchestration.md` | Integration | 0.5d | #2 | Done |
| 4 | combat-wiring | CombatSystem AISystem 接线 | `combat-wiring/story-004-ai-wiring.md` | Logic | 0.5d | #3 | Done |
| 5 | combat-wiring | CombatSystem 战斗奖励结算 | `combat-wiring/story-005-reward-settlement.md` | Logic | 0.5d | #4 | Done |
| 6 | combat-wiring | CombatSystem _resolve_attack_queue is_kill 修正 | `combat-wiring/story-006-kill-derivation.md` | Logic | 0.5d | #5 | Merged into #5 |
| 7 | binding-wiring | BindingManager 存根回调接线 | `binding-wiring/story-001-stub-wiring.md` | Logic | 0.5d | #2 | Done |
| 8 | binding-wiring | CardEffectEngine 子模块接线 | `binding-wiring/story-002-engine-wiring.md` | Logic | 0.5d | #7 | Done |
| 9 | file-refactor | exploration_system.gd 拆分 | `file-refactor/story-001-exploration-split.md` | Refactor | 1.0d | — | Done |
| 10 | file-refactor | combat_system.gd 拆分 | `file-refactor/story-002-combat-split.md` | Refactor | 1.0d | #6 | Done |
| 11 | file-refactor | gsm_atomic_writes.gd + save_load_system.gd 拆分 | `file-refactor/story-003-gsm-save-split.md` | Refactor | 1.0d | — | Done |
| 12 | file-refactor | binding_manager.gd + ai_system.gd 拆分 | `file-refactor/story-004-binding-ai-split.md` | Refactor | 1.0d | #7 | Done |
| 13 | misc-wiring | DialoguePlayer 条件评估器接线 | `misc-wiring/story-001-dialogue-conditions.md` | Logic | 0.5d | — | Done |
| 14 | qa | Sprint 8 QA 签收 | `qa/story-001-sprint-8-qa.md` | — | 0.5d | #1-13 | Done |

**总计**：14 story，预估 9.0d（含 QA）

## 关键决策

1. **不新建 DeckSystem**——战斗内牌库管理归 CombatSystem 内建
2. **拆分模式参照 Sprint 3 GSM 拆分先例**——提取到 RefCounted 子模块
3. **桩接线顺序**：牌库→回调→编排→AI→奖励→攻击结算
4. **文件重构与桩接线同步**——combat_system.gd 拆分在桩接线完成后进行

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| 桩接线破坏现有测试 | 高 | 高 | 每个 Story 完成后运行全量测试，零回归才继续 |
| 文件重构引入回归 | 中 | 高 | 纯结构变更，不修改逻辑，现有测试验证行为不变 |
| 桩代码被测试依赖 | 高 | 中 | 保留测试桩注入方法但标记为 deprecated，生产代码使用 Autoload |
| 接线目标 Autoload 不存在 | 低 | 高 | 接线前验证 Autoload 已注册 |

## 全量测试基线（Sprint 7 结束）

- Scripts: 135 / Tests: 2367 / Passing: 2366 / Pending: 1 / Failing: 0 / Asserts: 8984

## 此冲刺的完成定义

- [x] 所有必须完成的任务已完成（14 项）
- [x] 所有任务通过验收标准
- [x] QA 计划已存在
- [x] 所有逻辑/集成类故事有通过的单元/集成测试
- [x] 冒烟检查已通过 (`/smoke-check sprint`)
- [x] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [x] 已交付特性中无 S1 或 S2 的 bug
- [x] 零回归——2367 个既有测试全部通过
- [x] 无新增 Autoload
