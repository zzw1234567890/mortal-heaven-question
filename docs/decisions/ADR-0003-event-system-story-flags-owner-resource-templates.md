# ADR-0004：事件系统 — story_flags 唯一写入者 + Resource 模板 + 信号委托

## 状态
Proposed

## 日期
2026-07-24

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Foundation / Event System |
| **知识风险** | LOW（使用稳定 API `ResourceLoader.load()`、`DirAccess`、`@export` 嵌套 Resource，无 4.4+ 破坏性变更依赖） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/breaking-changes.md` |
| **使用的截止后 API** | `@export_range(0.0, 1.0, 0.01)`（4.x 稳定——float 滑块）；`JSON.stringify()` / `JSON.new().parse()`（4.x 稳定——仅用于模板导出/导入工具链，非运行时热路径）；`@export_group` / `@export_subgroup`（4.x 稳定——优化嵌套 Resource Inspector 布局） |
| **需要验证** | 嵌套 Resource（EventTemplate → Array[EventOption] → Array[EventCondition]/Array[EventOutcome]）在 Godot 4.6 Inspector 中的编辑体验——60-100 个模板 (每个 3-5KB) 的浏览性能；`ResourceLoader.load()` 同步加载 60-100 个 .tres 文件时主线程阻塞时间（预计 <150ms）；`DirAccess.list_dir_begin()` 在 `res://` 路径下对大量文件的处理 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`narrative.*` 域包含 `story_flags`；需新增第二层原子方法 `set_narrative_flag(flag, value) → void` 供 EventSystem 调用；条件判定通过 GSM 第一层 `player.*` / `collection.*` 读取；结果执行通过 GSM 第二层 `add_resource()`、`add_cultivation()` 等原子方法）；ADR-0002（卡牌系统——`ADD_CARD` 结果通过信号委托给 CardSystem，由 CardSystem 执行 `create_instance()` + `serialize_instance()` + `GSM.add_card_to_collection()` 完整流程。委托信号：`card_reward_requested(template_id: StringName)`）；ADR-0003（存档/读档——`story_flags` 作为 `narrative.*` 域的一部分随存档持久化；`set_narrative_flag()` 发射信号后 SaveLoadSystem 判定是否需要自动存档） |
| **关联的 ADR** | ADR-0006（探索系统——探索节点类型→事件模板 ID 分配；事件触发时机由探索系统管理）；ADR-0007（战斗系统——`trigger_battle` Outcome → 加载战斗场景）；ADR-0008（卡牌效果引擎——`SET_FLAG` 效果类型委托 EventSystem.set_flag()，参见下文「Outcome 类型词汇表权威来源」） |
| **阻塞** | 探索 Epic（事件节点在地图上的分配和触发需要事件系统 API）、叙事 Epic（剧情系统/对话系统/结局系统均依赖 story_flags 的读写契约）、卡牌效果 Epic（效果引擎的 `SET_FLAG` 效果类型需委托 EventSystem 写入） |
| **排序说明** | Foundation 层第 5 个 ADR（最后一个 Foundation 层 ADR）。Autoload 初始化顺序 #5：`GSM → InputManager → SceneManager → SaveLoad → EventSystem`。EventSystem 在 GSM 和 SaveLoad 就绪后才可实用——GSM 提供条件读取 + 结果写入，SaveLoad 提供 story_flags 持久化。**Foundation 层原则 #3 合规**：EventSystem 不直接依赖任何 Core/Feature 层系统（CardSystem 委托通过信号解耦——见下文 §ADD_CARD 信号委托） |

## 上下文

### 问题陈述

游戏有 6 种事件类型（灵脉采掘、坊市交易、洞府奇遇、杀人夺宝、炼丹/炼器台、斜月三星洞），约 60-100 个事件模板，每个包含条件分支（阵营/境界/资源/卡牌拥有/story_flag 标记）和结果数据（概率 + 随机值范围）。

核心架构问题有三个：

1. **story_flags 写入权**：`architecture.md` §事件系统 已确立 EventSystem 是 `story_flags` 的**唯一运行时写入者**——剧情系统、对话系统和卡牌效果引擎通过委托写入。这需要在 ADR-0001 中新增专门的 GSM 第二层原子方法 `set_narrative_flag()`，而非使用通用的 `GSM.set()`（通用 set 违反 ADR-0001 的禁止模式）。

2. **Foundation 层原则 #3 合规——ADD_CARD 执行路径**：EventSystem 是 Foundation 层 Autoload（#5），CardSystem 是 Core 层 Autoload。ADD_CARD 结果需要 `CardSystem.create_instance()` + `serialize_instance()` 才能正确调用 `GSM.add_card_to_collection()`（ADR-0002 模型 A 契约）。如果 EventSystem 直接调用 CardSystem，则违反"Foundation 层不依赖任何游戏系统"的原则。

