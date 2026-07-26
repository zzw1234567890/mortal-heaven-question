# ADR-0029：结局分支系统 — 嵌入 StorySystem 纯函数引擎 + ProgressionSystem 图鉴持久化

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Narrative |
| **知识风险** | LOW（Dictionary、RefCounted、信号系统均为 Godot 4.x 成熟 API；评分计算为纯函数无状态副作用） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None（所有 API——Dictionary、signal connect、RefCounted——自 4.0 起稳定） |
| **需要验证** | 6 个结局 × ~8 条叙事段落 × ~200 字符/段 = ~10KB 存储（const Dictionary 编译时常量——可忽略）；`evaluate_ending()` 纯函数单次调用 <0.1ms（无外部 I/O，纯字典运算）；结局展示 UI 序列与轮回结算时序的正确衔接 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0026（StorySystem——第 5 章完成时发射 `game_victory` 信号；StorySystem 是本系统的宿主——结局评估引擎嵌入其脚本文件）；ADR-0003（EventSystem——story_flags 的只读查询 `EventSystem.get_flag()`——30+ 个标记的评分权重计算）；ADR-0012（ProgressionSystem——结局图鉴持久化 `ProgressionSystem.unlock_ending()` 和累计通关计数 `total_completions`）；ADR-0001（GSM——`player.realm_level`、`player.identity_id` 的只读读取）；ADR-0025（IdentitySelectionSystem——身份标签用于评分权重——如「青云剑宗外门弟子」→ +10 归隐东域线；仅需 `identity_id` 值即可判定，无需直接依赖）；ADR-0008（CombatSystem——`game_victory` 在第 5 章 BOSS 击败后发射，触发结局判定流程） |
| **关联的 ADR** | ADR-0007（三分类信号体系——`ending_evaluated` 为 Cat 2b 信号，供 UI 和音频系统监听）；ADR-0005（SceneManager——通关展示序列中的场景切换 `show_ending_cg` → `show_ending_epilogue` → `show_ending_stats` → `change_scene("reincarnation")` → `change_scene("main_menu")`） |
| **阻塞** | 结局展示 UI Epic（结局 CG、尾声叙事、统计面板、结局图鉴界面）；通关流程 Epic（游戏胜利 → 结局判定 → 结局展示 → 通关奖励 → 轮回结算 → 主菜单） |
| **排序说明** | Feature 层末期 ADR——在 StorySystem（ADR-0026）和 ProgressionSystem（ADR-0012）之后被接受。结局系统是叙事层的终端——StorySystem 的 `game_victory` 信号触发结局判定，结果通过 ProgressionSystem 持久化。非 Autoload——嵌入 StorySystem 以节约 Autoload 槽位（当前已用 25 个，超出 Godot 建议的 20 软上限） |

## 上下文

### 问题陈述

`ending-branch-system.md` GDD 定义了完整的结局分支模型——跨章节聚合 30+ story_flags、3 条结局主线（飞升仙界 / 留在归墟之境 / 归隐东域）、每线 2 种变体（共 6 个结局 ID）、加权评分 + 平局解决 + 变体判定 + 通关展示流程（CG → 尾声叙事 → 统计面板 → 结局图鉴更新）。GDD 定义了评分公式和展示流程，但以下架构决策尚未解决：

1. **是否需要独立 Autoload**：结局判定仅在通关时调用一次——不需要常驻内存的服务。当前已有 25 个 Autoload（GSM → … → StorySystem），超出 Godot 建议的 20 软上限——不应再增加。
2. **判定引擎的归属**：纯函数 `evaluate_ending(story_flags, chapter_path, run_data) → EndingResult`——无状态副作用（只读 story_flags，不写入）。应独立于任何 Autoload 生命周期。
3. **得分模板数据存储**：3 条线 × ~7 个条件 × 权重值 + 变体条件规则 + 尾声文本模板——数据量约 10KB。const Dictionary（与 CHAPTER_TEMPLATES 一致）还是 Resource（.tres）。
4. **结局图鉴持久化路径**：GDD 原要求独立 `endings.dat`——但 ADR-0012 已将 ProgressionSystem 作为跨局数据的唯一权威源，且已定义 `unlock_ending()` 和 `get_unlocked_endings()` API。是否需要独立文件？
5. **通关展示流程的编排**：CG → 尾声 → 统计 → 图鉴更新 → 轮回结算 → 主菜单——长达 30+ 秒的序列。谁来驱动这个序列的 UI 节奏和场景切换？

### 约束

