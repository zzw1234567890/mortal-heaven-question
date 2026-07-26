# ADR-0027：对话系统 — RefCounted 服务类 + JSON 数据存储 + 零 Autoload 扩容

## 状态
Accepted

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Narrative |
| **知识风险** | LOW（JSON.parse_string、RefCounted、信号连接均为 Godot 4.x 成熟 API；打字机效果使用 Timer + _process 逐字渲染） |
| **需要验证** | `JSON.parse_string()` 同步解析 80-110 个对话树文件的加载延迟（按需加载——单次 3-15 节点 < 5ms）；RefCounted 在信号回调中的生命周期——确保 UI 持有 DialoguePlayer 引用期间不被 GC 回收；bark 池状态 `GSM.session.bark_history: Dictionary` 跨场景存活性——session.* 域为瞬态，场景切换后仍保留 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——条件判定通过第一层直接读取 `player.*`、`narrative.*`、`collection.*`；outcomes 通过第二层原子方法 `add_resource()`、`add_cultivation()`、`add_card_to_collection()` 写入；bark 池状态存储于 `GSM.session.bark_history` 瞬态域）；ADR-0003（EventSystem——`set_flag` outcome 委托 `EventSystem.set_flag()`；condition 类型词汇表部分复用 EventCondition 枚举）；ADR-0026（StorySystem——章节进度决定可用对话树；`get_chapter_data()` 提供当前章节上下文用于对话树 ID 解析；`chapter_started` 信号触发章节引子对话；`chapter_completed` 信号触发章末结局对话） |
| **启用** | ADR-0028+（结局分支系统——章末结局对话的选择结果写入 story_flags，供结局判定聚合）；ADR-UI（对话面板 UI——DialoguePlayer 发射信号驱动对话面板、选项面板、bark 气泡的渲染） |
| **阻塞** | 叙事 Epic（对话树播放、条件分支判定、bark 非阻塞展示）；UI Epic（对话面板/选项面板/bark 气泡/章节引子屏/章末结局屏的渲染） |
| **排序说明** | Feature 层——在 StorySystem（ADR-0026）之后被接受。对话系统的对话树 ID 由 StorySystem 和 EventSystem 提供，条件判定依赖 GSM 的 narrative.* 域。不增加 Autoload——RefCounted 服务类模式，零 Autoload 扩容。完整 25 链不变：GSM #1 / InputManager #2 / SceneManager #3 / SaveLoad #4 / EventSystem #5 / CardSystem #6 / CostSystem #7 / StatusEffectSystem #8 / CombatSystem #9 / CardEffectEngine #10 / RealmSystem #11 / ProgressionSystem #12 / BindingManager #13 / ExplorationSystem #14 / FactionSystem #15 / ResourceSystem #16 / DeploymentSystem #17 / AISystem #18 / SchoolSystem #19 / CultivationSystem #20 / IdentitySelectionSystem #21 / DeckEditingSystem #22 / FormationSystem #23 / TribulationSystem #24 / StorySystem #25 |

## 上下文

### 问题陈述

`dialogue-system.md` GDD 定义了完整的对话系统——两层数据结构 (DialogueNode + DialogueTree)、6 种对话类型（story/event/chapter_intro/chapter_end/bark/shop）、条件分支解析器、打字机效果播放引擎、NPC 角色定义、对话触发点路由。GDD 已明确对话系统是"对话的呈现引擎和条件分支解析器——不是内容创作工具"，但以下架构决策尚未解决：

1. **Autoload 定位**：已有 25 个 Autoload（超出 Godot 建议的 20 软上限）。对话系统是否真的需要独立 Autoload？对话树播放是瞬态操作——DialogueTree 是 Resource 模板，播放状态不需要跨场景持久化
2. **对话树存储格式**：80-110 个对话树 × 3-15 节点——JSON 文件 vs Resource (.tres) vs const Dictionary
3. **对话状态管理**：当前播放的对话树 ID、当前节点索引、对话历史——存在 GSM 中还是由播放器实例持有
4. **条件可见性判定**：DialogueNode 的 visibility_conditions 依赖 story_flags + player state——条件引擎是独立模块还是嵌入播放器
5. **对话结果写入**：DialogueOutcome.set_flag → EventSystem.set_flag() 委托——遵循 ADR-0003 的 story_flags 唯一写入者契约

### 约束

- story_flags 写入权不变：对话系统通过 `EventSystem.set_flag()` 委托（ADR-0003）
- GSM narrative.* 域：对话系统只读 story_flags、completed_chapters、current_chapter——不直接写入
- Foundation 层原则 #3：对话系统（Feature 层）可以依赖 Foundation 层和 Core 层系统
- 对话树可能很多：60+ NPC × 多条对话 + 章节引子/结局 + bark 池 ≈ 80-110 个对话树
- 对话进度不保存——对话中途退出后读档不恢复。但选项的 outcomes 在玩家选择时即时写入 GSM
- Autoload 链已满载——25 个 Autoload 超出 Godot 建议的 20 软上限。新增 Autoload 需要压倒性的理由