3. **事件模板的数据格式与 Inspector 编辑体验**：模板包含条件表达式和结果列表——需要类型安全的数据结构。Godot Resource（`.tres`）提供 Inspector 可视化编辑和 `enum` 下拉菜单，但 `Variant` 类型的 `@export` 字段在 Inspector 中无法编辑——需要替代方案。

### 约束

- **story_flags 唯一写入者**：EventSystem 是唯一的运行时写入者。剧情/对话/效果引擎通过委托写入，不直接操作 `GSM.narrative.story_flags`。写入路径：`EventSystem.set_flag() → GSM.set_narrative_flag()`（新增第二层方法）
- **Foundation 层原则 #3**：EventSystem 不直接依赖任何 Core/Feature 层系统。与 CardSystem 的交互通过信号委托解耦
- **GSM 三层 API 契约**：条件判定通过 GSM 第一层直接读取（零开销）；结果执行通过 GSM 第二层原子方法（原子性保证）；story_flags 写入通过新增的 `set_narrative_flag()`（第二层方法）
- **Resource 共享语义**：EventTemplate/Option/Condition/Outcome 均为 Resource——运行时只读。EventInstance 为 RefCounted 临时对象——**不持有 Resource 引用**，仅存储 `template_id: StringName` 和选项索引
- **编辑器可用性**：策划需在 Godot Inspector 中可视化编辑。所有 `@export` 字段必须是 Inspector 可编辑的类型（枚举、String、int、float、bool）——不使用 `Variant`
- **连锁深度限制**：最多 3 层 + 循环检测（visited_ids 集合）
- **存档兼容性**：已触发的事件不存储——`story_flags` 和 `exploration.map_state` 隐式记录事件进度

### 需求

- 6 种事件类型的模板定义（每种有对应的 Option/Outcome 结构）
- 条件判定引擎——6 种条件类型（realm ≥ N, faction == X, resource ≥ N, card_owned, flag_set, flag_not_set）
- 概率结果结算——`chance` + `[min, max]` 随机值范围（`use_range` 显式标志）
- 连锁事件支持——最多 3 层 + 循环检测
- 加权随机选择——从候选事件池中按权重选择事件
- story_flags 委托写入——剧情/对话/效果引擎通过 `EventSystem.set_flag()` 委托
- ADD_CARD 信号委托——EventSystem 发射 `card_reward_requested` 信号，CardSystem 响应执行完整流程
- 所有事件结算结束后发射 `event_resolved` 信号——SaveLoad 监听以判定是否需要自动存档

## 决策

**事件模板以 Godot Resource（`.tres`）格式存储，在编辑器 Inspector 中可视化编辑——不使用 `Variant` 类型，使用 `String` + `enum` + `use_range` 显式标志确保 Inspector 可编辑性。EventSystem 作为 Foundation 层 Autoload #5 管理事件模板数据库和运行时事件实例化。`story_flags` 的唯一运行时写入权归 EventSystem——通过新增的 GSM 第二层方法 `GSM.set_narrative_flag(flag, value)` 写入。ADD_CARD 结果通过信号委托给 CardSystem，保持 Foundation 层原则 #3 合规。**

### 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                    EventSystem (Autoload #5)                      │
│                                                                   │
│  ┌─ 事件模板注册表 ─────────────────────────────────────┐        │
│  │ templates: Dictionary[StringName, EventTemplate]       │        │
│  │   # 60-100 个 .tres 文件 → _ready() 中同步加载        │        │
│  └───────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 公共 API ───────────────────────────────────────────┐        │
│  │ trigger_event(event_id) → EventInstance               │        │
│  │ resolve_option(instance, opt_idx) → Array[Dict]       │        │
│  │ apply_outcomes(outcomes) → void                       │        │
│  │ select_event(candidates, realm) → StringName           │        │
│  │ set_flag(key, value) → void     # 唯一写入入口         │        │
│  │ get_flag(key, default) → Variant # 任意系统可读        │        │
│  │ check_condition(cond) → bool                          │        │
│  │ get_chain_event(inst, opt_idx) → StringName           │        │
│  └───────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 信号 ───────────────────────────────────────────────┐        │
│  │ event_triggered(event_id)                              │        │
│  │ event_resolved(event_id, option_idx, outcomes)         │        │
│  │   # ⚠️ SaveLoad 监听 → 判定是否触发自动存档            │        │
│  │ flag_changed(key, old, new)                            │        │
│  │   # 剧情/对话/结局系统监听                             │        │
│  │ chain_triggered(from, to)                              │        │
│  │ chain_ended(final_event_id)                            │        │
│  │   # 探索系统监听 → 恢复地图控制                        │        │
│  │ card_reward_requested(template_id)                     │        │
│  │   # ⚠️ Foundation 层不依赖 Core 层——信号委托          │        │
│  │   # CardSystem 监听此信号执行 create_instance +       │        │
│  │   # serialize_instance + GSM.add_card_to_collection   │        │
│  └───────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────┘
         │                    │                    │
         │ GSM 第一层读取      │ GSM 第二层写入      │ ResourceLoader
         │ (条件判定)          │ (set_narrative_flag) │ (模板加载)
         ▼                    ▼                    ▼
    ┌──────────┐       ┌──────────┐       ┌────────────────┐
    │   GSM    │       │   GSM    │       │ assets/events/  │
    │ player.* │       │ set_     │       │ *.tres          │
    │ narrative│       │ narrative│       │ (60-100 files)  │
    │ collection│      │ _flag()  │       └────────────────┘
    └──────────┘       │ add_     │
                       │ resource │
                       │ add_     │
                       │ cultivation│
                       └──────────┘
