# Sprint 7: Meta 层 + 叙事收束——ProgressionSystem + 轮回天赋 + 成就 + 对话

> **Sprint**: 7
> **Start Date**: 2026-09-01
> **End Date**: 2026-09-08
> **Status**: Active
> **Focus**: Meta 层 ProgressionSystem Autoload + 3 个 Feature 层 Epic（ReincarnationTalentSystem / AchievementSystem / DialogueSystem）——跨局元进度基础设施 + 轮回结算 + 成就判定 + 对话播放
> **Milestone**: meta-layer-complete（Meta 层完成）
> **Review Mode**: full
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-09-01

## Sprint Goal

实现 Meta 层 ProgressionSystem Autoload #12——拥有所有跨局元进度数据，取代 GSM progression.* 域。在此基础设施上实现 3 个 Feature 层 Epic：轮回天赋系统（天赋树 + 轮回结算 + 跨局继承）、成就系统（62 成就 + 解锁判定 + 图鉴集成）、对话系统（DialoguePlayer + 条件分支 + BarkManager）。

## 容量

- 总天数：7（2026-09-01 至 2026-09-08，日历日）
- 缓冲（20%）：1.5 天
- 可用：5.5 天
- 速度基准：日历日——Sprint 6 为 17 story / 5.5 天 ≈ 3.1 story/天；本冲刺 14 story / 5.5 天 ≈ 2.5 story/天——略降因 ProgressionSystem 为 Meta 层基础设施（Autoload + 序列化 + 信号去重），复杂度高于纯逻辑服务类

> **范围说明**：ProgressionSystem 是 Sprint 6 规划中明确的留 Sprint 7 实现项（reincarnation + achievement 需 ProgressionSystem 先实现）。对话系统为 RefCounted 服务类（ADR-0027），无 Autoload 依赖，可与 ProgressionSystem 并行。

## PR-SPRINT 关卡

- **裁决**：待 producer 评估
- **主要风险点**：
  - ProgressionSystem 取代 GSM progression.* 域——需确认 GSM 已移除 progression 域或已标记 superseded
  - ProgressionSystem Autoload #12 初始化顺序——需在 SaveLoadSystem #4 之后、特征系统之前
  - SaveLoadSystem 接口调整——load_progression / save_progression 对接 ProgressionSystem 而非 GSM
  - 轮回天赋 5 分支 × 4 层 = 20 节点天赋树——const Dictionary 数据量大
  - 成就系统 62 成就——const Dictionary 数据量大
  - 对话系统 80-110 对话树——JSON 按需加载

## Stories

### 必须完成（关键路径）—— 14 项

| # | Epic | Story | 文件 | 类型 | 预估 | 依赖 | 状态 |
|:--|------|:--|------|:--:|:--:|:--:|:--:|
| 1 | progression-system | 域存储 + initialize + serialize/deserialize | `progression-system/story-001-*.md` | Logic | 0.5d | — | Done |
| 2 | progression-system | achievements 领域 API | `progression-system/story-002-*.md` | Logic | 0.5d | #1 | Done |
| 3 | progression-system | talents 领域 API | `progression-system/story-003-*.md` | Logic | 0.5d | #1 | Done |
| 4 | progression-system | endings + gallery + stats + meta 领域 API | `progression-system/story-004-*.md` | Logic | 0.5d | #1 | Done |
| 5 | progression-system | progression_updated 信号 + batch_update + SaveLoad 集成 | `progression-system/story-005-*.md` | Integration | 0.5d | #1~#4 | Done |
| 6 | reincarnation-talent-system | PlayerTalents 天赋树 + 查询 API | `reincarnation-talent-system/story-001-*.md` | Logic | 0.5d | #3 | Done |
| 7 | reincarnation-talent-system | unlock_talent / get_active_talents | `reincarnation-talent-system/story-002-*.md` | Logic | 0.5d | #6 | Done |
| 8 | reincarnation-talent-system | settle_run 轮回结算（跨局天赋继承） | `reincarnation-talent-system/story-003-*.md` | Integration | 0.5d | #7 | Done |
| 9 | achievement-system | Achievement 实例 + 解锁状态管理 | `achievement-system/story-001-*.md` | Logic | 0.5d | #2 | Done |
| 10 | achievement-system | check(criteria) 判定引擎 | `achievement-system/story-002-*.md` | Logic | 0.5d | #9 | Done |
| 11 | achievement-system | get_achievements 查询 + 图鉴集成 | `achievement-system/story-003-*.md` | Integration | 0.5d | #10 | Done |
| 12 | dialogue-system | DialoguePlayer + DialogueDatabase 数据结构 | `dialogue-system/story-001-*.md` | Logic | 0.5d | — | Done |
| 13 | dialogue-system | start_dialogue / select_option / advance 播放编排 | `dialogue-system/story-002-*.md` | Logic | 0.5d | #12 | Done |
| 14 | dialogue-system | BarkManager + play_bark + get_bark_history | `dialogue-system/story-003-*.md` | Logic | 0.5d | #12 | Done |

