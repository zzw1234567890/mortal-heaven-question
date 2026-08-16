# Sprint 3: Core 层剩余系统 + 技术债

> **Sprint**: 3
> **Start Date**: 2026-08-10
> **End Date**: 2026-08-23
> **Status**: Complete
> **Focus**: Core 层剩余 3 系统（CostSystem / StatusEffectSystem / SchoolSystem）+ 偿还 game_state_manager.gd 技术债
> **Milestone**: core-layer-complete（Active，目标 2026-08-19——里程碑交付物仅要求 4 系统，Sprint 2 已满足；Sprint 3 视为向 Feature 层过渡的准备）
> **Review Mode**: full
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-14

## Sprint Goal

完成 Core 层剩余 3 系统（CostSystem #7 / StatusEffectSystem #8 / SchoolSystem #19）+ 偿还 Sprint 1 回顾行动项 #2（拆分 game_state_manager.gd 933+→≤300 行）。Sprint 3 结束后 Core 层 8 系统全部就绪，Feature 层（战斗、效果引擎、流派应用等）可开始构建。

## 容量

- 总天数：14
- 缓冲（20%）：3 天
- 可用：11 天（~88h @ 8h/天）
- Sprint 2 实际速度：11h/天（4 天完成 14 天计划——异常值，本冲刺按 7-8h/天保守校准）
- 计划工作量：~56h（64% 利用率，按 7-8h/天校准约 7-8 天）
- 剩余容量预留：Feature 层 Epic Story 预创建 8h

> **里程碑范围说明**：core-layer-complete 里程碑交付物仅列 4 系统（card/realm/resource/faction），Sprint 2 已 100% 满足。Sprint 3 的 3 新系统是架构定义的 Core 层完整交付物，视为向 Feature 层过渡的准备。里程碑时间无压力，但 3 系统是 Sprint 4（Feature 层）启动的前置依赖。

## PR-SPRINT 关卡

- **裁决**：CONCERNS（producer 智能体评估）
- **用户决策**：按计划进行——接受风险
- **主要风险点**：
  - status-effect 8 阶段管线复杂度高（348 行 GDD，AC 密度极高，实际可能需 3-3.5 天 vs 预估 2.5 天）
  - game_state_manager.gd 实际 1016 行（计划称 933+），拆分 + 全量回归估 1.5 天 vs 预估 1 天
  - 3-1（/create-stories 三系统 + 跨 Epic 接口契约盘点）估 1 天偏紧，是关键路径根节点
  - Sprint 2 的 11h/天是异常值，不宜外推

## Stories

### 必须完成（关键路径）—— ~44h

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | 多 Epic | /create-stories cost + status-effect + school（含跨 Epic 接口契约盘点） | — | Task | 1d | — | Done |
| 2 | cost-system | CostSystem Autoload #7：费用上限 + 全额恢复 + 临时加成 | `cost-system/story-001-*.md` | Integration | 0.5d | #1 | Done |
| 3 | cost-system | 双重信号路径（cost_changed + batch_updated） | `cost-system/story-002-*.md` | Logic | 0.5d | #2 | Done |
| 4 | status-effect | StatusTemplate/Instance + 8 阶段管线核心 | `status-effect/story-001-*.md` | Integration | 1d | #1 | Done |
| 5 | status-effect | 3 叠加规则 + 免疫多级检查 + 20 活跃上限 | `status-effect/story-002-*.md` | Logic | 1d | #4 | Done |
| 6 | status-effect | 战斗结束 snapshot 导出 GSM + 暂挂/恢复排序 | `status-effect/story-003-*.md` | Integration | 0.5d | #5 | Done |
| 7 | school-system | SchoolSystem Autoload #19：SCHOOL_LIBRARY const + 纯查询接口 | `school-system/story-001-*.md` | Logic | 0.5d | #1 | Done |
| 8 | school-system | 5 流派增益公式 + 不可驱散约束 | `school-system/story-002-*.md` | Logic | 0.5d | #7, #5 | Done |
| 9 | tech-debt | 拆分 game_state_manager.gd → gsm_serializer.gd（1016→≤300 行） | （Sprint 1 回顾行动项 #2） | Refactor | 1d | — | Done |

### 应该完成 —— ~5h

| # | Epic | Story | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|:--:|:--:|:--:|:--:|
| 10 | tech-debt | GSM 第二层方法独立单测补齐（resource/faction 新增方法） | Task | 0.5d | #9 | Done |
| 11 | docs | ADR-0003 §visited_ids 生命周期文档补充 | Doc | 0.125d | — | Done |

### 可以完成 —— 8h