- **Autoload 槽位**：当前 25 个 Autoload 已超出 Godot 20 软上限。结局系统不增加 Autoload。
- **story_flags 只读**：结局系统只读取 story_flags——不写入。唯一写入权归 EventSystem（ADR-0003）。
- **GSM 三层 API 合规**：结局数据读取通过 GSM 第一层（`GSM.player.realm`、`GSM.player.identity_id`）和 EventSystem（`get_flag()`）；结局图鉴写入通过 ProgressionSystem（ADR-0012——直写缓存模型）。
- **第 5 章完成时机**：结局判定在 StorySystem 的 `game_victory` 信号发射后触发——此时第 5 章 BOSS 已击败、第 5 章结局选择（飞升/守护/回归）已写入 story_flags。
- **通关展示完整性**：展示序列必须在玩家退出游戏前完成结局图鉴写入——如果玩家在尾声播放中 Alt+F4，下次启动检测到已完成 5 章 → 从结局展示第 1 幕重新开始。

### 需求

- 6 个结局 ID 的判定引擎（3 条线 × 2 变体）
- 评分公式：加权求和 + 第 5 章偏斜 + 优先级平局解决
- 变体条件判定（银翎存活/第 4 章选择/轮回天赋数/累计通关）
- 结局图鉴持久化（通过 ProgressionSystem API）
- 通关展示流程编排（CG → 尾声 → 统计 → 轮回结算）
- 尾声叙事文本生成（story_flags 驱动的引用插入）

## 决策

### 决策 1：不创建独立 Autoload——嵌入 StorySystem + EndingEvaluator 纯函数 RefCounted 工具类

**结局分支系统不作为独立 Autoload 注册。结局判定引擎（`EndingEvaluator`）为 RefCounted 工具类——StorySystem 的 `_on_game_victory()` 监听器中按需构造一个 `EndingEvaluator` 实例，传入 `story_flags + chapter_path + run_data`，调用纯函数 `evaluate()` 获得 `EndingResult`，然后发射 `ending_evaluated` 信号。实例在信号发射后立即释放。**

核心逻辑：

```gdscript
## StorySystem._ready() 中的连接
func _ready():
    # ... 现有初始化 ...
    game_victory.connect(_on_game_victory)

## StorySystem 内部——结局判定入口
func _on_game_victory() -> void:
    # 1. 构建输入数据
    var evaluator := EndingEvaluator.new()
    var result = evaluator.evaluate(
        EventSystem,        # 用于 get_flag() 只读查询
        chapter_path,       # StorySystem 持有的 5 章选择路径
        _collect_run_data() # 本局运行数据快照
    )
    # 2. 持久化结局图鉴（通过 ProgressionSystem 委托）
    ProgressionSystem.unlock_ending(
        result.ending_id,
        chapter_path,
        GSM.player.identity_id,
        RealmSystem.get_realm_name(GSM.player.realm)
    )
    # 3. 发射信号——UI 系统监听并驱动展示序列
    ending_evaluated.emit(result)
```

```gdscript
## EndingEvaluator（RefCounted——不持有状态，纯函数）
class_name EndingEvaluator extends RefCounted

func evaluate(event_system: Node, chapter_path: Dictionary, run_data: Dictionary) -> EndingResult:
    var scores := _calculate_scores(event_system, chapter_path, run_data)
    var ending_line := _resolve_tie(scores, chapter_path.get("ch5", ""))
    var variant := _determine_variant(ending_line, event_system, chapter_path, run_data)
    var ending_id := ending_line + "_" + variant  # 如 "ascend_solo"
    var epilogue := _generate_epilogue(ending_id, event_system, chapter_path)
    return EndingResult.new(ending_id, ending_line, variant, scores, epilogue)
```

**信号声明（新增于 StorySystem）：**

```gdscript
signal ending_evaluated(result: EndingResult)  # Cat 2b——UI/音频系统监听
```

**Autoload 计数影响**：不增加。`EndingEvaluator` 为 RefCounted 类——仅在通关时实例化一次（~0.1ms 构造开销），结算后销毁。不常驻内存。

设计论证：结局判定是 StorySystem `game_victory` 信号的自然延续——第 5 章完成 → 判定结局 → 展示结局。这不是独立的系统生命周期，而是 StorySystem "通关后行为" 的一部分。Autoload 槽位是有限资源——在不增加常驻开销的前提下，嵌入宿主系统是最优解。

### 决策 2：得分模板以 `const Dictionary` 编译时常量存储

**3 条结局线的评分权重、变体条件和尾声文本模板以 `const Dictionary` 存储——与 StorySystem 的 `CHAPTER_TEMPLATES`（ADR-0026）和 RealmSystem 的 `const realm_table`（ADR-0010）一致的已确立模式。**

