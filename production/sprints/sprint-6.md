# Sprint 6: 叙事经济线——身份选择 + 炼丹铭刻 + 章节推进 + 结局分支

> **Sprint**: 6
> **Start Date**: 2026-08-31
> **End Date**: 2026-09-07
> **Status**: Complete
> **Focus**: Feature 层叙事经济子系统 5 Epic（IdentitySelectionSystem / AlchemyCraftingSystem / InscriptionSystem / StorySystem / EndingBranchSystem）——MVP 核心循环第三支柱：身份开局 + 经济补充 + 叙事骨干
> **Milestone**: feature-layer-narrative（叙事经济线完成）
> **Review Mode**: full
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-31

## Sprint Goal

实现叙事经济线 5 Epic 共 17 Story，形成**完整的叙事循环**——开局身份选择 + 炼丹炼器经济补充 + 法宝铭刻属性强化 + 章节推进叙事骨干 + 结局分支判定。这是 MVP 关键路径的第三支柱：玩家选择身份开局，在探索中炼丹铭刻强化装备，通过 5 章剧情推进至通关结局。

## 容量

- 总天数：7（2026-08-31 至 2026-09-07，日历日）
- 缓冲（20%）：1.5 天
- 可用：5.5 天
- 速度基准：日历日——Sprint 5 为 17 story / 5.5 天 ≈ 3.1 story/天；本冲刺 17 story / 5.5 天 ≈ 3.1 story/天——与 Sprint 5 持平
- 参考速度：Sprint 5 Feature 层 4 Epic 复杂度持平；本冲刺 alchemy + inscription 为纯逻辑 RefCounted 服务类（无 Autoload 开销），story-system 为章节编排（GSM narrative 域写入）

> **范围说明**：本冲刺 5 Epic 均 must-have。identity-selection 是游戏循环入口；alchemy/inscription 是经济补充（纯逻辑服务类）；story-system 是叙事骨干；ending-branch 是通关结局判定。五者形成完整叙事经济闭环。reincarnation + achievement 6 Story 需 ProgressionSystem 先实现，留 Sprint 7。

## PR-SPRINT 关卡

- **裁决**：待 producer 评估
- **主要风险点**：
  - story-system ADR-0026 要求 StorySystem 为 narrative.* 域独占写入者——需确认 GSM narrative 域已就绪
  - ending-branch 嵌入 StorySystem（非独立 Autoload）——需在 story-system 003 后实现
  - identity-selection apply_identity 编排 DeckEditingSystem.initialize_initial_deck（Sprint 5 已实现）——跨 Epic 依赖
  - 2 个新 Autoload（IdentitySelectionSystem #21 + StorySystem #25）——需在 6-0 中注册

## Stories

### 必须完成（关键路径）—— 17 项

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | identity-selection-system | 身份模板 const Dictionary（6 个）+ 查询 API | `identity-selection-system/story-001-*.md` | Logic | 0.5d | — | Done |
| 2 | identity-selection-system | apply_identity 原子操作（编排现有服务 API） | `identity-selection-system/story-002-*.md` | Integration | 0.5d | #1 | Done |
| 3 | identity-selection-system | is_identity_selected / get_current_identity | `identity-selection-system/story-003-*.md` | Logic | 0.5d | #1 | Done |
| 4 | alchemy-crafting-system | 配方表（const Dictionary, 8 配方）+ 查询 API | `alchemy-crafting-system/story-001-*.md` | Logic | 0.5d | — | Done |
| 5 | alchemy-crafting-system | craft_pill / craft_artifact 炼制编排 | `alchemy-crafting-system/story-002-*.md` | Logic | 0.5d | #4 | Done |
| 6 | alchemy-crafting-system | roll_quality / forge_artifact_stat 品质与属性 | `alchemy-crafting-system/story-003-*.md` | Logic | 0.5d | #4 | Done |
| 7 | alchemy-crafting-system | apply_reroll 品质重掷 + 独立 RNG 实例 | `alchemy-crafting-system/story-004-*.md` | Logic | 0.5d | #6 | Done |
| 8 | inscription-system | generate_candidates 候选属性生成 | `inscription-system/story-001-*.md` | Logic | 0.5d | — | Done |
| 9 | inscription-system | inscribe / apply_inscription 铭刻编排 | `inscription-system/story-002-*.md` | Logic | 0.5d | #8 | Done |
| 10 | inscription-system | inscription_cost / dismantle_inscription_refund 成本 | `inscription-system/story-003-*.md` | Logic | 0.5d | #8 | Done |
| 11 | story-system | CHAPTER_TEMPLATES 5 章静态定义（const Dictionary） | `story-system/story-001-*.md` | Logic | 0.5d | — | Done |
| 12 | story-system | can_enter_chapter / get_chapter_context | `story-system/story-002-*.md` | Logic | 0.5d | #11 | Done |
| 13 | story-system | complete_chapter + GSM narrative.* 独占写入 | `story-system/story-003-*.md` | Integration | 0.5d | #12 | Done |
| 14 | story-system | is_boss_unlocked / on_boss_defeated | `story-system/story-004-*.md` | Logic | 0.5d | #13 | Done |
| 15 | ending-branch-system | EndingEvaluator 纯函数工具类 + evaluate_ending | `ending-branch-system/story-001-*.md` | Logic | 0.5d | #13 | Done |
| 16 | ending-branch-system | _calculate_scores / _resolve_tie 评分与平局 | `ending-branch-system/story-002-*.md` | Logic | 0.5d | #15 | Done |
| 17 | ending-branch-system | _determine_variant / _generate_epilogue 变体与尾声 | `ending-branch-system/story-003-*.md` | Logic | 0.5d | #16 | Done |