**总计**：14 story，预估 7.0d

## 上一个冲刺的结转项

| 任务 | 原因 | 新预估 |
|------|------|-------------|
| Feature 层文件超 300 行重构 | Sprint 4/5/6 QA 遗留 | 流程项，非 story，Sprint 7 期间按需重构 |
| CardSystem 掉落规则接线 | Sprint 5 桩实现遗留 | 后续 Sprint 接线 |
| RealmSystem 天劫 Boss 配置接线 | Sprint 5 桩实现遗留 | 后续 Sprint 接线 |
| StatusEffectSystem 心魔 debuff 接线 | Sprint 5 桩实现遗留 | 后续 Sprint 接线 |
| InputManager 锁管理接线 | Sprint 5 桩实现遗留 | 后续 Sprint 接线 |

## 风险登记

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|------|
| ProgressionSystem 取代 GSM progression.* 域 | 中 | 高 | ADR-0012 明确迁移计划；GSM progression 域标记 superseded_by: ADR-0012 |
| SaveLoadSystem 接口调整 | 中 | 中 | load_progression / save_progression 对接 ProgressionSystem.serialize/deserialize |
| Autoload #12 初始化顺序 | 低 | 中 | 直接调用模式（非信号等待）——利用 Godot 顺序 _ready() 保证 |
| 天赋树 20 节点 const Dictionary | 低 | 低 | 编译时常量，运行时只读 |
| 62 成就 const Dictionary | 低 | 低 | 编译时常量，运行时只读 |
| 对话树 80-110 JSON 按需加载 | 低 | 低 | ADR-0027 验证单次 3-15 节点 < 5ms |

## 外部因素依赖

无（Meta 层 + Feature 层依赖 Foundation + Core + Sprint 4/5/6 已就绪系统，均已实现）

## 此冲刺的完成定义

- [x] 所有必须完成的任务已完成（14 项）
- [x] 所有任务通过验收标准
- [x] QA 计划已存在
- [x] 所有逻辑/集成类故事有通过的单元/集成测试
- [x] 冒烟检查已通过 (`/smoke-check sprint`)
- [x] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [x] 已交付特性中无 S1 或 S2 的 bug
- [x] 任何偏差已更新设计文档
- [x] 代码已审查并合并
- [x] 1 个新 Autoload 已注册且顺序验证通过（ProgressionSystem #12）

## 关键依赖链

- **progression-system**：001（域存储）→ 002（achievements）+ 003（talents）+ 004（endings/gallery/stats/meta）→ 005（信号+集成）
- **reincarnation-talent-system**：001（天赋树）→ 002（unlock_talent）→ 003（settle_run）——依赖 progression-system #003（talents API）
- **achievement-system**：001（Achievement 实例）→ 002（判定引擎）→ 003（查询+图鉴）——依赖 progression-system #002（achievements API）
- **dialogue-system**：001（数据结构）→ 002（播放编排）+ 003（BarkManager）——无跨 Epic 依赖
- **跨 Epic 依赖**：reincarnation #003 → progression #003（talents API）；achievement #001 → progression #002（achievements API）

## Autoload 注册

Sprint 7 新增 1 个 Meta 层 Autoload：

| Autoload | 编号 | 脚本路径 | 依赖 |
|----------|:----:|----------|------|
| ProgressionSystem | #12 | `res://src/meta/progression_system.gd` | SaveLoadSystem, GSM |

ReincarnationTalentSystem 和 AchievementSystem 为 RefCounted 服务类，不注册 Autoload。DialogueSystem 为 RefCounted 服务类（ADR-0027），不注册 Autoload。

> **注**：ADR-0012 将 ProgressionSystem 定为 #12，但 project.godot 当前有 24 个 Autoload（Sprint 6 已注册到 #25 StorySystem）。ProgressionSystem 应插入到 SaveLoadSystem #4 之后。注册时需注意 Autoload 顺序——ProgressionSystem 必须在 SaveLoadSystem 之后 _ready()。

## Next Steps

1. `/qa-plan sprint`——为 14 story 定义测试用例需求
2. `/dev-story` 从 7-1（progression-system 域存储）起逐条填充 AC 并实现
3. 或并行启动 dialogue-system（无跨 Epic 依赖）

## 范围检查

> **Scope Check**: 若此冲刺包含了超出原始 Epic 范围的故事，在实现开始前运行 `/scope-check [epic]` 以检测范围蔓延。
