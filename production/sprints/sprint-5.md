# Sprint 5: 探索经济线——探索 + 修为 + 渡劫 + 卡组编辑

> **Sprint**: 5
> **Start Date**: 2026-08-29
> **End Date**: 2026-09-05
> **Status**: Active
> **Focus**: Feature 层探索经济子系统 4 Epic（ExplorationSystem / CultivationSystem / TribulationSystem / DeckEditingSystem）——MVP 核心循环第二支柱：探索 → 修为 → 突破
> **Milestone**: feature-layer-exploration（探索经济线完成）
> **Review Mode**: full
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Sprint Goal

实现探索经济线 4 Epic 共 17 Story，形成**可运行的探索循环**——程序化 DAG 地图生成 + 节点导航 + 修为获取与溢出 + 渡劫突破 + 卡组编辑。这是 MVP 关键路径的第二支柱：玩家在探索中获取修为，积累后渡劫突破，解锁更高境界地图。

## 容量

- 总天数：7（2026-08-29 至 2026-09-05，日历日）
- 缓冲（20%）：1.5 天
- 可用：5.5 天
- 速度基准：日历日——Sprint 4 为 25 story / 8 天 ≈ 3.1 story/天；本冲刺 17 story / 5.5 天 ≈ 3.1 story/天——与 Sprint 4 持平
- 参考速度：Sprint 4 Feature 层 AC 密度高于 Core，压缩率 ~1.3x；本冲刺 exploration-system 含 DAG 程序化生成复杂度高（类似 Sprint 4 的 combat-system 4-22）

> **范围说明**：本冲刺 4 Epic 均 must-have。exploration-system 是 MVP 核心循环第二支柱的入口；cultivation-system 是修为成长引擎；tribulation-system 是境界突破机制；deck-editing-system 是卡组管理基础。四者形成完整探索经济闭环。

## PR-SPRINT 关卡

- **裁决**：待 producer 评估
- **主要风险点**：
  - exploration-system DAG 程序化生成复杂度高（类似 Sprint 4 的 7 阶段状态机）
  - tribulation-system 依赖 CombatSystem + StatusEffectSystem 跨系统协作
  - 4 个 Autoload 新增（ExplorationSystem #14 / CultivationSystem #20 / TribulationSystem #24 / DeckEditingSystem #22）——需在 4-0 中注册
  - ADR-0014 ExplorationSystem Autoload 编号 #14 与当前 project.godot 中 CombatSystem 已占 #14 冲突——需调整编号

## Stories

### 必须完成（关键路径）—— 17 项

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | exploration-system | 程序化 DAG 地图生成（generate_map） | `exploration-system/story-001-*.md` | Logic | 1.0d | — | Done |
| 2 | exploration-system | 导航状态 GSM exploration.* 主存储 | `exploration-system/story-002-*.md` | Integration | 0.5d | #1 | Done |
| 3 | exploration-system | move_to_node / resolve_node 节点推进 | `exploration-system/story-003-*.md` | Logic | 0.5d | #1 | Done |
| 4 | exploration-system | DAG 缓存重建 + _dag_ready 就绪标志 | `exploration-system/story-004-*.md` | Integration | 0.5d | #2 | Done |
| 5 | exploration-system | 事件节点分配 + 经济计算 | `exploration-system/story-005-*.md` | Integration | 0.5d | #3 | Done |
| 6 | cultivation-system | gain_cultivation 统一获取入口 + 溢出判定 | `cultivation-system/story-001-*.md` | Logic | 0.5d | — | Done |
| 7 | cultivation-system | GSM player.* 数据存储 + batch_updated 传播 | `cultivation-system/story-002-*.md` | Integration | 0.5d | #6 | Done |
| 8 | cultivation-system | settle_overflow + 突破后溢出结算 | `cultivation-system/story-003-*.md` | Logic | 0.5d | #6 | Done |
| 9 | cultivation-system | realm_upgraded 信号订阅 + check_breakthrough | `cultivation-system/story-004-*.md` | Integration | 0.5d | #6 | Done |
| 10 | tribulation-system | 渡劫流程编排 + TribulationState 状态机 | `tribulation-system/story-001-*.md` | Logic | 1.0d | #9 | Done |
| 11 | tribulation-system | 渡劫战斗委托 CombatSystem + 天雷 debuff | `tribulation-system/story-002-*.md` | Integration | 0.5d | #10 | Done |
| 12 | tribulation-system | 渡劫丹辅助 + 成功/失败分支处理 | `tribulation-system/story-003-*.md` | Logic | 0.5d | #10 | Done |
| 13 | tribulation-system | 渡劫结果 GSM 同步 + 场景恢复 | `tribulation-system/story-004-*.md` | Integration | 0.5d | #11 | Done |
| 14 | deck-editing-system | 卡组验证器（卡组上限/添加/移除校验） | `deck-editing-system/story-001-*.md` | Logic | 0.5d | — | Done |
| 15 | deck-editing-system | 卡组编辑 API + GSM deck.* 存储 | `deck-editing-system/story-002-*.md` | Integration | 0.5d | #14 | Done |
| 16 | deck-editing-system | 卡组保存/加载 + 默认卡组 | `deck-editing-system/story-003-*.md` | Logic | 0.5d | #15 | Done |
| 17 | deck-editing-system | 卡组验证 UI 数据源接口 | `deck-editing-system/story-004-*.md` | Integration | 0.5d | #16 | Ready |