### 需求

- 6 种对话类型的播放引擎（story/event/chapter_intro/chapter_end/bark/shop）
- 条件可见性判定（10 种条件类型——见 GDD §3 条件系统）
- 文本变体选择（基于条件的多版本文本）
- 打字机效果（40 字/秒 + 标点停顿 + 点击快进 + 长按加速）
- 对话选项面板（灰显不满足条件的选项 + 条件提示）
- bark 非阻塞气泡（3 秒自动消失 + 点击消失 + 池不重复）
- 对话结果即时写入 GSM（通过 EventSystem 委托 + GSM 第二层原子方法）
- NPC 角色表查询（说话者 ID → 头像/表情/阵营）

## 决策

### 决策 1：对话系统使用 RefCounted 服务类 + 零 Autoload 扩容

**对话系统不作为 Autoload 注册。核心组件为两个 RefCounted 类：`DialoguePlayer`（对话播放引擎）和 `DialogueDatabase`（对话树数据访问层）。由触发对话的系统（StorySystem、EventSystem、CombatSystem 等）按需实例化。**

**为什么不需要 Autoload —— 四项论据：**

1. **对话是瞬态的**：DialogueTree 播放是"请求→播放→结束"的一次性操作。播放状态（当前节点索引、打字机进度、对话历史）在对话结束后即失效，不需要跨场景持久化。这与需要常驻内存的系统（GSM、EventSystem、StorySystem）本质不同。
2. **对话总是通过其他系统触发**：对话树 ID 来源于 StorySystem（章节引子/结局/剧情对话）、EventSystem（事件对话）、CombatSystem（战斗胜利 bark）等已有 Autoload。没有独立触发路径——对话系统不需要暴露全局入口。
3. **RefCounted 生命周期由 UI 持有者保证**：触发系统创建 DialoguePlayer → 传递给对话 UI 面板 → UI 面板持有引用并驱动渲染 → 对话结束后 UI 释放引用 → DialoguePlayer 自动释放。Godot 的 RefCounted 引用计数确保播放期间对象存活。
4. **bark 池状态通过 GSM.session 管理**：bark 池的"已使用列表"是会话级状态，存储于 `GSM.session.bark_history: Dictionary[String, Array[String]]`（瞬态域——不持久化到存档）。BarkManager RefCounted 读写此字典，无状态保存在自身。

**参考先例：**
- ADR-0013（BindingSystem）已论证 RefCounted 模型适用于"按需实例化、不持有持久状态"的系统——对话系统遵循相同模式
- ADR-0026（StorySystem）和 ADR-0014（ExplorationSystem）使用 Autoload 是因为持有需要跨场景存活的持久状态（章节进度、地图状态）——对话系统没有此类需求

**Autoload 扩容记录：**
- 当前：25 个（已超 20 软上限）
- 本 ADR 后：25 个（不增加）
- 未来预留：结局分支系统（ADR-0028+）——同样评估 RefCounted 优先方案

### 决策 2：对话树以 JSON 文件存储 + 按需加载

**对话树内容以 JSON 格式按章节组织存储（`assets/dialogue/ch{N}_*/`），由 `dialogue_index.json` 建立 ID→文件路径映射。`DialogueDatabase` RefCounted 按需加载——首次访问某对话树时同步解析 JSON，后续访问命中内存缓存。**

```
assets/dialogue/
├── ch1_qingyun/
│   ├── ch1_intro.json
│   ├── ch1_mo_yuan_confront.json
│   ├── ch1_ending.json
│   └── ch1_events.json
├── ch2_luanxinghai/
│   └── ...
├── shared/
│   ├── shop_greetings.json
│   ├── npc_barks.json            # bark 池定义
│   └── npc_profiles.json         # NPC 角色表
└── dialogue_index.json           # {tree_id: "ch1_qingyun/ch1_intro.json"}
```

**格式选择理由：**

| 维度 | JSON | Resource (.tres) | const Dictionary |
|------|------|------------------|------------------|
| 策划编辑 | 任意文本编辑器——无需 Godot | Godot Inspector——enum 下拉安全 | 编辑 GDScript 源码 |
| Git diff | 友好——结构化文本 | 可读但冗长 | 友好 |
| 外部工具验证 | 可脚本化批量校验 | 需 Godot 运行时 | 需 GDScript 解析 |
| 加载性能 | 首次 <5ms/文件（3-15 节点） | 类似 JSON 解析时间 | 编译时常量——零加载 |
| 规模适配 | 80-110 文件管理方便 | 80-110 个 .tres 文件略多 | 80-110 个字典条目——单文件过大 |