| # | Epic | Story | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|:--:|:--:|:--:|:--:|
| 12 | prep | Feature 层 Epic Story 预创建（为 Sprint 4 铺路） | Planning | 1d | — | Done |

**总计**：必须完成 44h + 应该完成 5h + 可以完成 8h = 57h（65% 利用率）

## 上一个冲刺的结转项

| 任务 | 原因 | 新预估 |
|------|--------|-------------|
| Story 2-14 ADR-0003 文档 | nice-to-have 未处理 | 0.125d → 3-11 |
| Story 2-16 Feature 层预创建 | nice-to-have 未处理 | 1d → 3-12 |

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| status-effect 8 阶段管线复杂度高（348 行 GDD，AC 密度极高） | 高 | 中 | ~~Sprint 2 回顾行动项 #2 跨 Epic 接口契约盘点前置；3-4/3-5 预估已上调；实际可能需 3-3.5 天~~ **已解决：3-4 已完成，复杂度在预估范围内** |
| game_state_manager.gd 拆分引入回归（1016 行 + 3 系统引用） | 中 | 高 | 拆分后重跑全量 809 测试，零回归才合并（同 event_system 拆分模式）；拆分估 1.5 天 |
| /create-stories 跨 Epic 接口契约盘点不充分 | 中 | 中 | ~~Sprint 2 回顾行动项 #2，3-1 强制执行；估 1d 偏紧，若延期 0.5d 影响下游~~ **已解决：3-1 已完成** |
| status-effect 与 BindingManager 暂挂排序契约 | 中 | 中 | 3-6 集成测试覆盖排序契约（先 BindingManager、后 StatusEffectSystem） |
| Sprint 2 速度 11h/天不可持续 | 中 | 中 | 本冲刺按 7-8h/天保守校准，56h 需 7-8 天 vs 11 天可用 |

## 外部因素依赖

无（Core 层仅依赖 Foundation 层，已就绪；剩余 3 系统依赖 GSM + card/realm/resource/faction，已就绪）

## 此冲刺的完成定义

- [x] 所有必须完成的任务已完成
- [x] 所有任务通过验收标准
- [x] QA 计划已存在 (`production/qa/qa-plan-sprint-3-2026-08-10.md`)
- [x] 所有逻辑/集成类故事有通过的单元/集成测试
- [x] 冒烟检查已通过 (`/smoke-check sprint`)
- [x] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [x] 已交付特性中无 S1 或 S2 的 bug
- [x] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [x] game_state_manager.gd 拆分零回归（Sprint 1 回顾行动项 #2）
- [x] /create-stories 阶段跨 Epic 接口契约盘点完成（Sprint 2 回顾行动项 #2）

## 关键依赖链

- **status-effect 关键路径**: ~~001→002→003（2.5d）~~ — 001 已完成，005→006 待启动
- **cost-system**: ~~001→002（1d）~~ — **已完成**
- **school-system**: ~~001→002（1d）~~ — 001 已完成，002 待启动（依赖 #5 status-effect 剩余）
- **game_state_manager.gd 拆分**: 独立任务，可在任意空闲时段进行，但拆分后须重跑全部测试
- ~~**3-1 /create-stories**: 阻塞 3-2~3-8 共 6 个任务，是关键路径根节点，必须最先完成~~ **已完成**

## 进度摘要（2026-08-14）

**Sprint 3 全部 12/12 故事完成 ✅**

- **cost-system**: 全部完成（3-2 + 3-3）
- **status-effect**: 全部完成（3-4 + 3-5 + 3-6）
- **school-system**: 全部完成（3-7 + 3-8）
- **技术债**: 全部完成（3-9 GSM 拆分 + 3-10 单测补齐 + 3-11 ADR 文档）
- **Feature 层预创建**: 完成（3-12——18 个 Feature Epic 标题级骨架）

## Next Steps

1. 启动 Sprint 4（Feature 层）——用 `/dev-story` 从 combat-system 起逐条填充 AC 并实现（战斗子系统为 MVP 关键路径）
2. ~~修复 cost_system 既有失败~~ **已修复（2026-08-14）**：8 个失败全消除——6 个信号计数（`_track_signal` 连接晚于 `init_for_battle`，丢失 init 的 cost_changed）+ 2 个 push_warning 计数（`_write_cost_to_gsm` → `_set_battle_cost` 在 battle=null 时警告）。全量 1118 tests / 1117 passing / 1 pending（save_load 多步迁移，首版有意延后）
3. 若需回顾，运行 `/retrospective` 生成 Sprint 3 回顾报告

## 范围检查

> **Scope Check**: 若此冲刺包含了超出原始 Epic 范围的故事，在实现开始前运行 `/scope-check [epic]` 以检测范围蔓延。