```gdscript
## EndingEvaluator 内的编译时常量（约 10KB）
const ENDING_TEMPLATES: Dictionary = {
    &"ascend": {
        name = "飞升仙界", theme = "天道终点", emotion = "宏大、释然、新的开始",
        conditions = [
            {flag = &"", chapter_choice = ["ch5", "ascend"], weight = 30, desc = "第5章选择「飞升仙界」"},
            {flag = &"", chapter_choice = ["ch4", "ascend_alone"], weight = 15, desc = "第4章飞升准备"},
            {flag = &"", chapter_choice = ["ch4", "ascend_with_yinyue"], weight = 15, desc = "第4章携伴飞升"},
            {flag = &"", chapter_choice = ["ch3", "defend_righteous"], weight = 10, desc = "坚守正道"},
            {flag = &"", chapter_choice = ["ch2", "destroy_cave"], weight = 8, desc = "拒绝诱惑"},
            {flag = &"", chapter_choice = ["ch1", "reject_mo"], weight = 7, desc = "拒绝墨渊"},
            {run_key = "elites_killed", operator = "ge", value = 20, weight = 5, desc = "战力证明"},
            {run_key = "unique_cards", operator = "ge", value = 100, weight = 5, desc = "博学广识"},
        ],
        variants = {
            &"solo": {condition = "ch4 != ascend_with_yinyue",
                       name = "仙道孤独", cg = "ascension_solo"},
            &"duo":  {condition = "ch4 == ascend_with_yinyue",
                       name = "仙侣同行", cg = "ascension_duo"},
        },
        epilogue_base = "天梯尽头，仙界之门缓缓开启……",
        cg_resource = "res://assets/ui/endings/ascension.png",
        bgm_theme = "ascension_theme",
    },
    &"guard": {
        name = "留在归墟之境", theme = "守护之道", emotion = "沉稳、担当、余生",
        conditions = [
            {chapter_choice = ["ch5", "guard"], weight = 30},
            {chapter_choice = ["ch3", "neutral_mediate"], weight = 15},
            {chapter_choice = ["ch2", "take_secret"], weight = 10},
            {chapter_choice = ["ch1", "accept_mo"], weight = 8},
            {run_key = "craft_count", operator = "ge", value = 20, weight = 8},
            {flag = &"yinyue_alive", weight = 5},
            {run_key = "identity", operator = "in", value = ["star_storm_wanderer", "yellow_maple_disciple"], weight = 5},
        ],
        variants = {
            &"lone":  {condition = "NOT (yinyue_alive AND ch4 == ascend_with_yinyue)",
                       name = "孤身守望"},
            &"order": {condition = "yinyue_alive AND ch4 == ascend_with_yinyue",
                       name = "建立新秩序"},
        },
        epilogue_base = "你立于归墟之境最高处，俯瞰这片你守护了半生的山河……",
        cg_resource = "res://assets/ui/endings/guardian.png",
        bgm_theme = "guardian_theme",
    },
    &"return": {
        name = "归隐东域", theme = "凡人之心", emotion = "宁静、圆满、归家",
        conditions = [
            {chapter_choice = ["ch5", "return"], weight = 30},
            {chapter_choice = ["ch1", "reject_mo"], weight = 12},
            {flag = &"ch2_rebuilt_foundation", weight = 10},
            {chapter_choice = ["ch3", "*"], weight = 5},
            {run_key = "elites_killed", operator = "le", value = 10, weight = 8},
            {run_key = "identity", operator = "eq", value = "seven_peaks_disciple", weight = 10},
            {run_key = "total_reincarnations", operator = "ge", value = 5, weight = 5},
        ],
        variants = {
            &"home": {condition = "NOT (yinyue_alive AND unlocked_talents >= 10 AND total_completions >= 3)",
                      name = "归隐凡间"},
            &"sect": {condition = "yinyue_alive AND unlocked_talents >= 10 AND total_completions >= 3",
                      name = "开宗立派"},
        },
        epilogue_base = "你推开青云剑宗旧居的木门，夕阳从门缝洒入，屋内一切如旧……",
        cg_resource = "res://assets/ui/endings/return_home.png",
        bgm_theme = "return_theme",
    },
}
```

**数据规模论证**：6 个结局的模板数据约 10KB——与 StorySystem 的 5 章 `CHAPTER_TEMPLATES`（<5KB）规模相当。const Dictionary 优势：零运行时加载、编译时验证、git diff 友好。不使用 Resource（.tres）：6 个条目远少于 EventSystem 的 60-100 个事件模板——不需要 Inspector 可视化编辑。策划修改权重值可直接编辑 GDScript 源码中的 Int 值，无需学习 Resource Inspector 操作。

### 决策 3：结局图鉴通过 ProgressionSystem API 持久化——不创建独立 endings.dat

**GDD 原要求独立 `endings.dat`——此需求被 ADR-0012 覆盖。结局图鉴数据使用 ProgressionSystem API：`unlock_ending()` 写入、`get_unlocked_endings()` / `get_ending_detail()` 读取。不创建独立的 `endings.dat` 文件。**

调用链路：