**选择 JSON 的决定性理由：**
- GDD 明确指定 JSON（§9 对话内容存储格式）——策划使用外部编辑器编写对话
- 数据规模不适配 const Dictionary：80-110 个对话树放入单个 .gd 文件约 3000-5000 行——编译时间和代码可读性均受影响
- Resource (.tres) 的 Inspector 编辑优势在"60+ NPC × 多条对话"的规模下被削弱——策划更可能在电子表格中批量编写后导出 JSON
- `dialogue_index.json` 在启动时一次性加载（约 3KB），对话树按需加载——不会阻塞启动

**JSON 模式示例：**
```json
{
  "id": "ch1_mo_yuan_confront",
  "title": "墨渊对峙",
  "trigger_type": "story",
  "allow_skip": true,
  "max_display_ms": 0,
  "start_node": "ch1_my_01",
  "end_action": "start_battle:mo_yuan_boss",
  "nodes": {
    "ch1_my_01": {
      "speaker": "mo_yuan",
      "speaker_display": "墨渊",
      "text": "小子，你的身体……老夫就收下了。",
      "expression": "smile",
      "delay_ms": 500,
      "next_node": "ch1_my_02"
    },
    "ch1_my_02": {
      "speaker": "lin_yuan",
      "speaker_display": "林渊",
      "text": "休想！",
      "expression": "angry",
      "choices": [
        {
          "id": "resist",
          "text": "拼死抵抗",
          "outcomes": [{"type": "set_flag", "target": "ch1_resisted_mo", "value": "true"}],
          "next_node": "ch1_my_03"
        }
      ]
    }
  }
}
```

### 决策 3：对话播放状态由 DialoguePlayer 实例持有——不持久化到 GSM

**对话播放的运行时状态（当前节点 ID、对话历史列表、打字机进度）完全由 DialoguePlayer RefCounted 实例持有。对话结束后实例释放，所有播放状态随之销毁。只有对话 outcomes（选择结果）在选择时即时写入 GSM。**

**状态分层：**

| 状态 | 持有者 | 持久化 | 生命周期 |
|------|--------|:------:|----------|
| 当前节点指针 `_current_node_id` | DialoguePlayer | 否 | 单次对话播放 |
| 对话历史 `_dialogue_history: Array[String]` | DialoguePlayer | 否 | 单次对话播放 |
| 打字机渲染进度 `_typing_index: int` | 对话 UI 面板 | 否 | 单句播放 |
| 对话 outcomes（set_flag/add_resource 等） | GSM（通过 EventSystem 委托写入） | **是** | 永久（存档） |
| bark 池已使用列表 `bark_history` | `GSM.session.bark_history` | 否（瞬态） | 单次游戏会话 |
| NPC 角色表 + 对话树缓存 | DialogueDatabase | 否（编译时常量 + 内存缓存） | 应用生命周期 |

**对话中途退出游戏的处理：**
- 对话播放进度不保存——读档后对话不恢复
- 但 outcomes 在选择时已即时写入 GSM——选择的影响已保存
- 玩家重新触发对话树时从头播放——对话树是可重入的（GDD §边界情况 #2）

**为什么不用 GSM 存储播放进度：**
- 对话进度恢复的价值低——玩家退出后重新进入，通常希望从头看起或跳过（对话树可跳过）
- 存储播放进度增加存档复杂度——需要序列化"当前节点 ID + 条件分支选择路径"
- chapter_end 对话不可跳过——如果玩家在章末结局中途退出，重新选择是公平的（叙事主体性保护）

### 决策 4：条件评估器嵌入 DialoguePlayer——独立条件引擎，读取 GSM

**条件评估逻辑作为 `ConditionEvaluator` 内部类嵌入 `DialoguePlayer`。它是一个纯函数——输入为条件列表 + GSM 引用，输出为布尔值。评估器独立于 EventSystem 的 `check_condition()`，但复用相似的条件类型词汇表。**

**条件类型对照（对话系统 vs EventSystem）：**

| 对话条件类型 | EventSystem 对应 | 新增/扩展 |
|-------------|-----------------|-----------|
| `story_flag` | `FLAG_SET` / `FLAG_NOT_SET` | 支持 `==` / `!=` / `has` / `not_has` 运算符 |
| `realm` | `REALM` | 支持完整比较运算符 (`>=` / `<=` / `>` / `<` / `==` / `!=`) |
| `faction` | `FACTION` | 相同 |
| `card_owned` | `CARD_OWNED` | 相同 |
| `identity` | — | **新增**：本局身份匹配 |
| `chapter_completed` | — | **新增**：章节完成判定 |
| `relation` | — | **新增**：NPC 好感度（未来系统） |
| `has_item` | — | **新增**：持有物品/资源 |
| `combat_result` | — | **新增**：上一场战斗结果 |
| `always` | — | **新增**：兜底选项 |

