# Sprint 4: Feature 层战斗子系统

> **Sprint**: 4
> **Start Date**: 2026-08-16
> **End Date**: 2026-08-23
> **Status**: Active
> **Focus**: Feature 层战斗子系统 6 Epic（CardEffectEngine / DeploymentSystem / BindingSystem / FormationSystem / AISystem / CombatSystem）——形成可运行的战斗闭环
> **Milestone**: core-layer-complete 之后（Feature 层启动，无独立里程碑）
> **Review Mode**: full
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-18

## Sprint Goal

实现 Feature 层战斗子系统 6 Epic 共 25 Story，形成**可运行的战斗闭环**——7 阶段状态机 + 卡牌效果结算引擎 + 角色上场阵位 + 功法/法宝绑定 + 阵法光环 + 敌方 AI，通过 CombatSystem 编排器贯通。这是 MVP 关键路径：战斗是游戏核心循环的结算入口。

## 容量

- 总天数：8（2026-08-16 至 2026-08-23，日历日）
- 缓冲（20%）：1.5 天
- 可用：6.5 天
- 速度基准：**日历日**（非人日）——Sprint 2/3 连续两次 4 天完成 14 天计划，回顾行动项 #3 要求改用日历日并上调基准
- 参考速度：Sprint 3 为 12 story / 4 天 = 3 story/天；本冲刺 25 story / 6.5 天 ≈ 3.8 story/天——偏紧，Feature 层 AC 密度高于 Core，压缩率可能衰减

> **范围说明**：用户决策 Sprint 4 全部 25 story 设为 **must-have**（非制作人推荐的 must 17 / should 4 / nice 4 分层）。这意味着接受"Feature 层非模板化，速度压缩率可能衰减"的风险——若中期落后，优先砍 formation-system（纯光环层，可最干净存根）与 binding-system（可存根）保 combat 闭环。

## PR-SPRINT 关卡