```
StorySystem._on_game_victory()
  └→ ProgressionSystem.unlock_ending(ending_id, chapter_path, identity_id, realm_name)
       ├→ 写入 _endings[ending_id] = {unlocked, unlocked_at, chapter_path, identity, realm}
       ├→ 递增 _meta.total_completions（内置——调用方无需额外操作）
       ├→ 发射 ending_unlocked(ending_id, total)
       └→ 发射 progression_updated → SaveLoadSystem 被动写盘
```

**为何不独立存储**：ADR-0012 在确立 ProgressionSystem 时已考量了结局图鉴的需求——在其 API 设计中预留了 `endings` 域（`unlock_ending`、`get_unlocked_endings`、`has_ending`、`get_ending_detail`）。ProgressionSystem 的原子写盘策略（.tmp → rename + .bak 备份）已提供写入安全性——独立文件并非必要。`progression.dat` 统一管理所有跨局数据（成就、天赋、卡牌图鉴、结局、统计）——增加独立文件反而增加损坏恢复的复杂度（两个文件可能不同步）。

**GDD「endings.dat 独立」需求的回应**：GDD §6 末尾提到"结局图鉴数据不随 progression.dat 重置"。这里的设计理解是：progression.dat 是**跨局**数据，`new_game()` 从不重置它——与 GDD 的设计意图一致。ProgressionSystem 的 `_endings` 域在 `initialize()` 中从 `progression.dat` 填充，跨局持续存在。无需独立文件即可满足需求。

### 决策 4：通关展示流程由 EndingDisplayController（场景内 Node）驱动

**通关展示序列（CG → 尾声 → 统计 → 图鉴更新 → 轮回结算 → 主菜单）由一个场景级别的 `EndingDisplayController` 节点驱动——注册到通关展示场景中。不增加 Autoload。**

```
通关展示场景（ending_display.tscn）:
  EndingDisplayController (Node)
    ├─ EndingCGDisplay (Control)      # CG 展示层
    ├─ EndingEpilogueDisplay (Control) # 尾声叙事层
    ├─ EndingStatsDisplay (Control)   # 统计面板层
    └─ EndingGalleryNotifier (Node)   # 图鉴解锁动画层
```

流程时序：

```
① StorySystem 发射 ending_evaluated(result)
   └→ SceneManager 监听 signal → change_scene("ending_display", {result})

② EndingDisplayController._ready()
   ├─ 第1幕：CG 淡入 (2.5s) + 结局标题浮现 (0.8s) → 可点击跳过
   ├─ 第2幕：尾声叙事逐句淡入 (8-16s) → 可点击跳过
   ├─ 第3幕：统计面板数据飞入 (1.5s)
   ├─ 结局图鉴翻转动画 (0.6s) → 已完成（ProgressionSystem 已在判定时写入）
   └─ 底部「[继续·进入轮回结算]」按钮

③ 玩家点击 → SceneManager.change_scene("reincarnation_settlement")
④ 轮回结算完成 → SceneManager.change_scene("main_menu")
```

场景管理器不需要预知结局展示——`ending_evaluated` 信号携带完整 `EndingResult`（ID、主线、变体、得分、尾声文本、CG 路径、BGM 主题），场景通过 `SceneManager.request_scene_change()` 的 context 参数传递。

### 关键接口总结

```gdscript
## EndingEvaluator（RefCounted 工具类——无状态，纯函数）
class_name EndingEvaluator extends RefCounted
func evaluate(event_system: Node, chapter_path: Dictionary, run_data: Dictionary) -> EndingResult
  # 纯函数——不修改任何外部状态
  # 返回 EndingResult（ending_id, line, variant, scores, epilogue, cg, bgm）

## EndingResult（RefCounted 数据传输对象）
class_name EndingResult extends RefCounted
var ending_id: StringName     # "ascension_solo", "ascension_duo", ...
var ending_line: StringName   # "ascend", "guard", "return"
var variant: StringName       # "solo", "duo", "lone", "order", "home", "sect"
var line_name: String         # "飞升仙界", "留在归墟之境", "归隐东域"
var variant_name: String      # "仙道孤独", "仙侣同行", ...
var scores: Dictionary        # {ascend: 55, guard: 45, return: 30}
var epilogue: String          # 生成后的完整尾声叙事文本
var cg_path: String           # CG 资源路径
var bgm_theme: String         # BGM 主题标识符

## StorySystem 新增信号
signal ending_evaluated(result: EndingResult)  # Cat 2b
  # SceneManager、EndingDisplayController、AudioSystem 监听

## StorySystem 新增方法
func _on_game_victory() -> void
  # 内部方法——构造 EndingEvaluator → evaluate → unlock_ending → emit ending_evaluated

## ProgressionSystem API（ADR-0012 已定义，此处引用）
ProgressionSystem.unlock_ending(ending_id, chapter_path, identity_id, realm) → {success, reason}
ProgressionSystem.get_unlocked_endings() → Array[String]
ProgressionSystem.has_ending(ending_id) → bool
ProgressionSystem.get_ending_detail(ending_id) → Dictionary
ProgressionSystem.get_meta("total_completions") → int
```