**为什么独立于 EventSystem：**
- 对话条件的语义不同：EventSystem 的条件用于"选项是否可选"（全部不满足→隐藏选项），对话系统的条件用于"节点是否可见"（不满足→跳过节点）和"选项是否可选"（不满足→灰色显示+提示）
- `format_condition_hint()` 是对话系统独有的——生成面向玩家的条件提示文本
- 对话条件类型是 EventSystem 的超集——扩展了 identity、chapter_completed 等类型
- 两者都从 GSM 读取——条件评估结果天然一致，不存在数据漂移

**关键接口：**
```gdscript
## DialoguePlayer 内部
class ConditionEvaluator:
    ## 评估节点可见性——任一条件不满足则不可见（跳过节点）
    func evaluate_node_visibility(conditions: Array, gsm: GameStateManager) -> bool

    ## 评估选项可用性——任一条件不满足则灰色+提示
    func evaluate_choice_availability(conditions: Array, gsm: GameStateManager) -> Dictionary
    # → {available: bool, hint: String}

    ## 评估单条件
    func _evaluate_single(cond: Dictionary, gsm: GameStateManager) -> bool

    ## 生成面向玩家的条件提示
    func _format_hint(cond: Dictionary) -> String
```

### 决策 5：对话结果写入——委托 EventSystem + GSM 第二层

**DialogueOutcome 的执行遵循 ADR-0003 的委托写入契约和 ADR-0001 的 GSM 第二层 API：**

```gdscript
## DialoguePlayer._execute_outcomes(outcomes: Array[Dictionary]) -> void
func _execute_outcomes(outcomes: Array) -> void:
    for oc in outcomes:
        match oc["type"]:
            "set_flag":
                # 委托 EventSystem——story_flags 唯一写入者（ADR-0003）
                EventSystem.set_flag(oc["target"], oc["value"])
            "add_resource":
                GSM.add_resource(oc["target"], oc["value"])        # ADR-0001 第二层
            "add_card":
                # 信号委托——与 EventSystem 的 ADD_CARD 路径一致
                EventSystem.card_reward_requested.emit(oc["target"])
            "trigger_battle":
                # 对话关闭后由触发系统处理——此处仅记录
                _pending_battle_id = oc["target"]
            "advance_chapter":
                # 委托 StorySystem（ADR-0026）
                StorySystem.complete_chapter(oc["target"])
            "change_relation":
                GSM.narrative.relations[oc["target"]] += oc["value"]
                GSM.batch_updated.emit({...})
            "nothing":
                pass  # 纯叙事
```

**story_flags 写入路径（符合 ADR-0003 契约）：**
```
DialogueOutcome.set_flag → EventSystem.set_flag() → GSM.set_narrative_flag() → batch_updated 信号
```

### 核心类设计

#### DialoguePlayer (RefCounted)

```gdscript
## 对话播放引擎——单次对话会话的生命周期
class_name DialoguePlayer extends RefCounted

## 信号——由对话 UI 面板连接
signal node_changed(node: Dictionary)                # 当前节点更新（含文本变体解析后）
signal choices_presented(choices: Array, node_id)    # 显示选项面板
signal dialogue_ended(end_action: String)            # 对话结束
signal bark_ready(text: String, speaker_id: String)  # bark 文本就绪

## 公共接口
func play(tree: Dictionary) -> void
    # 开始播放对话树——发射第一条 node_changed

func advance() -> void
    # 玩家点击推进——跳转到下一节点或显示选项

func select_choice(choice_index: int) -> void
    # 玩家选择选项——结算 outcomes → 跳转 → 继续播放

func skip() -> void
    # 跳过整段对话——不触发 outcomes（chapter_end 调用时抛出警告）

func get_dialogue_history() -> Array[String]
    # 返回迄今已显示的文本列表——供对话历史 UI

## 内部状态（瞬态——不持久化）
var _tree: Dictionary = {}
var _current_node_id: String = ""
var _dialogue_history: Array[String] = []
var _pending_battle_id: String = ""
```

#### DialogueDatabase (RefCounted)