**总计**：17 story，预估 8.5d

## 上一个冲刺的结转项

| 任务 | 原因 | 新预估 |
|------|------|-------------|
| Feature 层文件超 300 行重构 | Sprint 4/5 QA 遗留 CONDITION | 流程项，非 story，Sprint 6 期间按需重构 |
| CardSystem 掉落规则接线 | Sprint 5 桩实现遗留 | 后续 Sprint 接线 |
| RealmSystem 天劫 Boss 配置接线 | Sprint 5 桩实现遗留 | 后续 Sprint 接线 |
| StatusEffectSystem 心魔 debuff 接线 | Sprint 5 桩实现遗留 | 后续 Sprint 接线 |

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| story-system narrative.* 域独占写入冲突 | 低 | 中 | ADR-0026 明确 StorySystem 为唯一写入者，story_flags 委托 EventSystem |
| ending-branch 嵌入 StorySystem 架构 | 低 | 低 | ADR-0029 明确 EndingEvaluator 为 RefCounted 工具类，通关时实例化 |
| identity-selection apply_identity 跨 Epic 编排 | 中 | 中 | 编排 DeckEditingSystem.initialize_initial_deck（Sprint 5 已实现）+ CardSystem.create_instance |
| alchemy/inscription 纯逻辑服务类无 Autoload | 低 | 低 | RefCounted 模式，无需注册 project.godot |

## 外部因素依赖

无（Feature 层依赖 Foundation + Core + Sprint 4/5 已就绪系统，均已实现）

## 此冲刺的完成定义

- [x] 所有必须完成的任务已完成（17 项）
- [x] 所有任务通过验收标准
- [x] QA 计划已存在
- [x] 所有逻辑/集成类故事有通过的单元/集成测试
- [x] 冒烟检查已通过 (`/smoke-check sprint`)
- [x] QA 签收报告：APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [x] 已交付特性中无 S1 或 S2 的 bug
- [x] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [x] 2 个新 Autoload 已注册且顺序验证通过（IdentitySelectionSystem #21 + StorySystem #25）

## 关键依赖链

- **identity-selection-system**：001（模板）→ 002（apply_identity 编排）+ 003（查询）
- **alchemy-crafting-system**：001（配方表）→ 002（炼制编排）+ 003（品质属性）→ 004（重掷）
- **inscription-system**：001（候选生成）→ 002（铭刻编排）+ 003（成本返还）
- **story-system**：001（章节模板）→ 002（章节判定）→ 003（GSM narrative 域写入）→ 004（Boss 解锁）
- **ending-branch-system**：001（EndingEvaluator）→ 002（评分平局）→ 003（变体尾声）——依赖 story-system #003（narrative 域就绪）
- **跨 Epic 依赖**：identity-selection #002 → DeckEditingSystem.initialize_initial_deck（Sprint 5 已实现）；ending-branch #001 → story-system #003

## Autoload 注册

Sprint 6 新增 2 个 Feature 层 Autoload：

| Autoload | 编号 | 脚本路径 | 依赖 |
|----------|:----:|----------|------|
| IdentitySelectionSystem | #21 | `res://src/feature/identity_selection_system.gd` | GSM, CardSystem, DeckEditingSystem |
| StorySystem | #25 | `res://src/feature/story_system.gd` | GSM, EventSystem |

AlchemyCraftingSystem 和 InscriptionSystem 为 RefCounted 服务类，不注册 Autoload。EndingBranchSystem 的 EndingEvaluator 嵌入 StorySystem，不独立注册。

## Next Steps

1. `/qa-plan sprint`——为 17 story 定义测试用例需求
2. `/dev-story` 从 6-1（identity-selection 模板）起逐条填充 AC 并实现
3. 或并行启动 alchemy-crafting-system / inscription-system（无跨 Epic 依赖）

## 范围检查

> **Scope Check**: 若此冲刺包含了超出原始 Epic 范围的故事，在实现开始前运行 `/scope-check [epic]` 以检测范围蔓延。