```

### 关键接口

#### EventCondition Resource（Inspector 可编辑）

```gdscript
## 条件类型枚举
enum ConditionType {
    REALM = 0,             # 境界 ≥ value_int
    FACTION = 1,           # 阵营 == value_str
    RESOURCE = 2,          # 资源 ≥ value_int
    CARD_OWNED = 3,        # 拥有卡牌 value_str
    FLAG_SET = 4,          # story_flag key == value_str
    FLAG_NOT_SET = 5,      # story_flag key != value_str
}

## 比较运算符（用于 REALM / RESOURCE 数值比较）
enum ConditionOperator { GE = 0, EQ = 1, LT = 2 }

class_name EventCondition extends Resource
@export var type: ConditionType
@export var operator: ConditionOperator = ConditionOperator.GE
@export var target: String = ""       # 目标键（如 "ling_shi"、"zhengdao"）
@export var value_str: String = ""    # 字符串值（阵营名、卡牌ID、flag键名）
@export var value_int: int = 0        # 整数值（境界等级、资源数量）
```

#### EventOutcome Resource（Inspector 可编辑——无 Variant）

```gdscript
## Outcome 类型枚举
## ⚠️ 此枚举是权威来源——ADR-0009（卡牌效果引擎）必须扩展（非复制）此枚举
## 参见 architecture.md OQ-05
enum OutcomeType {
    ADD_RESOURCE = 0,      # target=资源类型, value_int=数量
    ADD_CULTIVATION = 1,   # value_int=修为量
    ADD_CARD = 2,          # target=模板ID → 通过 card_reward_requested 信号委托
    REMOVE_CARD = 3,       # target=卡牌实例ID
    HEAL = 4,              # value_int=治疗量（战斗中）
    DAMAGE = 5,            # value_int=伤害量（战斗陷阱）
    SET_FLAG = 6,          # target=flag键, value_str=flag值
    GAIN_TALENT = 7,       # target=天赋ID → GSM.progression
    TRIGGER_BATTLE = 8,    # target=敌方阵容ID
    ADVANCE_CHAPTER = 9,   # target=章节ID
    RESTORE_AP = 10,       # value_int=行动力恢复量
    NOTHING = 11,          # 无效果（纯叙事文本）
}

class_name EventOutcome extends Resource
@export var type: OutcomeType
@export var target: String = ""       # 目标ID（资源名/卡牌模板ID/flag键名/天赋ID）

## 值——Inspector 中清晰分离
@export var value_str: String = ""    # 字符串值（flag值、阵营名）
@export var value_int: int = 0        # 整数值（资源量、修为量、AP量）

## 随机范围——use_range 显式标志避免 min=max=0 歧义
@export var use_range: bool = false
@export var min_value: int = 0
@export var max_value: int = 0

## 概率——Inspector 中显示 0-100% 滑块
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
```

#### EventOption + EventTemplate Resource

```gdscript
class_name EventOption extends Resource
@export var option_id: String = ""
@export_multiline var text: String = ""
@export var conditions: Array[EventCondition] = []
@export var outcomes: Array[EventOutcome] = []
@export var weight_override: int = 0  # 0=无覆盖

class_name EventTemplate extends Resource
@export var template_id: StringName = &""
@export var event_type: EventType
@export var title: String = ""
@export_multiline var description: String = ""
@export var min_realm: int = 1
@export var weight: int = 10
@export var chain_next: StringName = &""   # 空=无连锁
@export var chain_on_option: int = -1      # -1=任意选项触发, n=仅第n个选项
@export var is_hidden: bool = false
@export var options: Array[EventOption] = []
```

#### EventInstance（RefCounted——不持有 Resource 引用）

```gdscript
## 运行时事件实例——结算后销毁
## ⚠️ 不持有 Resource 引用（避免与 ADR-0002 相同的共享 Resource 陷阱）
## 仅存储 template_id + 选项索引列表
class_name EventInstance extends RefCounted
var template_id: StringName
var available_option_indices: Array[int] = []  # 已过滤的选项索引（非 Resource 引用）
var all_options_hidden: bool = false
var chain_depth: int = 0
var selected_option_index: int = -1  # 玩家选择的选项索引
var resolved_outcomes: Array[Dictionary] = []  # 已结算的结果列表
```

#### EventSystem API

```gdscript
func _ready():
    _load_templates()
    # 加载完毕后发射 templates_loaded 信号

## 按需获取模板选项（而非从 Instance 上的 Resource 引用获取）
## 调用方用 instance.available_option_indices + get_template(instance.template_id).options[idx]
func get_template(id: StringName) -> EventTemplate:
    return templates.get(id)