```gdscript
## 对话树数据访问层——启动时加载索引，按需加载对话树
class_name DialogueDatabase extends RefCounted

## 按需获取对话树
func get_tree(tree_id: String) -> Dictionary:
    if _cache.has(tree_id):
        return _cache[tree_id]
    var file_path := _index.get(tree_id, "")
    if file_path.is_empty():
        push_error("DialogueDatabase: tree '%s' not found in index" % tree_id)
        return {}
    var tree := _load_json("res://assets/dialogue/" + file_path)
    _cache[tree_id] = tree
    return tree

## 获取 NPC 信息
func get_npc_profile(speaker_id: String) -> Dictionary

## 获取 bark 池（从缓存中检索）
func get_bark_pool(character_id: String) -> Array[String]

## 内部
var _index: Dictionary = {}     # {tree_id: file_path}——启动时从 dialogue_index.json 加载
var _cache: Dictionary = {}     # {tree_id: parsed_tree}——内存缓存
var _npc_profiles: Dictionary = {}  # NPC 角色表
var _bark_data: Dictionary = {}     # bark 池数据

func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("DialogueDatabase: cannot open '%s'" % path)
        return {}
    var text := file.get_as_text()
    file.close()
    var json := JSON.new()
    var err := json.parse(text)
    if err != OK:
        push_error("DialogueDatabase: JSON parse error in '%s': %s" % [path, json.get_error_message()])
        return {}
    return json.get_data()
```

#### BarkManager (RefCounted)

```gdscript
## bark 管理器——从 GSM.session.bark_history 读取/写入池状态
class_name BarkManager extends RefCounted

## 从角色 bark 池中抽取一条（本局不重复策略）
func get_bark(character_id: String, pool: Array[String]) -> String:
    var history: Array = GSM.session.bark_history.get(character_id, [])
    var available: Array = []
    for bark in pool:
        if bark not in history:
            available.append(bark)
    if available.is_empty():
        # 池耗尽——重置全部，但避免与上一句重复
        history.clear()
        available = pool.duplicate()
    var chosen := available[randi() % available.size()]
    history.append(chosen)
    GSM.session.bark_history[character_id] = history
    return chosen

## 查询——供对话历史 UI
func get_bark_history(character_id: String) -> Array[String]:
    return GSM.session.bark_history.get(character_id, [])
```

### 触发流示例

```
# 示例 1：剧情对话（StorySystem 触发）
# StorySystem 在章节进度到达某节点时：

var db := DialogueDatabase.new()
var tree := db.get_tree(&"ch1_mo_yuan_confront")
var player := DialoguePlayer.new()
player.node_changed.connect(_ui.show_dialogue_panel)
player.choices_presented.connect(_ui.show_choices_panel)
player.dialogue_ended.connect(_ui.hide_dialogue_panel)
player.play(tree)
# → UI 持有 player 引用 → 对话播放 → 结束后释放

# 示例 2：bark（CombatSystem 触发——战斗胜利后）
var db := DialogueDatabase.new()
var pool := db.get_bark_pool(&"lin_yuan")
var bark_mgr := BarkManager.new()
var text := bark_mgr.get_bark(&"lin_yuan", pool)
_ui.show_bark_bubble(text, &"lin_yuan", 3.0)  # 非阻塞——3 秒后自动消失
# → BarkManager 写回 GSM.session.bark_history

# 示例 3：多个对话触发请求冲突
# 后到达的请求覆盖前一个——符合 GDD §边界情况 #11
# 实现：UI 面板在收到新 node_changed 信号时关闭当前对话面板
```

## 考虑的替代方案

### 替代方案 A：独立 Autoload #26

- **描述**：DialogueSystem 注册为 Autoload #26，提供全局 `DialogueSystem.play_tree(id)` 入口
- **优点**：所有系统通过统一的全局入口访问——调用简洁（`DialogueSystem.play_tree(tree_id)`）；bark 管理更自然（bark 池状态由 Autoload 持有，不需要 GSM.session 中转）
- **缺点**：Autoload 链 25→26——第 4 个超出软上限 20 的 Autoload。对话播放是瞬态的——Autoload 的生命周期保证（场景变更后存活）对对话系统是过度设计。绝大多数情况下对话系统处于空闲——占用常驻内存但极少使用
- **拒绝原因**：对话系统不需要 Autoload 的任何核心优势（全局可访问、场景无关、生命周期保证）。RefCounted 模型在"按需实例化、瞬时使用"的场景下更精确。如果未来对话系统需要新的 Autoload 级能力（如跨场景对话暂停/恢复），可以升级——但当前需求不支持升级

### 替代方案 B：嵌入 StorySystem (ADR-0026)

- **描述**：对话播放逻辑和对话树数据访问作为 StorySystem 的内部模块——StorySystem 新增 `play_story_dialogue()`、`play_chapter_intro()`、`play_chapter_ending()` 方法
- **优点**：零 Autoload 扩容——StorySystem 已经是 #25；对话树组织天然按章节——StorySystem 管理章节进度；减少跨系统通信——StorySystem 直接调用对话播放，无需通过中间层
- **缺点**：StorySystem 膨胀——在 ~200 行章节管理逻辑基础上增加 ~500 行对话播放逻辑；违反单一职责——"管理章节进度"和"播放对话文本"是两个不同的关注点；bark 触发来源多样化（CombatSystem、CraftingSystem、DeckEditingSystem）——这些系统不应依赖 StorySystem 来播放 bark；EventSystem 的事件对话也需通过 StorySystem 中转——引入不必要的中间层
- **拒绝原因**：StorySystem 的职责是"章节进度管理 + 剧情编排"，对话播放是独立的呈现层关注点。将两者合并会造成约 700 行的 Autoload——调试和维护成本显著增加。bark 的多样性触发来源进一步削弱了"嵌入 StorySystem"的合理性