**总计**：17 story，预估 8.5d（exploration #1 + tribulation #10 各取 1.0d 上限）

## 上一个冲刺的结转项

| 任务 | 原因 | 新预估 |
|------|------|-------------|
| Feature 层文件超 300 行重构 | Sprint 4 QA 遗留 CONDITION | 流程项，非 story，Sprint 5 期间按需重构 |
| is_kill 技术债（队列读取→HP 派生） | Sprint 4 QA 遗留 CONDITION | CombatUI 接入时修复 |
| CardSystem 模板目录缺失 | Sprint 3 QA ADVISORY 遗留 | 资产管线，非 Sprint 5 范围 |

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| exploration DAG 程序化生成复杂度高 | 高 | 中 | story-001 预估上调至 1.0d；DAG 结构纯 Dictionary/Array 保证 JSON 可序列化 |
| tribulation 跨系统协作（Combat+StatusEffect） | 中 | 中 | 桩接口定义（CombatSystem.battle_start 存根、StatusEffectSystem.register 存根），可替换 |
| 4 个新 Autoload 编号冲突 | 中 | 高 | ADR-0014 标注 #14 但 project.godot 已被 CombatSystem 占据——注册时用实际位置（#19 之后），ADR 编号为规划序号非实际位置 |
| 探索→战斗→探索往返场景恢复 | 中 | 中 | ExplorationSystem 内部缓存重建模式（ADR-0014 §决策 1），读档后从 map_state 重建 DAG |
| cultivation 修为溢出边界计算 | 低 | 低 | 整数运算纯逻辑，单元测试覆盖边界 |

## 外部因素依赖

无（Feature 层依赖 Foundation + Core 层 + Sprint 4 战斗子系统，均已就绪）

## 此冲刺的完成定义

- [ ] 所有必须完成的任务已完成（17 项）
- [ ] 所有任务通过验收标准
- [ ] QA 计划已存在 (`production/qa/qa-plan-sprint-5.md`)
- [ ] 所有逻辑/集成类故事有通过的单元/集成测试
- [ ] 冒烟检查已通过 (`/smoke-check sprint`)
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [ ] 4 个新 Autoload 已注册且顺序验证通过

## 关键依赖链

- **exploration-system**：001（DAG 生成）→ 002（GSM 存储）→ 003（节点推进）→ 004（缓存重建）→ 005（事件分配）
- **cultivation-system**：001（获取入口）→ 002（GSM 存储）+ 003（溢出结算）→ 004（突破检查）
- **tribulation-system**：001（状态机）→ 002（战斗委托）→ 003（渡劫丹）→ 004（GSM 同步）——依赖 cultivation #004（check_breakthrough）
- **deck-editing-system**：001（验证器）→ 002（编辑 API）→ 003（保存/加载）→ 004（UI 数据源）
- **跨 Epic 依赖**：cultivation #004 → tribulation #001；exploration #005 → cultivation #001（事件节点修为奖励）

## Next Steps

1. `/qa-plan sprint`——为 17 story 定义测试用例需求
2. `/dev-story` 从 5-1（exploration-system DAG 生成）起逐条填充 AC 并实现
3. 或并行启动 deck-editing-system（无跨 Epic 依赖）

## 范围检查

> **Scope Check**: 若此冲刺包含了超出原始 Epic 范围的故事，在实现开始前运行 `/scope-check [epic]` 以检测范围蔓延。