## 事件触发——返回 EventInstance（含已过滤的选项索引列表）
func trigger_event(event_id: StringName, context: Dictionary = {}) -> EventInstance:
    var template := templates.get(event_id)
    if template == null:
        push_error("EventSystem: template '%s' not found" % event_id)
        return null
    var instance := EventInstance.new()
    instance.template_id = event_id
    for i in range(template.options.size()):
        var opt := template.options[i]
        if _all_conditions_met(opt.conditions):
            instance.available_option_indices.append(i)
    instance.all_options_hidden = instance.available_option_indices.is_empty()
    event_triggered.emit(event_id)
    return instance

## 结算选项——返回已结算的结果列表
func resolve_option(instance: EventInstance, option_index: int) -> Array[Dictionary]:
    var template := templates.get(instance.template_id)
    var opt := template.options[option_index]
    instance.selected_option_index = option_index
    var results: Array[Dictionary] = []
    for outcome in opt.outcomes:
        if outcome.chance < 1.0 and randf() >= outcome.chance:
            results.append({"type": outcome.type, "triggered": false})
            continue
        var final_value
        if outcome.use_range:
            final_value = randi_range(outcome.min_value, outcome.max_value)
        else:
            final_value = outcome.value_int
        results.append({
            "type": outcome.type,
            "target": outcome.target,
            "value": final_value,
            "value_str": outcome.value_str,
            "triggered": true
        })
    instance.resolved_outcomes = results
    return results

## 执行结果——通过 GSM 第二层原子方法 + 信号委托
func apply_outcomes(instance: EventInstance) -> void:
    for oc in instance.resolved_outcomes:
        if not oc["triggered"]:
            continue
        match oc["type"]:
            OutcomeType.ADD_RESOURCE:
                GSM.add_resource(oc["target"], oc["value"])     # ADR-0001 第二层
            OutcomeType.ADD_CULTIVATION:
                GSM.add_cultivation(oc["value"])                # ADR-0001 第二层
            OutcomeType.ADD_CARD:
                # ⚠️ 信号委托——不直接调用 CardSystem（Foundation 原则 #3）
                card_reward_requested.emit(oc["target"])        # emit template_id
            OutcomeType.REMOVE_CARD:
                GSM.remove_card_from_collection(oc["value"])    # ADR-0002
            OutcomeType.SET_FLAG:
                set_flag(oc["target"], oc["value_str"])         # 内部→GSM 第二层
            OutcomeType.RESTORE_AP:
                GSM.restore_action_points(oc["value"])
            OutcomeType.GAIN_TALENT:
                GSM.progression.unlock_talent(oc["target"])
            OutcomeType.ADVANCE_CHAPTER:
                GSM.narrative.advance_chapter(oc["target"])
            OutcomeType.TRIGGER_BATTLE:
                pass  # 由探索系统处理（检查 results 中的 TRIGGER_BATTLE）
            OutcomeType.HEAL, OutcomeType.DAMAGE:
                pass  # 战斗上下文中由战斗系统处理
            _:
                push_warning("EventSystem: unhandled outcome type %d" % oc["type"])

    # 结算完毕后发射信号——SaveLoad 监听以判定自动存档
    event_resolved.emit(instance.template_id, instance.selected_option_index, instance.resolved_outcomes)

## story_flags 唯一写入入口
func set_flag(key: String, value: Variant) -> void:
    GSM.set_narrative_flag(key, value)  # ⚠️ ADR-0001 新增的第二层方法

func get_flag(key: String, default: Variant = false) -> Variant:
    return GSM.narrative.story_flags.get(key, default)

## 条件判定
func check_condition(cond: EventCondition) -> bool:
    match cond.type:
        ConditionType.REALM:
            var player_realm := GSM.player.realm
            match cond.operator:
                ConditionOperator.GE: return player_realm >= cond.value_int
                ConditionOperator.EQ: return player_realm == cond.value_int
                ConditionOperator.LT: return player_realm < cond.value_int
        ConditionType.FACTION:
            return GSM.player.faction == cond.value_str
        ConditionType.RESOURCE:
            return GSM.player.resources.get(cond.target, 0) >= cond.value_int
        ConditionType.CARD_OWNED:
            return _has_card(cond.value_str)
        ConditionType.FLAG_SET:
            return get_flag(cond.target) == cond.value_str
        ConditionType.FLAG_NOT_SET:
            return get_flag(cond.target) != cond.value_str
    return false

## 连锁事件——含循环检测
func get_chain_event(instance: EventInstance, option_index: int) -> StringName:
    var template := templates.get(instance.template_id)
    if template == null or template.chain_next == &"":
        return &""
    # 指定选项限制
    if template.chain_on_option >= 0 and template.chain_on_option != option_index:
        return &""
    # 深度限制 + 循环检测
    if instance.chain_depth >= MAX_CHAIN_DEPTH:  # = 3
        push_warning("EventSystem: chain depth exceeded for '%s'" % template.template_id)
        return &""
    return template.chain_next