### 替代方案 C：Resource (.tres) 对话树

- **描述**：每个对话树作为 `DialogueTreeResource` 存储在 `.tres` 文件中，Inspector 中可视化编辑节点、选项、条件和结果
- **优点**：Inspector 编辑——enum 下拉菜单（trigger_type、condition type、outcome type）防止拼写错误；Godot 原生类型安全——`@export` 字段编译时检查
- **缺点**：80-110 个 .tres 文件管理负担重；嵌套 Resource 结构（DialogueTreeResource→Array[DialogueNodeResource]→Array[DialogueChoiceResource]→Array[ConditionResource]/Array[OutcomeResource]）在 Inspector 中编辑体验不佳——大量展开/折叠；策划可能需要 Godot 编辑器——增加了非技术策划的门槛
- **拒绝原因**：GDD 明确指定 JSON 格式以支持策划使用外部编辑器。嵌套 Resource 的 Inspector 编辑在 80-110 个对话树的规模下体验不如 JSON + 外部工具。如果团队后续决定转向 Resource 格式（例如策划反馈 JSON 容易拼写错误），迁移成本可控——DialogueDatabase 的内部实现替换，公开 API 不变

### 替代方案 D：const Dictionary 编译时常量

- **描述**：所有 80-110 个对话树作为单个 `const DIALOGUE_TREES: Dictionary` 常量嵌入 .gd 文件——类似 StorySystem 的 `CHAPTER_TEMPLATES`
- **优点**：零运行时加载——编译时分配；类型安全——GDScript 字典语法在编辑器中有基本检查
- **缺点**：文件巨大——80-110 个对话树 × 平均 8 节点 × ~15 行 = 约 10,000-15,000 行单个 .gd 文件；编辑体验极差——策划在 GDScript 源码中编辑嵌套字典；与 GDD 指定的 JSON 格式矛盾；编译时间增加——Godot 解析大型 .gd 文件
- **拒绝原因**：数据规模不适配——StorySystem 的 `CHAPTER_TEMPLATES` 是 5 章 × ~30 字段 ≈ 150 行，对话系统是 80-110 个对话树 ≈ 10,000+ 行。const Dictionary 的优势（编译时验证、零加载）在此规模下被维护成本完全抵消

## 后果

### 积极的

- **零 Autoload 扩容**：25 个 Autoload 保持不变——对话系统采用 RefCounted 模型，不增加常驻内存负担
- **清晰的职责分离**：DialoguePlayer 负责播放逻辑——DialogueDatabase 负责数据访问——BarkManager 负责 bark 池管理。三个 RefCounted 类各司其职
- **按需加载**：对话树 JSON 文件在首次访问时加载并缓存——启动时间不受对话树数量影响。dialogue_index.json 仅约 3KB
- **策划友好**：JSON 格式支持任意文本编辑器编辑、Git diff 友好、外部工具批量校验——符合 GDD 设计意图
- **story_flags 写入合规**：委托 EventSystem.set_flag()——遵循 ADR-0003 的单一写入者契约。所有 story_flags 变更经过同一审计点
- **条件评估一致性**：DialoguePlayer 和 EventSystem 都从 GSM 读取——条件判定结果天然一致，不存在数据漂移
- **可测试性**：DialoguePlayer 是纯 RefCounted——可在单元测试中独立实例化，注入模拟的 GSM 和 DialogueDatabase

### 消极的

- **调用方需了解 DialoguePlayer API**：触发对话的系统（StorySystem、EventSystem、CombatSystem 等）需要创建 DialoguePlayer 并连接信号——比 `DialogueSystem.play_tree(id)` 多约 5 行代码。缓解：提供 `DialogueFacade` 静态工具方法封装常见模式
- **bark 池状态依赖 GSM.session**：bark 池的已使用列表存储在 GSM.session.bark_history——这是 GSM 中唯一的"对话相关"状态。如果未来 bark 逻辑复杂化（如跨角色 bark 连锁），GSM.session 的对话状态可能膨胀
- **JSON 解析运行时开销**：首次访问对话树时需要同步解析 JSON——每个对话树 3-15 节点，解析约 <5ms。80-110 个对话树全部加载约 400-500ms——但按需加载意味着实际只加载玩家遇到的对话树（每局约 15-25 个，总计 <125ms）
- **无全局对话队列**：多个对话触发请求到达时，RefCounted 模型依赖 UI 面板管理冲突（后到达覆盖前一个）——无法实现排队。GDD §边界情况 #11 已明确"后到达覆盖前一个"——此行为符合设计，但缺乏集中调度点
- **与 StorySystem 的循环依赖风险**：DialogSystem 依赖 StorySystem（章节进度 → 对话树 ID），StorySystem 的章节结局依赖对话系统（章末结局对话 → 选择结果写入 story_flags）——实际上不是循环依赖：StorySystem 触发对话但不依赖对话播放逻辑；对话系统写入 story_flags 通过 EventSystem 委托而非直接回调 StorySystem

