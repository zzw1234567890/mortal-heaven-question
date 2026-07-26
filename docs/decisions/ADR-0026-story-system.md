# ADR-0026：剧情系统 — 独立 Feature Autoload + GSM-主存储 + EventSystem 委托写入

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Narrative |
| **知识风险** | LOW（Dictionary、Autoload、信号系统均为 Godot 4.x 成熟 API） |
| **需要验证** | Autoload #25 初始化顺序——StorySystem 必须在 EventSystem(#5)、RealmSystem(#11)、ExplorationSystem(#14) 之后就绪；章节数据 `const Dictionary` 编译时内存占用（预计 <5KB）；`chapter_completed` 与 ExplorationSystem 的 `map_cleared` 时序关系 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`narrative.*` 域状态读写；需新增 5 个第二层原子写入方法）；ADR-0003（EventSystem——story_flags 委托写入 `EventSystem.set_flag()`；`event_resolved` 信号监听以追踪必经事件完成；`ADVANCE_CHAPTER` Outcome 路径修正）；ADR-0010（RealmSystem——`get_realm_property()` 用于 chapter entry_conditions 境界验证）；ADR-0014（ExplorationSystem——章节地图解锁委托、剧情事件节点分配）；ADR-0007（三分类信号体系——`chapter_completed` 为 Cat 2b 信号） |
| **启用** | ADR-0027+（对话系统——章节进度决定可用对话树）；ADR-0028+（结局分支系统——跨章节聚合 story_flags 判定最终结局） |
| **阻塞** | 叙事 Epic（章节推进流程 + BOSS 解锁判定 + 结局分支选择界面）；对话系统 Epic（条件分支依赖 `get_current_chapter()` 和 story_flags 状态） |
| **排序说明** | Feature 层后期 ADR——Autoload 链最末（#25）。在 Foundation 层和 Core 层关键系统之后被接受，在对话/结局分支系统 ADR 之前被接受。完整 25 链：GSM #1 / InputManager #2 / SceneManager #3 / SaveLoad #4 / EventSystem #5 / CardSystem #6 / CostSystem #7 / StatusEffectSystem #8 / CombatSystem #9 / CardEffectEngine #10 / RealmSystem #11 / ProgressionSystem #12 / BindingManager #13 / ExplorationSystem #14 / FactionSystem #15 / ResourceSystem #16 / DeploymentSystem #17 / AISystem #18 / SchoolSystem #19 / CultivationSystem #20 / IdentitySelectionSystem #21 / DeckEditingSystem #22 / FormationSystem #23 / TribulationSystem #24 / StorySystem #25 |

## 上下文

### 问题陈述

`story-system.md` GDD 定义了完整的章节式剧情推进模型——5 个主线章节、每章 4-8 个必经事件、章末 BOSS 解锁判定、2-3 个结局分支选择、跨章节 story_flags 累积。GDD 定义了 ChapterState 结构，但以下架构决策尚未解决：

1. **运行时状态归属**：`narrative.*` 域（current_chapter、chapter_progress、completed_chapters）的写入权未分配。story_flags 写入权已由 ADR-0003 分配给 EventSystem，但其他 narrative 字段的写入者尚未明确。
2. **Autoload 定位**：剧情系统是否作为独立 Autoload？它在已有 25 个 Autoload 链中的位置是什么？
3. **章节数据存储格式**：5 章 × ~30 字段以什么格式存储？const Dictionary vs Resource .tres？
4. **与 EventSystem 的交互模式**：事件驱动剧情推进 vs 剧情解锁事件可用性——谁是主导？
5. **ADVANCE_CHAPTER 路径修正**：ADR-0003 直接调用了不存在的 `GSM.narrative.advance_chapter()`——需要修正为委托路径。

### 约束