```

#### ADD_CARD 信号委托链路（Foundation 原则 #3 合规）

```
EventSystem.apply_outcomes() 检测到 OutcomeType.ADD_CARD
  └→ card_reward_requested.emit(template_id: StringName)
       │
       │  ⚠️ EventSystem 不等待结果——不关心 CardSystem 是否在线
       │     Foundation 层只发射信号，不调用 Core 层 API
       │
       ▼
CardSystem._on_card_reward_requested(template_id: StringName)
  ├→ inst = create_instance(template_id)    # 分配 GSM 卡牌 ID
  ├→ dict = serialize_instance(inst)        # 转为序列化字典
  └→ GSM.add_card_to_collection(dict)       # 写入 GSM（ADR-0002 模型 A）
       └→ GSM 发射 card_collection_changed → UI 刷新
```

**信号委托的边界条件：**
- CardSystem 未初始化（模板未加载完成）→ `card_reward_requested` 信号无人监听 → 卡牌静默丢失。缓解：CardSystem 在 `_ready()` 中连接信号时检查其 `templates_loaded` 标志。EventSystem 在事件触发前检查 `CardSystem.templates_loaded`。
- 模板 ID 无效 → `create_instance()` 中 `assert(template_id in templates)` 触发（ADR-0002 契约）→ 开发构建中崩溃，发布构建中记录错误

#### GSM 第二层新增方法（需在 ADR-0001 中补充）

```gdscript
## ⚠️ 新增——供 EventSystem 使用
## 不得由剧情/对话/效果引擎直接调用——它们通过 EventSystem.set_flag() 委托
func set_narrative_flag(flag: StringName, value: Variant) -> void:
    var old = narrative.story_flags.get(flag, null)
    if old == value: return
    narrative.story_flags[flag] = value
    # 发射 batch_updated——SaveLoad 监听以判定自动存档
    var changes := {
        "narrative.story_flags.%s" % flag: {"old": old, "new": value}
    }
    batch_updated.emit(changes)
```

#### 委托写入契约（story_flags）

```
┌──────────────────────────────────────────────────────────────┐
│                 story_flags 写入委托链                        │
│                                                              │
│  EventSystem.set_flag(key, value)           ← 唯一写入入口    │
│    └→ GSM.set_narrative_flag(key, value)    ← GSM 第二层新增  │
│         ├→ 写入 GSM.narrative.story_flags[key]               │
│         └→ 发射 batch_updated（SaveLoad 监听）               │
│                                                              │
│  剧情系统 (NarrativeSystem):                                  │
│    advance_chapter(chapter_id)                               │
│      └→ EventSystem.set_flag("chapter_" + chapter_id, true)  │
│                                                              │
│  对话系统 (DialogueSystem):                                   │
│    DialogueOutcome.set_flag                                  │
│      └→ EventSystem.set_flag(outcome.target, outcome.value)  │
│                                                              │
│  卡牌效果引擎 (CardEffectEngine):                               │
│    SET_FLAG 效果类型                                          │
│      └→ EventSystem.set_flag(effect.flag_key, true)          │
│                                                              │
│  结局分支系统 (EndingSystem):                                  │
│    只读——EventSystem.get_flag(key)——不写入                    │
└──────────────────────────────────────────────────────────────┘
```

#### 模板加载策略

```gdscript
## EventSystem._ready() 中执行
func _load_templates() -> void:
    var dir := DirAccess.open("res://assets/events/")
    if dir == null:
        push_error("EventSystem: events directory not found")
        return

    dir.list_dir_begin()
    var file_name := dir.get_next()
    var count := 0
    while file_name != "":
        if file_name.ends_with(".tres"):
            var path := "res://assets/events/" + file_name
            var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
            if res is EventTemplate:
                templates[res.template_id] = res
                count += 1
            else:
                push_error("EventSystem: '%s' is not an EventTemplate (got %s)" %
                           [path, res.get_class() if res else "null"])
        file_name = dir.get_next()
    dir.list_dir_end()

    print("EventSystem: loaded %d event templates" % count)
    templates_loaded.emit(count)
```

#### 循环检测算法

```gdscript
const MAX_CHAIN_DEPTH: int = 3

## 在 event_resolved 信号的消费者调用 get_chain_event() 之前，
## 调用方负责维护 visited_ids 集合并传递给下一次 trigger_event()
func _check_chain_cycle(instance: EventInstance, next_id: StringName) -> bool:
    # 调用方维护的 _chain_visited_ids 集合
    if _chain_visited_ids.has(next_id):
        push_warning("EventSystem: chain cycle detected at '%s'" % next_id)
        chain_ended.emit(instance.template_id)
        _chain_visited_ids.clear()
        return false  # 截断
    _chain_visited_ids.append(next_id)
    return true