### 与 StorySystem 的宿主关系

StorySystem 是结局判定引擎的**宿主**——不拥有 EndingEvaluator 的内部逻辑（那是工具类的职责），但拥有：
- 结局判定的**触发时机**（`game_victory` 监听器）
- 结局图鉴持久化的**调用权**（调用 ProgressionSystem.unlock_ending）
- `ending_evaluated` 信号的**发射权**

EndingEvaluator 是**纯工具**——无状态、无信号、无外部依赖（通过参数注入 `event_system` 用于只读查询）。这保持了 StorySystem 的边界清晰：StorySystem 负责"何时判定结局"和"结果持久化"，EndingEvaluator 负责"如何判定结局"。

StorySystem 需修改的部分（仅增加，不修改现有逻辑）：
1. `_ready()` 中新增 `game_victory.connect(_on_game_victory)`
2. 新增 `_on_game_victory()` 方法（~20 行编排逻辑）
3. 新增 `_collect_run_data()` 辅助方法（~10 行——从 GSM 收集 `elites_killed`、`unique_cards` 等本局数据）
4. 新增 `ending_evaluated` 信号声明
5. 新增 `EndingEvaluator` 和 `EndingResult` 类文件（独立 .gd 脚本）

### 评分计算算法

```gdscript
func _calculate_scores(event_system, chapter_path, run_data) -> Dictionary:
    var scores := {ascend = 0, guard = 0, return = 0}
    for line in ["ascend", "guard", "return"]:
        for cond in ENDING_TEMPLATES[line].conditions:
            if cond.has("chapter_choice"):
                var ch = cond.chapter_choice[0]  # "ch1" .. "ch5"
                var expected = cond.chapter_choice[1]  # "ascend", "reject_mo", ...
                var actual = chapter_path.get(ch, "")
                if actual == expected or expected == "*":
                    scores[line] += cond.weight
            elif cond.has("flag"):
                if event_system.get_flag(cond.flag, false):
                    scores[line] += cond.weight
            elif cond.has("run_key"):
                if _check_run_condition(run_data, cond):
                    scores[line] += cond.weight
    return scores

func _resolve_tie(scores: Dictionary, ch5_choice: String) -> StringName:
    # 第5章偏斜
    match ch5_choice:
        "ascend": scores.ascend += 5
        "guard":  scores.guard += 5
        "return": scores.return += 5
    # 最高分 + 优先级打破平局
    var max_val := max(scores.ascend, scores.guard, scores.return)
    var priority := ["ascend", "guard", "return"]
    for line in priority:
        if scores[line] == max_val:
            return line
    return "ascend"  # fallback——不应到达

func _determine_variant(line: StringName, event_system, chapter_path, run_data) -> StringName:
    match line:
        "ascend":
            return "duo" if chapter_path.get("ch4", "") == "ascend_with_yinyue" else "solo"
        "guard":
            var yinyue := event_system.get_flag("yinyue_alive", false)
            var ch4_accompany := chapter_path.get("ch4", "") == "ascend_with_yinyue"
            return "order" if (yinyue and ch4_accompany) else "lone"
        "return":
            var yinyue := event_system.get_flag("yinyue_alive", false)
            var talents := ProgressionSystem.get_talent_tree_state().unlocked.size()
            var completions := ProgressionSystem.get_meta("total_completions")
            return "sect" if (yinyue and talents >= 10 and completions >= 3) else "home"
    return "solo"
```

### 尾声叙事文本生成

```gdscript
func _generate_epilogue(ending_id: StringName, event_system, chapter_path) -> String:
    var template := ENDING_TEMPLATES[ending_id.split("_")[0]]
    var base := template.epilogue_base
    var insertions: Array[String] = []

    # 按 story_flags 条件插入特定段落
    if event_system.get_flag("ch1_accepted_mo_condition", false):
        insertions.append("你记得那一日在云澜城，墨渊的夺舍条件你曾动过念头……")
    if event_system.get_flag("ch2_took_bone_secret", false):
        insertions.append("枯骨老祖的秘宝至今仍在你储物袋中——力量的代价，你已经懂了。")
    else:
        insertions.append("摧毁枯骨洞府的那一击，让你在正道中赢得了尊重。")
    if event_system.get_flag("li_feiyu_alive", false):
        insertions.append("苏剑鸣在远处对你挥了挥手，转身消失在人群中。活着就好——修仙路上，能活着的人不多。")

    # 插入段落融入基础文本——最多 12 句
    var result := base
    for insertion in insertions.slice(0, 12 - base.count("\n")):
        result += "\n\n" + insertion
    return result
```