- **裁决**：CONCERNS（producer 智能体评估，完整报告见 session 记录）
- **用户决策**：全 25 story 均 must（接受风险）
- **制作人三项结构性建议**（均已采纳）：
  1. **AI 提 must-have**（原草案误归 should）——ADR-0008 Phase 5 敌方行动"无条件自动推进"且直接调用 `AISystem.get_next_action()`，无 AI 则回合无法跑完、战斗无法判定胜负
  2. **新增 4-0 Autoload 注册任务**——RealmSystem(#11)/SchoolSystem(#19) 已实现但未注册进 project.godot（Sprint 3 QA ADVISORY 遗留）；combat Phase 4 伤害计算依赖 `RealmSystem.get_suppression()`，不注册则 combat 无法编译/测试
  3. **4-22 预估 1d → 1.5-2d**——7 阶段状态机含验证矩阵 + enter/exit + call_deferred 调度 + 9 子系统分派 + 5 个 Cat 2b 信号，是本次最高复杂度单故事
- **主要风险点**（详见 §风险登记）：
  - Feature 层非模板化，历史 ~1.8x 压缩率可能衰减到 ~1.3-1.5x → 14.5d 预估实际需 ~10 天，超 8 天上限
  - combat 编排 9 子系统但 binding/formation 若中途未完成需存根（`get_aura_bonus()` 返回 0、`unbind()` 空操作）
  - Autoload 初始化顺序：CombatSystem 必须在 9 个子系统之后注册（正确性要求，非簿记）

## Stories

### 必须完成（关键路径）—— 26 项（25 story + 1 task）

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 0 | 多 Epic | Autoload 注册：RealmSystem #11 + SchoolSystem #19 + 6 个 Feature Autoload 顺序验证 | — | Task | 0.5d | — | In Progress |
| 1 | card-effect-engine | EffectTemplate/EffectInstance 双层对象模型（4 种子类） | `card-effect-engine/story-001-*.md` | Logic | 0.5d | — | Complete |
| 2 | card-effect-engine | ResolutionStack 栈式结算引擎（优先级队列 + LIFO + 中断插入） | `card-effect-engine/story-002-*.md` | Logic | 0.5d | #1 | Complete |
| 3 | card-effect-engine | 触发链硬限制 10 层 + visited_card_ids 循环检测 | `card-effect-engine/story-003-*.md` | Logic | 0.5d | #2 | Complete |
| 4 | card-effect-engine | PRD 伪随机分布引擎（5% 步进 + 怜悯保护） | `card-effect-engine/story-004-*.md` | Logic | 0.5d | #1 | Complete |
| 5 | card-effect-engine | AI 干跑评估接口（GameStateSnapshot 不可变纯计算） | `card-effect-engine/story-005-*.md` | Logic | 0.5d | #3, #4 | Complete |
| 6 | deployment-system | 内部状态机 + 阵位数据管理（STANDBY→READY→ACTED） | `deployment-system/story-001-*.md` | Logic | 0.5d | — | Complete |
| 7 | deployment-system | deploy / remove / is_targetable 前后排保护 O(1) | `deployment-system/story-002-*.md` | Logic | 0.5d | #6 | Complete |
| 8 | deployment-system | 战斗结束 serialize_field 快照导出 GSM.battle.deployment_snapshot | `deployment-system/story-003-*.md` | Integration | 0.5d | #7 | Complete |
| 9 | deployment-system | clear_standby_state + mark_unavailable + revive_character | `deployment-system/story-004-*.md` | Logic | 0.5d | #7 | Complete |
| 10 | binding-system | BindingRecord RefCounted 实例模型 + 内部注册表 | `binding-system/story-001-*.md` | Logic | 0.5d | — | Complete |
| 11 | binding-system | bind / unbind / get_bindings 查询 API | `binding-system/story-002-*.md` | Logic | 0.5d | #10 | Ready |
| 12 | binding-system | 绑定生命周期信号总线（7 个 Cat 2b 信号） | `binding-system/story-003-*.md` | Integration | 0.5d | #11 | Ready |
| 13 | binding-system | serialize_all 快照导出 + persistent effect 接口 | `binding-system/story-004-*.md` | Integration | 0.5d | #11 | Ready |
| 14 | formation-system | 内部条件状态机 + 阵法位管理 | `formation-system/story-001-*.md` | Logic | 0.5d | — | Ready |
| 15 | formation-system | 激活条件实时重判（订阅 deployment 信号） | `formation-system/story-002-*.md` | Integration | 0.5d | #14, #7 | Ready |
| 16 | formation-system | get_aura_bonus O(1) 查询 + 梯度光环计算 | `formation-system/story-003-*.md` | Logic | 0.5d | #14 | Ready |
| 17 | formation-system | serialize_all 快照导出 GSM.battle.formation_snapshot | `formation-system/story-004-*.md` | Integration | 0.5d | #16 | Ready |
| 18 | ai-system | EnemyTemplate Resource + EnemyFactory + EnemyBattleState | `ai-system/story-001-*.md` | Logic | 0.5d | #0 | Ready |
| 19 | ai-system | execute_turn 决策主循环（普通/精英/Boss 分支） | `ai-system/story-002-*.md` | Logic | 0.5d | #18, #5 | Ready |
| 20 | ai-system | BossPhaseMgr 阶段转换内部状态机 | `ai-system/story-003-*.md` | Logic | 0.5d | #18 | Ready |
| 21 | ai-system | 难度缩放 + register_preconfigured_bindings | `ai-system/story-004-*.md` | Logic | 0.5d | #19, #20 | Ready |
| 22 | combat-system | 7 阶段回合状态机（advance_phase 确定性推进 + 阶段转换校验） | `combat-system/story-001-*.md` | Logic | 1.5d | #5, #7, #13, #17, #21 | Ready |
| 23 | combat-system | 战斗生命周期编排（battle_start / battle_end + GSM battle.* 域） | `combat-system/story-002-*.md` | Integration | 0.5d | #22 | Ready |
| 24 | combat-system | play_card 出牌 + 目标解析 + 自动推进调度 | `combat-system/story-003-*.md` | Logic | 0.5d | #22 | Ready |
| 25 | combat-system | 阶段转换 Cat 2b 信号通知 CombatUI | `combat-system/story-004-*.md` | Integration | 0.5d | #23 | Ready |

**总计**：25 story + 1 task = 26 项，预估 14.5d（4-22 取 1.5d 下限；上限 2d → 15d）

## 上一个冲刺的结转项

| 任务 | 原因 | 新预估 |
|------|--------|-------------|
| RealmSystem/SchoolSystem Autoload 注册 | Sprint 3 QA ADVISORY 遗留——已实现但未注册 project.godot | 并入 4-0（0.5d） |
| /story-done 门禁强化（全量零回归 + orphan + parse error） | Sprint 3 回顾行动项 #1 | 流程项，非 story，Sprint 4 开始前落实 |
| 测试清单完整性检查（test_ 前缀 + 可加载性） | Sprint 3 回顾行动项 #2 | 流程项，并入 /story-done 门禁 |
| 速度基准改用日历日 | Sprint 3 回顾行动项 #3 | 本冲刺容量已按日历日规划 |

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| Feature 层非模板化，~1.8x 压缩率衰减 | 中 | 高 | 全 25 story 均 must 是用户决策；若中期落后，优先砍 formation（纯光环层）+ binding（可存根）保 combat 闭环 |
| combat 编排 9 子系统但 binding/formation 中途未完成 | 高 | 中 | 存根接口显式定义（`get_aura_bonus()` 返回 0、`unbind()` 空操作），确保可替换 |
| Autoload 初始化顺序（CombatSystem 依赖 9 子系统） | 中 | 高 | 4-0b 终验 + `_ready()` 检查 `_initialized` 标志（ADR-0008 已定模式）；CombatSystem 最后注册 |
| 7 阶段状态机复杂度高（ADR-0008 为 348 行 GDD 级） | 高 | 中 | 4-22 预估已上调至 1.5-2d；`/dev-story` 填充 AC 时若 AC>20 需再上调 |
| GSM battle.* 快照写入边界歧义 | 中 | 低 | deployment/binding/formation 的 serialize story 需在 AC 明确"战斗期间各子系统内部态，战斗结束由 CombatSystem 编排导出"（ADR-0008 已声明 CombatSystem 独占 battle.* 运行时写入） |
| AI ↔ Combat 循环依赖风险 | 低 | 中 | AI 只消费 `GameStateSnapshot`（4-5）与传入的 `enemy/field` 参数，不回调 CombatSystem——在 ai-system AC 显式写明"AI 不持有 CombatSystem 引用" |

## 外部因素依赖

无（Feature 层依赖 Foundation + Core 层，均已就绪；需在 4-0 补齐 RealmSystem/SchoolSystem Autoload 注册这一内部前置）

## 此冲刺的完成定义

- [ ] 所有必须完成的任务已完成（26 项）
- [ ] 所有任务通过验收标准
- [ ] QA 计划已存在 (`production/qa/qa-plan-sprint-4.md`)
- [ ] 所有逻辑/集成类故事有通过的单元/集成测试
- [ ] 冒烟检查已通过 (`/smoke-check sprint`)
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [ ] /story-done 门禁已强化（全量零回归 + orphan + parse error 检查——Sprint 3 回顾行动项 #1/#2）
- [ ] RealmSystem(#11)/SchoolSystem(#19)/6 个 Feature Autoload 已注册且顺序验证通过（4-0）

## 关键依赖链

- **card-effect-engine 关键路径**（结算引擎，无下游依赖，最先做）：001→002→003→005，004→005（PRD 可并行）
- **deployment-system**：001→002→003/004（纯逻辑，可较早启动）
- **binding-system**：001→002→003/004
- **formation-system**：001→002（依赖 deployment 信号）→003→004
- **ai-system**：001→002（依赖 card-effect 005 的 GameStateSnapshot）→003→004
- **combat-system（编排器，最后做）**：4-22 依赖全部 5 子系统（#5/#7/#13/#17/#21）→ 4-23→4-24→4-25
- **4-0（Autoload 注册）**：Day 1 先注册 RealmSystem+SchoolSystem 解除 combat 伤害计算阻塞；combat 集成测试前完成 6 个 Feature Autoload 顺序终验

## Next Steps

1. **落实 Sprint 3 回顾行动项 #1/#2**：强化 `/story-done` 门禁 + 测试清单完整性检查（Sprint 4 开始前）
2. `/qa-plan sprint`——为 25 story 定义测试用例需求（实现前必需）
3. `/dev-story` 从 4-0（Autoload 注册）→ card-effect-engine story-001 起逐条填充 AC 并实现
4. `/scope-check` 各 Epic——实现开始前验证无范围蔓延

## 范围检查

> **Scope Check**: 若此冲刺包含了超出原始 Epic 范围的故事，在实现开始前运行 `/scope-check [epic]` 以检测范围蔓延。