## 调用方的标准模式：
## var visited = []
## var next = event_system.get_chain_event(inst, opt_idx)
## while next != &"":
##     if not _check_chain_cycle(inst, next): break
##     var new_inst = event_system.trigger_event(next)
##     new_inst.chain_depth = inst.chain_depth + 1
##     ...
```

### 版本兼容性策略

事件模板作为 Godot Resource（`.tres`）存储，版本兼容由 Resource 的序列化自然处理：
- **新增字段**：新 `.tres` 文件中新增的 `@export` 字段加载时使用类定义的默认值——无需迁移旧模板
- **字段移除**：保留在类定义中但标记为不再使用——旧 `.tres` 仍可加载
- **枚举扩展**：`OutcomeType` 新增枚举值（如 12→13）兼容——旧模板使用旧枚举值，新模板使用新值

### 信号契约

| 信号 | 签名 | 发射时机 | 消费者 |
|------|------|---------|--------|
| `event_triggered` | `(event_id: StringName)` | `trigger_event()` 成功创建 EventInstance 后 | 探索系统、UI |
| `event_resolved` | `(event_id: StringName, option_idx: int, outcomes: Array[Dictionary])` | `apply_outcomes()` 完成后 | **SaveLoad**（自动存档判定）、探索系统、UI |
| `flag_changed` | `(key: StringName, old: Variant, new: Variant)` | `GSM.set_narrative_flag()` 写入后——由 GSM 的 `batch_updated` 承载 | 剧情/对话/结局系统 |
| `chain_triggered` | `(from_event: StringName, to_event: StringName)` | 连锁事件触发时 | UI（面板内容替换） |
| `chain_ended` | `(final_event_id: StringName)` | 连锁链结束（无 chain_next 或深度截断）时 | 探索系统（恢复地图控制） |
| `card_reward_requested` | `(template_id: StringName)` | ADD_CARD Outcome 执行时 | **CardSystem**（信号委托——唯一解耦点） |
| `templates_loaded` | `(count: int)` | `_load_templates()` 完成后 | CardSystem（检查事件是否可能包含卡牌奖励） |

**`flag_changed` 与 GSM 信号的关系**：`flag_changed` **不是** EventSystem 的独立信号——它通过 GSM 的 `batch_updated` 信号承载。当 `GSM.set_narrative_flag()` 发射 `batch_updated({"narrative.story_flags.{key}": {old, new}})` 时，监听 `batch_updated` 的系统可以通过过滤 `narrative.story_flags.*` 路径检测到 flag 变更。这样避免了"两个信号携带同一变更"的重复。

## 考虑的替代方案

### 替代方案 A：JSON 配置文件（外部加载）
- **描述**：事件模板存储在 JSON 文件中，运行时手动构造 EventTemplate 对象。
- **优点**：Git diff 友好、单一文件管理、可脚本化批量生成
- **缺点**：无类型安全——拼写错误的枚举值到运行时才报错；策划无 Inspector 可视化编辑；嵌套结构在 JSON 中难以阅读
- **拒绝原因**：约 60-100 个模板的 4 层嵌套（模板→选项→条件+结果）在 JSON 中容易出错。Godot Resource 的 `enum` 下拉菜单提供编译时拼写检查——这是 JSON 无法替代的安全网

### 替代方案 B：Outcome 类型化子类（每个 OutcomeType 一个 Resource 子类）
- **描述**：`ResourceOutcome`（resource_amount: int）、`CardOutcome`（card_template_id: StringName）等 12 个子类
- **优点**：编译时类型安全——每个子类仅有相关字段；Inspector 完美适配（不会出现不相关字段）
- **缺点**：12 个 `class_name` 注册 + 12 个 `.gd` 文件 = 类爆炸；Template 中的 `Array[EventOutcome]` 必须存储不同子类——基类数组仍丢失子类类型信息
- **拒绝原因**：对于 60-100 个模板的规模，12 个子类带来的维护成本 > 收益。轻量方案（String+int+use_range flag）实现了足够的可用性，且不牺牲 Inspector 可编辑性

### 替代方案 C：直接依赖——放宽 Foundation 原则 #3
- **描述**：EventSystem 直接调用 `CardSystem.create_instance()` + `serialize_instance()`——通过 Autoload 树解析（`get_node("/root/CardSystem")`）
- **优点**：实现简单——同步调用，无需信号编排；不易出现 "信号无人监听" 的静默丢失
- **缺点**：违反 Foundation 层原则 #3——EventSystem（Foundation）依赖 CardSystem（Core）。如果 CardSystem 未加载或在未来被移除，EventSystem 静默失败
- **拒绝原因**：信号委托在代码复杂度和架构原则合规之间取得了最佳平衡。`card_reward_requested` 信号是单向的、fire-and-forget 的——EventSystem 不等待结果。如果 CardSystem 未就绪（`templates_loaded == false`），EventSystem 可在触发事件前检查并拒绝

## 后果

### 积极的
- **Foundation 原则 #3 合规**：EventSystem 不直接依赖任何 Core/Feature 层系统——ADD_CARD 通过信号委托解耦
- **类型安全**：所有枚举用 `enum` 定义——Inspector 下拉菜单防止拼写错误
- **Inspector 可编辑**：所有 `@export` 字段使用 Inspector 原生支持的类型（enum/String/int/float/bool）——不使用 `Variant`
- **min/max 无歧义**：`use_range: bool` 显式标志区分"精确值"和"随机范围"——0 值不再引起歧义
- **story_flags 写入路径合规**：通过新增 GSM 第二层方法 `set_narrative_flag()`——不违反 ADR-0001 的禁止模式（通用 `set()`）
- **Resource 共享安全**：EventInstance 不持有 Resource 引用——仅存储 template_id 和选项索引。与 ADR-0002 的 Template/Instance 分离模式一致
- **信号契约完整**：7 个公开信号覆盖所有事件生命周期——SaveLoad 通过 `event_resolved` 判定自动存档，探索系统通过 `chain_ended` 恢复控制
- **Outcome 枚举为权威来源**：为 ADR-0009（卡牌效果引擎）提供统一的 12 种类型词汇表（OQ-05 解决方案）
- **连锁安全**：MAX_CHAIN_DEPTH=3 硬限制 + visited_ids 循环检测 + 非静默日志

### 消极的
- **信号委托增加异步复杂度**：ADD_CARD 是 fire-and-forget 信号——EventSystem 无法知道卡牌是否成功添加。CardSystem 错误处理独立于事件流
- **`.tres` 文件碎片化**：60-100 个单独文件 vs 单个 JSON——Git 管理略显不便
- **`String` 值运行时解析**：`value_str` 和 `value_int` 的正确使用依赖策划在 Inspector 中填入正确的字段——填错字段（如在 ADD_CULTIVATION 的 value_str 填数字）不会在编辑时被检测
- **嵌套 Resource 编辑体验**：4 层嵌套（Template→Option→Condition/Outcome）在 Inspector 中可能需要大量滚动（缓解：`@export_group` 组织字段）
- **需同步更新 ADR-0001**：新增 `set_narrative_flag()` 方法——在接受 ADR-0004 之前必须补充到 ADR-0001 的第二层 API

### 风险
- **`card_reward_requested` 信号无人监听**：CardSystem 未连接信号 → 卡牌奖励静默丢失。缓解：EventSystem 在 `trigger_event()` 前检查 `CardSystem.templates_loaded`——如果模板未加载完成则拒绝触发含 ADD_CARD 的事件。CardSystem 在其 `_ready()` 中连接 `card_reward_requested`
- **模板 .tres 文件路径变更**：策划重命名 .tres 文件 → `ResourceLoader.load()` 返回 null → `trigger_event()` 返回 null。缓解：加载时验证 `template_id` 字段与 `templates` 字典中的键一致——不一致的记录警告
- **`chain_next` 指向不存在的模板 ID**：模板 A 的 `chain_next = "event_xyz"` 但 "event_xyz" 不在模板注册表中。缓解：`_load_templates()` 完成后全量验证 `chain_next` 引用——所有 `chain_next` 值必须在 `templates.keys()` 中存在或为空
- **连锁事件循环**：A→B→A。缓解：visited_ids 集合 + 深度截断时 `push_warning`（非静默）
- **GSM.add_resource() 返回 false**：资源类型不存在或溢出。缓解：`apply_outcomes()` 检查返回值并记录错误——事件结果已被 UI 展示，实际执行失败需在 HUD 中提示

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| event-system.md | §事件定义结构 §1：EventTemplate + Option + Condition + Outcome | 确立 Godot Resource 类——EventTemplate、EventOption、EventCondition、EventOutcome——所有字段 Inspector 可编辑 |
| event-system.md | §事件类型大全 §2：6 种事件类型 | 确立 EventType 枚举 + is_hidden 隐藏奇遇规则 |
| event-system.md | §事件触发流程 §3：9 步 | 确立 trigger_event() → resolve_option() → apply_outcomes() → get_chain_event() |
| event-system.md | §概率结果结算 §4：chance + [min, max] | 确立 chance + use_range + min/max 显式标志——消除 0 值歧义 |
| event-system.md | §连锁事件 §5：最多 3 层 | 确立 MAX_CHAIN_DEPTH=3 + visited_ids 循环检测算法 |
| event-system.md | §事件条件分支 §6：realm/faction/resource/card_owned | 确立 check_condition() + 6 种 ConditionType——含 FLAG_SET/FLAG_NOT_SET |
| event-system.md | §事件权重与随机选择 §7 | 确立 select_event() 加权随机 |
| event-system.md | §事件结果执行器 §8：12 种 Outcome 类型 | 确立 apply_outcomes() 中每种类型的执行映射——通过 GSM 第二层原子方法或信号委托 |
| event-system.md | §斜月三星洞 §9：每图 1 次 + 固定位置 | 确立 is_hidden 标记 + min_realm 过滤 |
| event-system.md | §待解决问题 #1：模板存储格式 | 确立 Godot Resource (.tres) 为存储格式 |
| architecture.md | §事件系统 — story_flags 所有权 | 确立 EventSystem 为唯一写入者——GSM.set_narrative_flag() 为写入方法 |
| architecture.md | §初始化顺序 T+0：EventSystem Autoload #5 | 确立 Autoload 顺序——在 GSM + SaveLoad 之后，功能系统之前 |
| architecture.md | OQ-05：Outcome 类型统一 | 确立 OutcomeType 枚举（12 种）为权威来源——ADR-0009 必须扩展非复制 |

## 性能影响
- **CPU**：`trigger_event()` 约 0.1ms（条件过滤——最多 12 次 O(1) 字典读取）。`resolve_option()` 约 0.05ms（1-3 outcome × 随机数生成）。均非每帧操作——每局约 20-40 次事件交互
- **内存**：60-100 个 EventTemplate Resource 约 100-300KB（每个 2-5KB）。EventInstance RefCounted 约 200B（选项索引列表 + 元数据），结算后释放
- **加载时间**：`_load_templates()` 同步加载 <150ms——与 CardSystem 模板加载同时进行（Autoload #4 和 #5 的 `_ready()` 按序执行），总启动时间不叠加。若增长到 200+ 模板 → 改用 `load_threaded_request()` 分批
- **网络**：不适用

## 迁移计划
无现有代码需迁移。

事件模板 .tres 文件目录结构：
```
assets/events/
├── ling_mai_caijue/      # 灵脉采掘 ~10-15
├── fang_shi_jiaoyi/      # 坊市交易 ~10-15
├── dong_fu_qiyu/         # 洞府奇遇 ~10-15
├── sha_ren_duo_bao/      # 杀人夺宝 ~10-15
├── lian_dan_lian_qi/     # 炼丹/炼器台 ~10-15
├── xie_yue_san_xing/     # 斜月三星洞 ~5-10
└── chain/                # 连锁子事件 ~10-20
```

策划工作流：在 Godot 编辑器中右键 → New Resource → EventTemplate → 填充字段 → 保存到对应目录。`_load_templates()` 自动在下次启动时加载新模板。

## 需同步更新的 ADR
- **ADR-0001**：第 2 层新增 `GSM.set_narrative_flag(flag: StringName, value: Variant) → void`——更新「第二层：原子写入操作」部分
- **ADR-0001**：注册表新增 `set_narrative_flag` 接口契约

## 验证标准
- 通过 GUT：`EventSystem` 测试套件覆盖：
  - `_load_templates()` 正确加载所有 .tres 文件；`chain_next` 引用完整性验证通过
  - `trigger_event()` 返回 EventInstance——`available_option_indices` 已过滤不满足条件的选项索引
  - 所有条件不满足 → `all_options_hidden == true`
  - `check_condition()` —— `REALM GE 3` 对 realm=2 返回 false，对 realm=3 返回 true
  - `check_condition()` —— `FLAG_SET` / `FLAG_NOT_SET` 正确读取 story_flags
  - `resolve_option()` —— chance=1.0 必定触发；chance=0.0 永不触发
  - `resolve_option()` —— use_range=true, min=50, max=150 → 100 次执行均在 [50, 150]
  - `apply_outcomes()` —— ADD_RESOURCE → `GSM.add_resource()` 被调用
  - `apply_outcomes()` —— ADD_CARD → `card_reward_requested` 信号发射且携带正确的 template_id
  - `apply_outcomes()` —— SET_FLAG → `GSM.set_narrative_flag()` 被调用
  - `set_flag()` 重复写入相同值 → 不发射 batch_updated
  - `select_event()` —— 1000 次执行的加权随机分布符合预期比例（卡方检验）
  - 连锁事件 —— chain_depth=3 时截断并 push_warning
  - 连锁事件 —— 循环 A→B→A 在第 3 次触发时截断
  - EventInstance 不持有任何 Resource 引用——`available_option_indices` 为 int 数组
  - `_load_templates()` 验证所有 `chain_next` 引用指向存在的模板 ID
- 通过集成测试：
  - CardSystem 监听 `card_reward_requested` → 收到信号后正确调用 `create_instance()` + `serialize_instance()` + `GSM.add_card_to_collection()`
  - SaveLoad 监听 `event_resolved` → 触发自动存档判定

## 相关决策
- ADR-0001（GSM——需新增 `set_narrative_flag()`；条件判定通过第一层；结果执行通过第二层 `add_resource()`/`add_cultivation()`）
- ADR-0002（卡牌数据模型——ADD_CARD 通过 `card_reward_requested` 信号委托给 CardSystem）
- ADR-0003（存档/读档——story_flags 持久化；`event_resolved` 触发自动存档）
- ADR-0006（探索系统——事件节点分配 + 调用 EventSystem.trigger_event()）
- ADR-0007（战斗系统——trigger_battle Outcome 加载战斗场景）
- ADR-0008（卡牌效果引擎——SET_FLAG 效果 → 委托 EventSystem.set_flag()；OutcomeType 枚举为共享词汇表权威来源）