## 考虑的替代方案

### 替代方案 A：独立 Autoload #26（EndingBranchSystem）

- **描述**：EndingBranchSystem 作为独立 Autoload 注册——管理结局模板、判定引擎和图鉴数据。类似于 StorySystem 的模式。
- **优点**：清晰的关注点分离——结局判定逻辑不在 StorySystem 中；可独立测试 EndingBranchSystem 而无需实例化全部叙事栈；符合「每个 GDD 一个 Autoload」的线性思维。
- **缺点**：Autoload #26——已超 Godot 20 软上限 6 个。结局判定仅在一次 30+ 小时的游玩中调用 1 次——Autoload 的常驻内存（~5KB）利用率极低。结局模板（6 个条目）不需要运行时热加载——const Dictionary 即可。结局图鉴已有 ProgressionSystem API。独立 Autoload 增加初始化顺序复杂度（需排在 StorySystem #25 之后）。
- **拒绝原因**：Autoload 是稀缺资源——不应为了逻辑隔离而消费它，当隔离可以通过 RefCounted 工具类（零常驻成本）实现时。结局判定不构成独立的系统生命周期——它是 StorySystem 通关行为的自然延伸。`EndingEvaluator` 工具类与独立 Autoload 有相同的测试性（无外部依赖，纯函数输入输出），但无 Autoload 开销。

### 替代方案 B：纯函数工具类（不嵌入任何 Autoload）

- **描述**：EndingEvaluator 作为完全独立的 `.gd` 脚本文件——不嵌入 StorySystem。调用方（SceneManager 或通关展示场景）直接实例化 EndingEvaluator 并调用 `evaluate()`。
- **优点**：与 StorySystem 零耦合——可以在没有 StorySystem 的测试场景中独立测试；StorySystem 不因结局判定逻辑而膨胀。
- **缺点**：结局判定的触发时机分散——SceneManager 监听 `game_victory` 信号获取 StorySystem 专有的 `chapter_path` 数据。`chapter_path`（5 章选择路径）是 StorySystem 的内部数据——SceneManager 不应知道其结构。调用链路复杂化：StorySystem → game_victory 信号 → SceneManager → EndingEvaluator.evaluate() → ProgressionSystem → SceneManager → 切换场景。StorySystem 的 `game_victory` 信号仍需携带 `chapter_path` 数据——实质上是将 StorySystem 的内部数据暴露给外部调用者。
- **拒绝原因**：`chapter_path` 的所有权在 StorySystem——它理应是结局判定的触发者和数据提供者。将 EndingEvaluator 嵌入 StorySystem（而非独立）保持了数据就近原则——StorySystem 直接持有判定的输入数据，无需通过信号载荷暴露内部状态。测试性未牺牲——EndingEvaluator 仍是纯函数 RefCounted 类，可在 GUT 测试中独立实例化，传入 mock `chapter_path` 和 `run_data`。

### 替代方案 C：嵌入 ProgressionSystem

- **描述**：结局判定引擎作为 ProgressionSystem 的方法——`ProgressionSystem.evaluate_ending()`。因为结局图鉴已在 ProgressionSystem 中，将判定一并纳入看似自然。
- **优点**：结局判定 + 图鉴持久化在同一系统中——数据流简洁。
- **缺点**：ProgressionSystem 的主要职责是跨局元进度存储——而非叙事评分计算。将 3 条线 × ~7 个条件的评分逻辑嵌入 ProgressionSystem 使其成为"叙事评分器"——严重越权。结局判定需要读取 30+ story_flags（通过 EventSystem）和 chapter_path——这些都是叙事域数据，与 ProgressionSystem 的统计/成就/天赋域无关。ProgressionSystem 的初始化时序（_ready 中直接调用 SaveLoadSystem.load_progression()）发生在故事开始前——结局判定是通关后事件，生命周期完全不对。
- **拒绝原因**：违反关注点分离原则。ProgressionSystem 是"跨局数据仓库"——不是"叙事结局判定器"。结局判定是 StorySystem 的职责，结局图鉴持久化是 ProgressionSystem 的职责——这两个职责通过 `unlock_ending()` 调用解耦，而非混合在一个系统中。

## 后果

### 积极的