### 风险

- **DialoguePlayer 在信号回调中过早释放**：UI 面板持有 DialoguePlayer 引用期间，如果 Godot 的 RefCounted 因信号断开而提前回收 → 对话播放中断。缓解：UI 面板显式持有 `var _current_player: DialoguePlayer` 成员变量——保证引用计数 > 0 直到对话结束
- **dialogue_index.json 与文件系统不同步**：策划新增对话树 JSON 文件但忘记更新索引 → 对话树不可访问。缓解：DialogueDatabase 在编辑器模式下启动时扫描 `assets/dialogue/` 目录并验证索引完整性——缺失条目记录警告
- **对话树 JSON 引用不存在的 next_node**：节点 A 的 next_node 指向不存在的节点 B → 对话阻塞。缓解：DialoguePlayer.play() 在开始播放前全量验证所有节点的 next_node 引用——发现悬空引用时截断对话并记录错误
- **bark_history 无限增长**：单次游戏会话中 bark 触发超过池大小 → history 数组累积。缓解：BarkManager.get_bark() 在池耗尽时清空 history——数组大小始终 ≤ bark 池大小
- **JSON 中 condition type 拼写错误**：策划在 JSON 中写 `"type": "storyflag"` 而非 `"story_flag"` → 条件评估静默失败。缓解：DialogueDatabase 加载时验证所有 condition type 值是否在已知枚举中——未知类型记录警告并视为 `always`（安全兜底）

## 与现有系统的交互

| 系统 | 交互方向 | 协议 |
|------|:--------:|------|
| **GSM (ADR-0001)** | 读取 + 写入 | 第一层读取（条件判定）；第二层写入（outcomes: add_resource, add_cultivation, remove_card 等） |
| **EventSystem (ADR-0003)** | 委托写入 | `set_flag` outcome → EventSystem.set_flag()；`add_card` outcome → EventSystem.card_reward_requested 信号 |
| **StorySystem (ADR-0026)** | 读取 + 触发 | 读取 `get_current_chapter()` 用于对话树 ID 解析；被 StorySystem 调用以播放章节引子/结局对话 |
| **CombatSystem (ADR-0008)** | 触发 | 战斗胜利后触发 victory bark；`combat_result` 条件判定读取战斗结果 |
| **ExplorationSystem (ADR-0014)** | 触发 | 事件节点 → EventSystem → 对话树 ID；商店节点 → 商店问候对话 |
| **UI 系统** | 信号驱动 | DialoguePlayer 发射 node_changed / choices_presented / dialogue_ended → UI 面板渲染 |

## 性能影响

- **CPU**：条件评估 O(n)——每个节点最多 10 个条件 × O(1) GSM 字典读取 = <0.01ms/节点。JSON 解析 3-15 节点 <5ms/对话树（首次加载）。打字机效果 = 每 25ms 一个字符——非帧密集型
- **内存**：DialogueDatabase 缓存——已访问的对话树累积。每局约 15-25 个对话树 × 平均 3KB = 45-75KB。DialoguePlayer 实例约 2KB（播放状态）——对话结束后释放。dialogue_index.json 约 3KB——常驻。NPC 角色表约 5KB——常驻。总计常驻 <10KB + 会话缓存 <75KB
- **加载时间**：启动时仅加载 dialogue_index.json + npc_profiles.json（约 8KB，<1ms）。对话树按需加载——不会阻塞启动
- **网络**：不适用（纯单机游戏）

## 解决的 GDD 需求