- story_flags 写入权不变：StorySystem 通过 `EventSystem.set_flag()` 委托（ADR-0003）
- GSM narrative.* 域已声明：本 ADR 在此契约上分配写入权，不推翻
- 存档兼容性：`completed_required_events` 为 `Array[String]`，`completed_chapters` 为 `Array[StringName]`——均为 JSON 兼容
- Autoload 顺序：StorySystem 依赖 EventSystem(#5)、RealmSystem(#11)、ExplorationSystem(#14)——排在它们之后

## 决策

### 决策 1：StorySystem 作为独立 Feature Autoload #25 + GSM-主存储模型

**StorySystem 注册为 Autoload #25（Autoload 链最末）。运行时叙事状态通过 GSM `narrative.*` 域存储以支持存档/读档——StorySystem 是 `current_chapter`、`chapter_progress`、`completed_chapters` 的独占运行时写入者（story_flags 除外——委托 EventSystem）。章节模板数据（5 章静态定义）作为 `const Dictionary` 编译时常量——参考 RealmSystem（ADR-0010）模式。**

**状态分层：**
- **GSM narrative.* 域（持久化）**：`current_chapter`、`current_chapter_progress{completed_required_events, boss_unlocked, boss_defeated, ending_chosen}`、`completed_chapters`、`story_flags`（EventSystem 独占写入）
- **StorySystem 内部（编译时常量，不持久化）**：`CHAPTER_TEMPLATES`（5 章 × ~30 字段）、`_ending_branch_data`、`_chapter_intro_texts`

状态模型论证：与 ExplorationSystem（ADR-0014）相同的 GSM-primary 模型。剧情进度是游戏进度——玩家期望中途存读档后恢复到同一章节状态。GSM.serialize() 自动包含 narrative.* 域，无需自定义序列化。

### 决策 2：章节数据以 `const Dictionary` 编译时常量存储

5 章 × ~30 字段以 `const Dictionary` 存储——类似 RealmSystem 的 `const realm_table`。不使用 Resource（.tres）。

```gdscript
const CHAPTER_TEMPLATES: Dictionary = {
    &"ch1_qixuan": {
        chapter_number = 1,
        title = "第一话：青云入世", subtitle = "仙途问道之始",
        entry_conditions = {min_realm = 1, prev_chapter_completed = false, required_flags = []},
        required_events = [&"ch1_event_1_trial", &"ch1_event_2_su_jianming",
                           &"ch1_event_3_blood_trial", &"ch1_event_4_mo_duoshe",
                           &"ch1_event_5_join_danxia"],
        chapter_boss = {boss_id = &"mo_yuan_possessed"},
        ending_branches = [
            {branch_id = &"ch1_accept_mo",  label = "接受墨渊的提议", flag_to_set = {&"ch1_accepted_mo_condition": true}},
            {branch_id = &"ch1_reject_mo",  label = "拒绝墨渊", flag_to_set = {&"ch1_accepted_mo_condition": false}},
        ],
        maps = [&"qing_yun_jian_zong", &"xue_yuan_mi_jing", &"yueguo_capital", &"dan_xia_gu"],
        completion = {unlock_next_chapter = &"ch2_luanxinghai", unlock_maps = [&"cang_xuan_zhengdao_meng"]},
    },
    # ... ch2~ch5（共 5 章）
}
```

格式选择理由：数据量（5 章）远小于事件模板（60-100 个）。Resource 适用于策划频繁 Inspector 编辑的大量条目——5 章结构化数据场景下，const Dictionary 优势明显：零运行时加载、git diff 友好、编译时验证。

### 决策 3：双向触发模型——事件驱动剧情推进，剧情解锁事件可用性

剧情推进核心驱动是事件完成：必经事件完成 → StorySystem 追踪进度 → BOSS 解锁。同时剧情状态反向影响事件可用性——地图事件池由当前章节过滤。这是双向协作而非单向依赖：

① 玩家进入地图 → ExplorationSystem 调用 `StorySystem.get_chapter_context(map_id)` 获取当前章节的必经事件列表 → 标记必经事件节点
② 事件完成 → EventSystem 发射 `event_resolved` → StorySystem 监听并更新 `completed_required_events` → 检查 BOSS 解锁
③ BOSS 击败 → StorySystem 设置 `boss_defeated = true` → 展示结局分支
④ 结局选择 → `complete_chapter()`：写入 story_flags（委托 EventSystem）、更新 completed_chapters、解锁下一章

### 决策 4：StorySystem 自身执行章节进入条件评估

Entry conditions 评估由 StorySystem 自身执行——直接通过 GSM 第一层读取 `player.realm_level` 和 `narrative.*` 域。这是自包含纯函数，不委托给其他系统。遵循 ADR-0010（`get_current_property()` 便捷查询）和 ADR-0014（`select_map()` 自包含验证）的模式。

### 决策 5：地图解锁通过信号委托给 ExplorationSystem

章节完成后发射 `chapter_completed` 信号（Cat 2b），ExplorationSystem 监听并执行地图解锁。遵循 ADR-0003 和 ADR-0014 的信号委托先例。StorySystem 不直接调用 ExplorationSystem 方法。

### ADVANCE_CHAPTER 路径修正（ADR-0003 同步）

ADR-0003 中 `OutcomeType.ADVANCE_CHAPTER` 直接调用 `GSM.narrative.advance_chapter()`——此方法不存在。修正：StorySystem 监听 `event_resolved` 检测 ADVANCE_CHAPTER → 调用 StorySystem 验证并推进。由于 EventSystem（Foundation）不能依赖 StorySystem（Feature），通过**监听器反转**实现——StorySystem 在 `_ready()` 中连接 EventSystem 的信号。保持 Foundation 层原则 #3 合规。

### 关键接口总结

```gdscript
# 验证 + 查询
func can_enter_chapter(chapter_id: StringName) -> Dictionary       # → {allowed, reason}
func get_chapter_context(map_id: StringName) -> Dictionary         # 供 ExplorationSystem
func get_chapter_data(chapter_id: StringName) -> Dictionary        # 供对话/结局系统
func is_boss_unlocked() -> bool

# 状态变更
func on_boss_defeated() -> void
func complete_chapter(branch_id: StringName) -> void               # 结局选择后调用

# 信号
signal chapter_completed(chapter_id, branch_id)    # Cat 2b — ExplorationSystem 监听
signal boss_unlocked(chapter_id, boss_id)          # Cat 2b — 探索UI 监听
signal chapter_started(chapter_id)                 # Cat 2b — UI 标题卡
signal game_victory()                              # Cat 2b — 第5章完成时替代 chapter_completed
```

### GSM 第二层新增方法（需同步 ADR-0001）

```
GSM.set_current_chapter(chapter_id)          # 启动新章节
GSM.add_required_event_completion(event_id)  # 追加必经事件
GSM.set_narrative_boss_unlocked(value)
GSM.set_narrative_boss_defeated(value)
GSM.add_completed_chapter(chapter_id)
```

## 考虑的替代方案

### 替代方案 A：非 Autoload 组件模式
将 StorySystem 作为探索场景根节点的 Node 组件——场景加载时实例化，离开时销毁。**拒绝**：剧情状态是全局游戏进度，不是场景级状态。对话系统（任何场景都可能触发）、结局系统（通关后）、存档系统（随时读写 narrative.*）都需要访问章节状态。组件模式导致逻辑随场景销毁而丢失。

### 替代方案 B：GSM 内嵌模式
CHAPTER_TEMPLATES 和推进逻辑全部作为 GSM 方法和常量。**拒绝**：GSM 进一步膨胀——在已有 10+ 个域基础上增加章节模板数据和 ~200 行推进逻辑。违反 ADR-0001 设计意图。ADR-0014 已论证探索逻辑不应嵌入 GSM——剧情逻辑同理。

### 替代方案 C：Resource (.tres) 章节数据
5 个章节各自作为 ChapterDefinition Resource。**拒绝**：数据规模不适配——5 章 vs 60-100 个事件模板。嵌套 Array[Dictionary] 在 Resource Inspector 中编辑体验差。规模与 RealmSystem 的 5 层境界数据相当——遵循已确立的 const Dictionary 模式。

## 后果

### 积极的
- **清晰的职责边界**：StorySystem 负责章节模板、条件验证、BOSS 解锁判定、推进编排——GSM 负责持久化——EventSystem 负责 story_flags 写入
- **存档/读档简化**：GSM-primary 模型自动纳入 GSM.serialize() 管道——无需自定义序列化
- **ADVANCE_CHAPTER 路径修正**：将 ADR-0003 中调用不存在方法的路径替换为监听器反转——保持 Foundation 层原则 #3 合规
- **信号委托一致**：遵循 ADR-0003 和 ADR-0014 的先例——跨系统协调通过 Cat 2b 信号，无直接跨层依赖
- **Autoload 定位清晰**：#25——在 EventSystem、RealmSystem、ExplorationSystem 之后，在对话/结局系统 ADR 之前

### 消极的
- **第 25 个 Autoload（链最末）**：Autoload 链中的最后一个——仅依赖 3-4 个上游，初始化链简洁
- **章节数据维护成本**：策划修改需编辑 GDScript 源码。约定：章节扩展至 10+ 时考虑迁移 Resource 模式

### 风险
- **必经事件 event_id 不同步**：CHAPTER_TEMPLATES 引用的 event_id 在 EventSystem 中不存在。缓解：`_ready()` 中交叉验证所有引用
- **ADVANCE_CHAPTER 监听时序**：StorySystem 连接 EventSystem 信号前不应有事件触发。缓解：Autoload 顺序确保 StorySystem `_ready()` 在 EventSystem 之后、任何场景加载之前
- **chapter_completed 信号消费者离线**：如果玩家在章节完成瞬间切换到主菜单，ExplorationSystem 可能不在线。缓解：GSM 持久化地图解锁事实——ExplorationSystem 下次进入时从 GSM 同步

## 解决的 GDD 需求

| GDD 需求 | 本 ADR 如何解决 |
|-------------|--------------------------|
| §1 章节结构（5 章模板） | CHAPTER_TEMPLATES const Dictionary——5 章集中定义 |
| §3 章节状态机 + 推进判定 | `complete_chapter()` + GSM narrative.* 状态 + BOSS 解锁判定 |
| §5 必经事件追踪 | chapter_progress.completed_required_events + `event_resolved` 监听 |
| §6 地图剧情绑定 | `get_chapter_context(map_id)`——供 ExplorationSystem 过滤事件池 |
| §8 章节入口展示 | `chapter_started` 信号——携带标题/副标题/引子供 UI 展示 |
| §公式——entry conditions | `can_enter_chapter()` 纯函数——境界 + 前置章节 + flag 条件 |

## 性能影响
- **CPU**：`can_enter_chapter()` < 0.01ms，`complete_chapter()` < 0.1ms——均非每帧操作
- **内存**：CHAPTER_TEMPLATES < 5KB，Autoload 节点 < 1KB——常驻 < 6KB
- **加载时间**：const Dictionary 编译时分配——零运行时加载

## 需同步更新的 ADR
- **ADR-0001**：第二层新增 5 个 narrative.* 原子写入方法
- **ADR-0003**：修正 `ADVANCE_CHAPTER` 执行路径——监听器反转替代直接调用

## 验证标准
- `GIVEN` 新游戏 → `current_chapter = "ch1_qixuan"`, `completed_chapters = []`
- `GIVEN` 第 1 章完成 + 结局"拒绝墨渊" → story_flags["ch1_accepted_mo_condition"] = false, current_chapter = "ch2_luanxinghai"
- `GIVEN` 第 1 章完成 + 结局"接受墨渊" → story_flags["ch1_accepted_mo_condition"] = true
- `GIVEN` 必经事件未全部完成 → `is_boss_unlocked() = false`
- `GIVEN` 所有必经事件完成 → `is_boss_unlocked() = true`
- `GIVEN` 第 2 章需第 1 章完成 → 未完成时 `can_enter_chapter("ch2")` → `{allowed: false}`
- `GIVEN` chapter_completed 发射 → ExplorationSystem 解锁下一章地图
- `GIVEN` 第 5 章完成 → `game_victory` 信号（代替 chapter_completed）

## 相关决策
- ADR-0001：GSM 三层 API——narrative.* 域状态所有权
- ADR-0003：EventSystem——story_flags 写入委托、event_resolved 监听、ADVANCE_CHAPTER 路径修正
- ADR-0010：RealmSystem——境界查询用于 entry_conditions 验证
- ADR-0014：ExplorationSystem——地图解锁信号委托、剧情事件节点分配
- ADR-0007：三分类信号体系——Cat 2b 信号分类