- **不增加 Autoload**：RefCounted 工具类无 Autoload 开销——25 个 Autoload 的现状不变。结局判定仅在通关时实例化一次（~0.1ms 构造 + <0.1ms 计算），然后销毁。
- **测试性优秀**：`EndingEvaluator.evaluate()` 是纯函数——输入 `(EventSystem, chapter_path, run_data)`，输出 `EndingResult`。GUT 测试无需任何 Autoload：构造 mock EventSystem（返回预设 story_flags 值的 Dictionary） + mock chapter_path → 调用 `evaluate()` → 断言 `result.ending_id == "ascension_solo"`。18 个验收标准（GDD §验收标准）可直接翻译为 18 个 GUT 测试用例。
- **关注点分离清晰**：StorySystem 负责"何时判定"——EndingEvaluator 负责"如何判定"——ProgressionSystem 负责"如何存储"——EndingDisplayController 负责"如何展示"。四个关注点解耦，各自可独立修改。
- **一致的数据格式**：const Dictionary（ENDING_TEMPLATES）与 CHAPTER_TEMPLATES、FACTION_LIBRARY、realm_table 一致——项目内已确立的模式，开发者无需学习新格式。
- **ProgressionSystem 整合**：结局图鉴通过已有 API 持久化——不引入新文件格式、不重复实现 I/O 逻辑、享有原子写盘保护。
- **通关展示可恢复**：第 5 章完成后退出 → 下次启动 GSM 检测到 `completed_chapters` 包含所有 5 章 → StorySystem 重新发射 `game_victory` → 从结局展示第 1 幕重新开始。

### 消极的

- **StorySystem 轻微膨胀**：新增 `_on_game_victory()` 方法（~20 行）、`_collect_run_data()`（~10 行）、信号声明。EndingEvaluator 和 EndingResult 为独立 `.gd` 文件（不嵌入 StorySystem 脚本）——StorySystem 仅增加 ~30 行编排代码。这是有意的架构选择——编排逻辑在宿主系统，计算逻辑在工具类。
- **ENDING_TEMPLATES 可读性**：const Dictionary 嵌套 3 层的条件数组（line → conditions → {flag/chapter_choice/run_key, weight}）——在代码中阅读不如独立的 .tres 文件直观。缓解措施：每条条件和权重有 `desc` 字段（如 "第5章选择「飞升仙界」"）——增加自文档化。
- **策划修改权重需编辑 GDScript**：不接受非程序团队直接在 Inspector 中调整结局权重。缓解措施：6 个结局的权重值极少调整——不同于 EventSystem 的 60-100 个事件模板（策划频繁迭代）。如果未来扩展至 10+ 条结局线，考虑迁移 Resource 模式。
- **第 5 章偏斜打破平局的逻辑位置**：`_resolve_tie()` 在第 5 章偏斜 +5 后重新计算 `max()`——这意味着原本得分最高但第 5 章不匹配的线可能被反超。GDD 明确设计为此行为（"此刻的选择比过去更重"）——但条件数组中的 `chapter_choice` 已为第 5 章给了 +30 权重，偏斜 +5 是额外的打破僵局机制。需在代码注释中说明此设计意图。

### 风险

- **game_victory 信号丢失**：StorySystem 的 `game_victory` 信号无消费者（SceneManager 未就绪）→ 结局判定静默跳过。缓解措施：StorySystem 的 `_on_game_victory()` 是内部连接（`_ready()` 中连接），不依赖外部消费者。EndingEvaluator 始终运行，`ending_evaluated` 信号作为 Cat 2b 通知发射。即使 UI 未监听，结局图鉴已通过 ProgressionSystem 持久化。
- **ProgressionSystem 未初始化**：`ProgressionSystem._initialized_and_loaded == false` 时调用 `unlock_ending()` → 失败返回 `{success: false, reason: "not_initialized"}`。缓解措施：`_on_game_victory()` 检查 `ProgressionSystem._initialized_and_loaded` 标志——若为 false 则延迟持久化（在下一帧重试或记录到待写队列）。通关是游戏终点——ProgressionSystem 在启动时即初始化（Autoload #12），通关前必定已就绪。
- **结局图鉴写入与展示异步**：`unlock_ending()` 已通过 `progression_updated` 信号触发 SaveLoadSystem 同步写盘——`_on_game_victory()` 调用 `unlock_ending()` 后结局数据已持久化。展示序列仅从 ProgressionSystem 读取已完成写入的数据——不存在异步竞态。
- **EndingResult 在展示序列中传递大量数据**：EndingResult 包含完整的 `epilogue` 文本（~500-1000 字符）和 `scores` 字典——通过信号传递 RefCounted 对象无额外内存复制（Godot RefCounted 以引用传递）。展示场景接收后通过 `SceneManager.request_scene_change()` 的 context 参数传递。

## 解决的 GDD 需求