| GDD 需求 | 本 ADR 如何解决 |
|-------------|--------------------------|
| §1 对话数据结构（DialogueNode + DialogueTree + DialogueChoice + DialogueOutcome） | 确立 JSON 模式——DialogueDatabase 解析为 Dictionary；DialoguePlayer 以 Dictionary 而非 Resource 操作 |
| §2 对话类型（6 种：story/event/chapter_intro/chapter_end/bark/shop） | 确立 trigger_type 枚举 + 各类型的播放模式和跳过行为——由 DialoguePlayer 根据类型切换行为 |
| §3 条件系统（10 种 condition type + 可见/灰色语义） | 确立 ConditionEvaluator 内嵌于 DialoguePlayer——节点不满足→跳过，选项不满足→灰色+提示 |
| §4 对话播放引擎（打字机 + 点击推进 + 跳过） | 确立 DialoguePlayer RefCounted——信号驱动 UI 渲染（node_changed → 打字机效果在 UI 侧实现） |
| §5 文本变体 | 确立 select_text_variant() 在 DialoguePlayer.node_changed 发射前解析——UI 收到的是最终文本 |
| §6 NPC 角色定义 | 确立 npc_profiles.json + DialogueDatabase.get_npc_profile() |
| §7 对话触发点（6 种触发场景） | 确立触发路由——StorySystem/EventSystem/CombatSystem → DialoguePlayer 实例化 |
| §8 对话状态管理 + story_flags 所有权 | 确立播放状态瞬态（DialoguePlayer 持有）；outcomes 即时写入 GSM；set_flag 委托 EventSystem |
| §9 对话内容存储格式 | 确立 JSON 文件 + dialogue_index.json——按章节组织，按需加载 |
| §边界情况 #1 对话中途退出 | 确立播放进度不保存——outcomes 已即时写入 GSM，对话从头重新播放 |
| §边界情况 #6 说话者 ID 不存在 | 确立 DialogueDatabase 返回通用占位信息 + 记录警告 |
| §边界情况 #11 多个对话触发请求 | 确立 UI 面板管理冲突——新 node_changed 信号关闭当前面板 |
| §边界情况 #15 对话树引用验证 | 确立 DialoguePlayer.play() 中全量验证 next_node 引用——悬空引用截断 + 日志 |

## 需同步更新的 ADR

本 ADR 不要求修改已有 ADR。对话系统是纯消费者——读取 GSM 状态、委托 EventSystem 写入——不引入新的 API 需求到已有 ADR。

## 验证标准

- `GIVEN` 对话树有 3 个节点，`WHEN` DialoguePlayer.play(tree) 被调用，`THEN` 逐句发射 node_changed 信号
- `GIVEN` 对话节点有 conditions（realm ≥ 2），`WHEN` 当前 realm=1，`THEN` 该节点被跳过——node_changed 发射下一个满足条件的节点
- `GIVEN` 对话选项有 conditions（story_flag: ch1_accepted=true），`WHEN` 该 flag=false，`THEN` choices_presented 中该选项的 available=false + hint="需要前置剧情条件"
- `GIVEN` DialogueOutcome type=set_flag，`WHEN` 玩家选择该选项，`THEN` EventSystem.set_flag() 被调用——GSM.narrative.story_flags 即时更新
- `GIVEN` 对话节点有 text_variants（基于 realm），`WHEN` realm=3，`THEN` node_changed 携带匹配 realm≥3 的变体文本
- `GIVEN` speaker=narrator 的节点，`WHEN` node_changed 发射，`THEN` 数据中标示 is_narrator=true
- `GIVEN` trigger_type=story，`WHEN` 玩家调用 skip()，`THEN` dialogue_ended 发射——outcomes 未执行
- `GIVEN` trigger_type=chapter_end，`WHEN` 玩家尝试 skip()，`THEN` 操作被忽略——push_warning 记录
- `GIVEN` BarkManager.get_bark() 同一角色连续调用 6 次（池大小=5），`THEN` 前 5 次各不相同，第 6 次重置池
- `GIVEN` DialogueDatabase.get_tree(tree_id) 首次调用，`THEN` JSON 文件被加载、解析并缓存——第二次调用命中缓存
- `GIVEN` dialogue_index.json 中引用的文件不存在，`WHEN` get_tree() 被调用，`THEN` 返回空 Dictionary + push_error
- `GIVEN` 对话树节点的 next_node 指向不存在的节点 ID，`WHEN` play() 被调用，`THEN` play() 中全量验证捕获并截断——对话在该节点后结束
- `GIVEN` 25 个 Autoload 已注册，`WHEN` 对话系统被实例化，`THEN` Autoload 链保持 25——对话系统为 RefCounted，不进入 Autoload 注册表

## 相关决策

- ADR-0001：GSM 三层 API——条件判定通过第一层读取，outcomes 通过第二层写入
- ADR-0003：EventSystem——story_flags 委托写入、card_reward_requested 信号委托、条件判定词汇表部分复用
- ADR-0026：StorySystem——对话树 ID 来源（章节引子/结局/剧情对话）、章节进度 → 对话树可用性过滤
- ADR-0013：BindingSystem——RefCounted 模型的先例（非 Autoload 服务类）
- ADR-0007：三分类信号体系——DialoguePlayer 信号为 Cat 2b（系统特定事件）