| GDD 需求 | 本 ADR 如何解决 |
|------------|--------------------------|
| §1 全局结局判定模型（5 步流程） | EndingEvaluator.evaluate() 实现——收集输入 → 计算得分 → 取最高分 → 判定变体 → 返回 EndingResult |
| §2 三条结局主线 + 权重表 | ENDING_TEMPLATES const Dictionary——每条线的条件/权重/变体规则 |
| §3 结局得分平局处理 | _resolve_tie() 方法——第 5 章偏斜 +5 + 优先级打破僵局 |
| §4 通关展示流程（CG → 尾声 → 统计 → 图鉴 → 轮回） | EndingDisplayController 场景内节点驱动 3 幕展示序列 + SceneManager 场景切换 |
| §5 结局图鉴存储结构 | ProgressionSystem._endings 域——通过 unlock_ending()/get_unlocked_endings()/get_ending_detail() API |
| §6 结局对后续游戏的影响 | ProgressionSystem._meta.total_completions（unlock_ending() 内置递增）；结局图鉴数据跨局持久化 |
| §7 叙事文本的剧情引用 | _generate_epilogue() 方法——story_flags 驱动的插入段落 + 12 句上限截断 |
| §8 结局系统与章节结局的关系 | 明确职责分界——StorySystem 提供第 5 章结局选择 + game_victory 触发；EndingEvaluator 聚合判定 |
| 全部 18 个验收标准 | 纯函数设计可直接翻译为 GUT 测试用例——mock EventSystem + chapter_path → 断言 ending_id |

## 性能影响

- **CPU**：`evaluate()` <0.1ms（3 条线 × ~7 条件 × O(1) 字典查找 + `get_flag()` × ~5 个条件变量 = ~30 次 O(1) 查询）。`_generate_epilogue()` <0.05ms（字符串拼接 ~10 个段落）。均在通关瞬间执行一次——无每帧开销。
- **内存**：ENDING_TEMPLATES const Dictionary <10KB（编译时常量——零运行时加载）。EndingEvaluator 实例 <1KB（RefCounted——结算后销毁）。EndingResult <5KB（尾声文本是最重的字段——~1000 字符，信号传递后展示场景持有 30 秒然后释放）。
- **加载时间**：无影响——EndingEvaluator 和 EndingResult 为纯 GDScript 类，const Dictionary 编译时分配。
- **网络**：不适用（纯单机游戏）。

## 需同步更新的 ADR

- **ADR-0026（StorySystem）**：新增 `ending_evaluated` 信号和 `_on_game_victory()` 方法——更新 §"关键接口总结" 部分
- **ADR-0012（ProgressionSystem）**：确认 `unlock_ending()` 和 `get_ending_detail()` API 与 EndingEvaluator 的调用方式兼容——已在 ADR-0012 §"结局图鉴领域" 中充分定义，无需修改
- **架构文档**：architecture.md §"叙事子系统" 中结局分支系统的拥有/暴露/消费字段更新——明确"嵌入 StorySystem + EndingEvaluator（RefCounted 工具类）"

## 验证标准

- **GIVEN** 第 5 章选择「飞升仙界」+ 前 4 章偏向飞升线 → `evaluate()` 返回 `ending_id == "ascension_solo"`（若 ch4=独自飞升）或 `"ascension_duo"`（若 ch4=携伴飞升）
- **GIVEN** 第 5 章选择「留在归墟之境」+ 前 4 章偏向中立/魔道 → `evaluate()` 返回 `"guardian_lone"` 或 `"guardian_order"`（根据银翎状态）
- **GIVEN** 第 5 章选择「归隐东域」+ 身份=青云剑宗 + 银翎存活 + 天赋 >=10 + 通关 >=3 → `evaluate()` 返回 `"return_sect"`
- **GIVEN** 飞升线=50, 守护线=50（平局）+ 第 5 章选择=飞升 → 偏斜 +5 → 飞升线=55 胜出 → `"ascension_*"`
- **GIVEN** 飞升线=55, 守护线=50 + 第 5 章选择=守护 → 偏斜后 55=55 平局 → 优先级飞升 >守护 → `"ascension_*"`
- **GIVEN** 玩家在第 5 章结局选择后退出 → 重新启动 → 检测到 5 章完成 → `game_victory` 重新发射 → 从结局展示第 1 幕开始
- **GIVEN** progress.dat 损坏 → `progression.dat` 重新生成——结局图鉴为空（6 个结局均未解锁）
- **GIVEN** ProgressionSystem.get_meta("total_completions") == 2 → `unlock_ending()` 调用后 == 3（内置递增）
- **GIVEN** 全部 6 个结局解锁 → `get_unlocked_endings().size() == 6` → 图鉴 UI 显示「图鉴完成·超凡入圣」

## 相关决策

- ADR-0026（StorySystem——game_victory 信号、chapter_path 所有权、结局判定的宿主）
- ADR-0003（EventSystem——story_flags 的只读查询 `get_flag()`）
- ADR-0012（ProgressionSystem——结局图鉴持久化 API `unlock_ending()`、`get_unlocked_endings()`）
- ADR-0001（GSM——`player.realm`、`player.identity_id` 只读）(已被 ADR-0012 取代 progress.* 域所有权)
- ADR-0007（信号分类体系——ending_evaluated 为 Cat 2b 信号）