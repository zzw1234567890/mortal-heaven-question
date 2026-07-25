# ADR-0002：卡牌数据模型 — Template/Instance 分离 + Resource 序列化

## 状态
Proposed

## 日期
2026-07-24

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Core / Card System |
| **知识风险** | HIGH（Godot 4.6 在 LLM 训练截止 2025-05 之后） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/breaking-changes.md` |
| **使用的截止后 API** | `ResourceLoader.load_threaded_request()` (4.x 稳定，4.5+ 优化)、`Array[StringName]` 类型化集合 (4.4+)、`duplicate_deep()` (4.5+ 深拷贝——仅用于 Instance 拷贝，不用于模板) |
| **需要验证** | 222 个 .tres 文件的 `load_threaded_request()` 分批加载在目标硬件上的启动时间（预计 <2s）；4.6 双焦点系统不影响 CardSystem（纯数据系统，非 UI） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——CardInstance 的 ID 由 GSM 分配；GSM 通过 `collection.owned_cards` 持有实例；CardSystem 调用 `GSM.enable_validation(db)` 在模板加载完成后启用卡牌校验） |
| **启用** | ADR-0006（卡牌效果引擎——消费 CardTemplate 的效果定义）、ADR-0008（战斗系统——读取角色属性、费用查询）、ADR-0011（状态效果系统——消费模板的状态效果配置）、ADR-0003（事件系统——story_flags 触发卡牌获得/失去） |
| **阻塞** | 所有涉及卡牌数据的史诗（战斗 Epic、卡组编辑 Epic、绑定 Epic、阵法 Epic、炼丹/铭刻 Epic、AI Epic）——在这些系统可以编码前必须接受本 ADR |
| **排序说明** | 在 ADR-0001 之后、ADR-0006（卡牌效果引擎）之前被接受。Core 层第一个 ADR（CardSystem 在 architecture.md 层映射中属于 CORE 层，在 Foundation 层 GSM 就绪后构建） |

> **跨 ADR 契约说明**：本 ADR 依赖 ADR-0001 中的两个 API——`GSM.allocate_card_id() → int` 和 `GSM.add_card_to_collection(inst_dict: Dictionary) → void`。这两个 API 目前**未在 ADR-0001 中显式列出**——在接受本 ADR 之前需补充到 ADR-0001 的第二层原子操作中。详见下文「GSM 集成合约」。

## 上下文

### 问题陈述
游戏有 222 张卡牌，分为 6 种类型（角色、功法、法宝、阵法、丹药、符箓）。每张卡牌有固定的模板数据——名称、费用、效果类型、数值、阵营标签、稀有度——以及运行时可变的实例数据——等级、铭刻、突破层数、绑定目标、获得来源。

Godot 4.6 的核心约束：**Resource 是引用计数共享的**。若 CardTemplate 为 Resource 且允许运行时写入，同一模板被两张同名卡实例共享时，写入一张会导致另一张也变化——这违反了"同名卡的不同实例等级独立"的需求（card-system.md §验收标准："实例A升级到3级，实例B保持1级"）。

同时，模板数据应可通过 Godot 编辑器可视化编辑（便于策划配置 222 张卡牌），实例数据必须能在存档时序列化为轻量 Dictionary。

### 约束
- **Godot Resource 语义**：Resource 是共享引用——对 Resource 字段的写入立即对所有持有者可见。模板必须保持只读。
- **编辑器可检查性**：222 张卡牌的模板数据必须能在 Godot Inspector 中直接查看/编辑——策划需要可视化配置工具
- **实例独立性**：同名卡的不同实例（2 张「枯木逢春诀」）必须有独立的等级、铭刻和绑定状态
- **内存预算**：完整运行时状态 <1MB（222 个模板 + 运行时实例）。每个模板约 1-2KB → 总共约 300-400KB。每个实例约 128B → 平均 40 张实例约 5KB
- **启动性能**：模板加载不得阻塞主线程超过 200ms 的连续尖峰
- **存档兼容性**：实例数据必须可序列化为平坦 Dictionary，以兼容 GSM 的 `serialize()` / `deserialize()` 接口（ADR-0001）

### 需求
- 6 种卡牌类型的模板定义（角色、功法、法宝、阵法、丹药、符箓），每种有类型专属字段
- 同名卡多实例支持——每张同名卡独立持有等级、铭刻、绑定状态
- 222 个模板文件可被所有实例共享引用——零拷贝
- CardSystem 作为模板注册表和实例工厂
- 与 GSM 集成——实例 ID 分配、收藏存储、校验启用

## 决策

**卡牌数据模型采用 Template（Resource, 只读）/ Instance（RefCounted, 可变）两层分离架构。**

### CardTemplate（模板层）—— `Resource`, `.tres` 文件

```
class_name CardTemplate
extends Resource

## 模板唯一标识（如 "char_lin_yuan_base_01"）
@export var card_id: StringName

## 卡牌名称
@export var name: String

## 卡牌类型
@export var type: CardType  # enum: CHARACTER / TECHNIQUE / ARTIFACT / FORMATION / PILL / TALISMAN

## 稀有度
@export var rarity: Rarity  # enum: WHITE / BLUE / PURPLE / GOLD / DARK_GOLD

## 灵力消耗
@export var cost: int

## 阵营标签（最多 3 个）
@export var faction_tags: Array[StringName] = []

## 规则描述文本
@export var description: String

## 背景叙述文本
@export var flavor_text: String

# --- 类型专属字段（按 type 条件可空）---

## 角色卡：基础属性
@export var base_hp: int = 0
@export var base_attack: int = 0
@export var innate_skill: StringName = ""       # 原生天赋效果 ID
@export var technique_slots: int = 3
@export var artifact_slots: int = 3

## 功法/法宝卡：效果数据
@export var effect_type: StringName = ""         # 引用 card-effect-engine 的效果类型
@export var effect_value: int = 0
@export var native_owner: StringName = ""        # 本命角色 card_id 前缀

## 功法专属
@export var stack_limit: int = 3                  # 同名叠加张数上限
@export var stack_multiplier: float = 1.5         # 每层叠加乘数

## 法宝专属
@export var trigger_condition: StringName = ""    # 触发条件
@export var cooldown: int = 0

## 阵法卡
@export var faction_requirement: StringName = ""   # 所需阵营
@export var required_count: int = 0                # 所需阵营角色数
@export var aura_effect: StringName = ""           # 光环效果 ID

## 丹药/符箓卡
@export var duration_turns: int = 0                # 持续回合数（丹药）
@export var target_type: StringName = ""           # 目标类型（符箓）
@export var base_fail_chance: float = 0.0          # 基础失败率（符箓）
```

**存储**：`assets/cards/templates/[card_id].tres`——每张卡一个文件，由策划在编辑器中管理。

> **引擎验证（2026-07-24）**：Godot 专家确认 Resource + @export + .tres 是 Godot 4.6 的惯用数据驱动模式。CardTemplate Resource、CardInstance RefCounted、StringName 键类型、Array[StringName] 类型化集合——全部对 4.6 安全且惯用。无弃用 API。ResourceLoader.load_threaded_request() 不支持通配符——CardSystem 必须使用 DirAccess 枚举文件列表（见下文加载生命周期）。

**规则——模板只读**：任何系统不得在运行时写入 `CardTemplate` 字段。CardSystem 可选性地添加 `_validate_template_readonly()` 调试断言。

### CardInstance（实例层）—— `RefCounted`, 运行时分配

```
class_name CardInstance
extends RefCounted

## 全局唯一实例 ID——由 GSM 单调递增分配
var card_instance_id: int = 0

## 指向模板
var template_id: StringName = ""

## 实例成长状态（独立于同模板的其他实例）
var level: int = 1
var inscriptions: Array = []         # Array[Dictionary] — 0-3 条铭刻副属性
var breakthrough_layers: int = 0     # 0-3 层突破

## 绑定状态（功法/法宝卡）
var binding_target_id: StringName = ""  # 绑定的角色 instance_id

## 获得来源追踪（实现支柱 3「机缘巧合，意外之喜」——每张卡的故事）
var acquired_chapter: int = 0
var acquired_event_id: StringName = ""
var acquired_method: int = 0        # enum: DROP / SHOP / EVENT / CRAFT / TRIBULATION
```

**实例 ID 分配**：CardInstance 的 `card_instance_id` 由 GSM 分配单调递增整数。CardSystem 调用 `GSM.allocate_card_id() → int`，GSM 内部维护 `_next_card_id` 计数器。分配后不可更改。此设计遵循 ADR-0001 的"GSM 是真理的单一来源"原则。

**与模板的关系**：Instance 持有 `template_id: StringName` 而非直接的 Resource 引用。模板查找通过 `CardSystem.get_template(instance.template_id)` 进行。这种间接方式避免了两层引用的耦合——Instance 可以在没有加载模板的情况下被序列化/反序列化（存档时只存 `template_id` 字符串）。

### CardSystem Autoload —— 模板注册表 + 实例工厂

```
## CardSystem 公共 API

## 模板查询
func get_template(id: StringName) -> CardTemplate:
    return templates.get(id, null)

## 按类型/稀有度筛选
func get_templates_by_type(type: CardType) -> Array[CardTemplate]:
    # O(n) 遍历——非热路径，仅在收藏浏览/战利品生成时调用

## 实例工厂——创建 CardInstance 并分配 GSM ID
func create_instance(template_id: StringName) -> CardInstance:
    assert(template_id in templates, "Unknown template: %s" % template_id)
    var inst = CardInstance.new()
    inst.card_instance_id = GSM.allocate_card_id()
    inst.template_id = template_id
    inst.acquired_chapter = GSM.narrative.current_chapter  # 当前章节
    return inst

## 实例序列化——Dictionary 格式
func serialize_instance(inst: CardInstance) -> Dictionary:
    return {
        "card_instance_id": inst.card_instance_id,
        "template_id": inst.template_id,
        "level": inst.level,
        "inscriptions": inst.inscriptions,
        "breakthrough_layers": inst.breakthrough_layers,
        "binding_target_id": inst.binding_target_id,
        "acquired_chapter": inst.acquired_chapter,
        "acquired_event_id": inst.acquired_event_id,
        "acquired_method": inst.acquired_method,
    }

## 实例反序列化
func deserialize_instance(data: Dictionary) -> CardInstance:
    var inst = CardInstance.new()
    inst.card_instance_id = data["card_instance_id"]
    inst.template_id = StringName(data["template_id"])  # 显式转换——存档 JSON 反序列化产生 String，非 StringName
    inst.level = data["level"]
    inst.inscriptions = data["inscriptions"]
    inst.breakthrough_layers = data["breakthrough_layers"]
    inst.binding_target_id = data.get("binding_target_id", "")
    inst.acquired_chapter = data.get("acquired_chapter", 0)
    inst.acquired_event_id = data.get("acquired_event_id", "")
    inst.acquired_method = data.get("acquired_method", 0)
    return inst
```

### 模板加载生命周期

```
T+0: CardSystem._ready()
  → 初始化 templates = {} 空字典
  → DirAccess.open("res://assets/cards/templates/") 枚举 .tres 文件
  → 对每个文件调用 ResourceLoader.load_threaded_request(path)
  → 记录待加载总数: _pending_loads = total_count

T+1..T+N: CardSystem._process(delta) —— 分批处理
  → 每帧查询 load_threaded_get_status() 最多 10 个
  → 状态为 THREAD_LOAD_LOADED → load_threaded_get() 获取模板
  → 存入 templates[res.card_id] = res
  → 全部完成后: set_process(false)
  → 记录耗时: print("CardSystem: %d templates loaded in %d ms" % [total, elapsed])

T+N: 全部加载完成
  → CardSystem 发射 signals.templates_loaded
  → GSM 收到信号后调用 GSM.enable_validation(db=CardSystem.templates)
  → 从此刻起，add_card_to_collection() 校验 template_id 是否在注册表中存在
```

> **API 注意事项（引擎验证）**：`ResourceLoader.load_threaded_request()` **不支持通配符**——必须先用 `DirAccess` 枚举 .tres 文件名，然后对每个文件单独调用 `load_threaded_request()`。每个文件的完整语法：
> ```gdscript
> var dir := DirAccess.open("res://assets/cards/templates/")
> dir.list_dir_begin()
> var file_name := dir.get_next()
> while file_name != "":
>     if file_name.ends_with(".tres"):
>         ResourceLoader.load_threaded_request("res://assets/cards/templates/" + file_name)
>     file_name = dir.get_next()
> dir.list_dir_end()
> ```

**分批加载策略**：每帧处理 10 个模板 = 23 帧 ≈ 380ms @ 60fps。实际 I/O 加载在后台线程完成（`load_threaded_request` 是异步的），主线程仅在检查完成状态时开销——检查 <0.1ms/帧。总启动影响可忽略。

> **简单性说明（引擎验证）**：222 个 .tres 文件总计约 100KB。同步 `load()` 在所有平台上的耗时远低于 100ms——异步加载相比同步加载的额外复杂度（文件枚举、进度跟踪、每帧轮询）带来的性能收益可忽略。ADRD 仍采用异步方案以满足架构需求"不阻塞主线程 >200ms"，但实现时可降级为 `await` 协程内同步加载（每 50 个文件 yield 一帧），代码量约为异步方案的 1/4。两种方案均被 ADR 所涵盖。

### 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                    CardSystem (Autoload)                     │
│                                                              │
│  ┌─ 模板注册表 ───────────────────────────────────────┐      │
│  │ templates: Dictionary[StringName, CardTemplate]      │      │
│  │ get_template(id) → CardTemplate     ← O(1) 查询     │      │
│  │ get_templates_by_type(type) → Array  ← O(n) 筛选    │      │
│  │                                                      │      │
│  │  assets/cards/templates/char_lin_yuan_base_01.tres   │      │
│  │  assets/cards/templates/tech_qing_yun_sword.tres     │      │
│  │  ... (222 个 .tres 文件, 每个 1-2KB)                 │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                              │
│  ┌─ 实例工厂 ─────────────────────────────────────────┐      │
│  │ create_instance(template_id) → CardInstance          │      │
│  │   ├→ GSM.allocate_card_id()  # 分配全局唯一 ID      │      │
│  │   ├→ inst.template_id = template_id  # 持有引用     │      │
│  │   └→ inst.acquired_chapter = GSM.narrative.chapter  │      │
│  │                                                      │      │
│  │ serialize_instance(inst) → Dictionary                │      │
│  │ deserialize_instance(dict) → CardInstance            │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                              │
│  ┌─ 加载生命周期 ──────────────────────────────────────┐     │
│  │ _ready() → load_threaded_request(222 个 .tres)       │     │
│  │ _process() → 每帧 10 个 load_threaded_get()          │     │
│  │   完成 → signals.templates_loaded.emit()             │     │
│  └──────────────────────────────────────────────────────┘      │
│                                                              │
│  信号: templates_loaded                                      │
└──────────────────────────────────────────────────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────┐    ┌──────────────────────┐
│  CardTemplate   │    │   CardInstance        │
│  (Resource)     │    │   (RefCounted)        │
│  .tres 文件     │    │   运行时分配           │
│                 │    │                      │
│  不可变         │    │  card_instance_id: int│
│  共享引用       │    │  template_id: SName   │
│  所有实例共用   │    │  level: int           │
│  222 个文件     │    │  inscriptions: Array  │
│                 │    │  breakthrough: int    │
│  由策划编辑     │    │  binding_target_id    │
│                 │    │  acquired_* 追踪      │
└─────────────────┘    └──────────────────────┘
```

### GSM 集成合约

**序列化模型——模型 A（数据容器）**：GSM 持有序列化的 Dictionary，而非 CardInstance 对象。当需要操作 CardInstance 时，调用者先通过 CardSystem 反序列化。

```
## 获得卡牌时（运行中）
inst = CardSystem.create_instance(template_id)
dict = CardSystem.serialize_instance(inst)
GSM.add_card_to_collection(dict)

## 存档时
GSM.serialize() → {..., "collection": {"owned_cards": Array[Dictionary]}}

## 读档时
GSM.deserialize(data) → 恢复 owned_cards 为 Array[Dictionary]
CardSystem.reconstitute_instances(GSM.collection.owned_cards) → Array[CardInstance]
# 每个 Dictionary 调用 CardSystem.deserialize_instance(dict)
```

**理由**：模型 A 中 GSM 只存数据——无需持有对 CardInstance 对象的引用。这保持了 GSM 作为纯数据容器的角色（ADR-0001 原则），并将 CardInstance 对象管理集中在 CardSystem 中。在序列化时不需额外的对象→字典转换——GSM 自身就能序列化其所持有的数据。

**GSM API（需在 ADR-0001 中补充定义）**：

```
## GSM 需暴露给 CardSystem 的接口

GSM.allocate_card_id()                              → int
  # 返回 _next_card_id 的当前值，然后单调递增
  # 分配后不可收回

GSM.add_card_to_collection(inst_dict: Dictionary)  → void
  # inst_dict 由 CardSystem.serialize_instance() 生成
  # 在 validation_enabled == false 时拒绝写入并记录警告

GSM.remove_card_from_collection(card_instance_id: int) → bool
  # 按 card_instance_id 从 owned_cards 中删除
  # 未找到时返回 false

GSM.enable_validation(db: Dictionary[StringName, CardTemplate]) → void
  # 设置在 add_card_to_collection 时校验 template_id 存在于 db 中
```

> **⚠ ADR-0001 契约缺口**：截至本 ADR 编写时（2026-07-24），`allocate_card_id()` 和 `add_card_to_collection(inst_dict)` 的正式签名**未在 ADR-0001 的第二层原子操作列表中列出**。在接受本 ADR 之前，应补充到 ADR-0001 中。本 ADR 中定义的签名是该接口的权威规范。

**访问 Instance 的路径**（调用者视角）：

```
## 读取卡牌实例
owned_cards_dicts = GSM.collection.owned_cards                 # Array[Dictionary]
instances = CardSystem.reconstitute_instances(owned_cards_dicts)  # Array[CardInstance]

## 读取单张卡的模板
inst = instances[0]
template = CardSystem.get_template(inst.template_id)  # CardTemplate Resource
card_name = template.name                              # String
```

## 启动合约
1. CardSystem 在 GSM._ready() 之后 _ready()（Autoload 顺序：#1=GSM, #2=CardSystem）
2. CardSystem 加载完成 → 发射 templates_loaded
3. GSM 收到信号 → enable_validation(db=CardSystem.templates)
4. 在 enable_validation() 之前，GSM 拒绝所有 add_card_to_collection() 调用

## 考虑的替代方案

### 替代方案 A：单一 CardData Resource + 获得时 deep-copy
- **描述**：一张 CardData Resource 同时包含模板和可变数据。获得卡牌时调用 `duplicate_deep()` 创建独立副本。
- **优点**：概念简单——一张卡即一个 Resource 文件。无需分离模板/实例。
- **缺点**：222 个 `duplicate_deep()` 拷贝在运行时占用大量内存（每个 RoleCard 包含阵营标签数组、绑定数据等嵌套结构——深拷贝约 3-5KB 而非 128B）。玩家收藏 40 张卡时内存占用本应为 5KB（Instance），却用了 200KB（拷贝的 Resource）。且 Resource 的 `duplicate_deep()` 在 Godot 4.5 中刚稳定——存在边缘情况行为差异的风险。
- **拒绝原因**：内存浪费 + 模板数据本就不该拷贝。实例仅需持有 template_id 来引用共享模板——这是引用而非拷贝的经典用例。且 Resource 深拷贝破坏了模板的"来源可检查性"——无法区分"这是一张原始模板"还是"这是一张运行中被修改的卡"。

### 替代方案 B：纯 Dictionary 数据驱动——完全绕过 Resource 系统
- **描述**：所有卡牌数据存储在 JSON 文件中（`cards.json`），运行时加载为 `Dictionary`。模板和实例均为字典。
- **优点**：完全灵活——无 Godot Resource 系统限制。JSON 易于版本控制和批量编辑（脚本即可生成 222 张卡）。跨引擎可移植。
- **缺点**：失去编辑器可视化——策划无法在 Godot Inspector 中查看/编辑卡牌数据。失去 @export 类型安全——字段错误只在运行时暴露。需自定义导入管线——额外开发工作量。CardInstance 仍需 RefCounted 包装以支持方法逻辑。
- **拒绝原因**：Godot 的 Resource 系统正是为"策划可编辑的数据资产"设计的。222 张卡牌在 Inspector 中可点击查看是强制性的工作流需求——策划不应需要理解 JSON。且 .tres 文件也支持版本控制（人类可读的键值对文本格式）。

### 替代方案 C：Template 与 Instance 合并为单一 Resource——通过只读约束保护
- **描述**：单一 `CardData` Resource，通过 convention 约束"运行时不得修改 @export 字段"来保护共享模板。
- **优点**：最简——无需维护两个类的 API。
- **缺点**：Convention 不可强制执行。一个无意的字段写入（`card.cost = 0`）就会污染所有同名卡实例——且很难追踪源头。依赖所有开发者和未来的 AI 编码代理来记住这条规则。没有编译器或运行时防护。
- **拒绝原因**：失败模式是静默的数据损坏，而非明确的错误。Template/Instance 的类型系统分离（Resource vs RefCounted）以编译时的界限强制执行"模板只读"——远比 convention 安全。

## 后果

### 积极的
- **编译时保证模板不可变**：Resource（模板）vs RefCounted（实例）的类型区分使得运行时修改模板成为不可能——没有 `@export var cost` 可被意外赋值。超越了替代方案 C 的 convention 约束。
- **模板在编辑器中可检查**：策划可双击 `assets/cards/templates/char_lin_yuan_base_01.tres` 在 Godot Inspector 中编辑字段。Godot 原生编辑器支持 Resource 的可视化编辑。
- **实例内存效率高**：CardInstance 仅包含 ~10 个可变字段（约 128B），而非拷贝整个模板（3-5KB）。40 张卡的收藏占用约 5KB vs 替代方案 A 的 200KB。
- **存档简单**：`serialize_instance()` → 平坦 Dictionary——与 GSM 的 `serialize()` 无缝集成。存档中只存 `template_id` 字符串，无需序列化整个模板。
- **模板与实例之间的清晰契约**：下游系统接收 CardInstance 时，通过 `CardSystem.get_template(inst.template_id)` 获取模板数据。接口明确——没有歧义。

### 消极的
- **数据访问需要一次间接查找**：要获取一张卡的费用（模板字段），系统调用 `CardSystem.get_template(inst.template_id).cost`——比直接 `inst.cost` 多一次字典查找。此开销对 2D 卡牌游戏可忽略不计（O(1) 字典查找 <1μs）。在热路径（战斗结算）中，系统可以缓存模板引用。
- **两层 API 增加了认知负载**：开发者需区分"这是模板属性（查找）"和"这是实例属性（直接访问）"。缓解：命名规范——模板属性通过 `get_template()` 访问，实例属性直接访问。CardSystem 可提供便利方法 `get_cost(instance)` 简化常见操作。
- **Resource 编辑器依赖 Godot**：模板在文本编辑器中不可编辑（.tres 虽是人类可读的，但手动编辑容易出错）。缓解：这正是策划预期的编辑器工作流。

### 风险
- **222 个 .tres 文件的加载失败**：`load_threaded_request()` 返回错误——文件缺失/损坏。缓解：CardSystem 对加载失败的模板记录错误并跳过，允许游戏无此张卡牌继续运行。缺失模板的 instance 在尝试使用时显示占位符卡牌+"模板缺失"提示。
- **template_id 与文件名不同步**：策划复制 .tres 文件后忘记更新 `card_id` 字段——导致注册表中有两个不同文件名但相同 card_id 的模板。缓解：CardSystem 在加载时检测重复 `card_id`，以 EDITOR 构建中止并报错，RELEASE 构建以第一个为准并记录警告。
- **CardSystem._ready() 在 GSM 之前执行**：Godot Autoload 顺序如果错误（CardSystem 在 GSM 之前），`create_instance()` 调用 `GSM.allocate_card_id()` 将导致空引用。缓解：CardSystem 在 Project Settings → Autoload 中列在 GSM 之后。启动时 `_ready()` 断言 `GSM != null && GSM._initialized`。这是 ADR-0001 中已识别的 Autoload 顺序风险的具体实例。
- **CardInstance ID 溢出**：32-bit 整数——上限约为 21 亿。假设每局游戏分配 200 个实例，玩家打 1000 万局才会溢出。实际不构成威胁。若需要，可升级为 64-bit。
- **StringName 反序列化隐式转换**：从存档 JSON 反序列化时，`template_id` 以 String 形式返回，但 `CardSystem.templates` 字典以 StringName 为键。Godot 4.x 使用值比较（`hash()` + `==`），使得 `templates.get(String(template_id))` 可以正确工作。为提高可见性，`deserialize_instance()` 执行显式 `StringName(data["template_id"])` 转换。缓解：GUT 测试验证 `templates.has(StringName(deserialized_id))` 返回 true。风险：Godot 未来版本可能改变 Dictionary 键比较语义。

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| card-system.md | §核心规则 #1 卡牌数据模型——Template/Instance 分离的两层架构 | 确立 CardTemplate(Resource) + CardInstance(RefCounted) 分离，模板只读，实例持有独立的状态 |
| card-system.md | §详细设计 #1 CardTemplate 共有字段（card_id, name, type, rarity, cost, faction_tags, description, flavor_text）| 定义 CardTemplate Resource 的 @export 字段规范 |
| card-system.md | §详细设计 #1 CardInstance 附加字段（card_instance_id, template_id, level, inscriptions, breakthrough_layers, binding_target_id, acquired_*）| 定义 CardInstance RefCounted 的可变字段规范 |
| card-system.md | §详细设计 #1 类型的专属字段（角色: base_hp/base_attack、功法: stack_limit/multiplier、法宝: trigger_condition 等）| 作为 @export 字段纳入 CardTemplate，按 type 条件可空 |
| card-system.md | §验收标准——实例独立性：实例 A 升级到 3 级不应影响实例 B | Template/Instance 分离在编译时强制执行此约束——实例只持有 template_id 引用，不持有模板数据的副本 |
| card-system.md | OQ-04——222 个模板文件的异步加载策略 | 确立 ResourceLoader.load_threaded_request() 分批加载，每帧 10 个，主线程无阻塞 |
| card-system.md | §依赖——与 GSM 的接口需求 | 确立 GSM.allocate_card_id() 用于 ID 分配；GSM.enable_validation(db) 模板加载后启用校验 |
| card-system-design.md | 222 张卡牌涵盖 52 角色 + 52 功法 + 48 法宝 + 16 阵法 + 24 丹药 + 30 符箓 | 每张卡在 `assets/cards/templates/` 中对应一个 .tres 文件；CardType 枚举定义 6 种类型 |
| architecture.md | TR-card-001, TR-card-002 | 直接解决——本 ADR 是主架构文档中标记的 ADR-0006（卡牌数据模型） |
| architecture.md | OQ-04——模板异步加载，防止启动卡顿 | ResourceLoader.load_threaded_request() 分批加载策略——每帧 10 个，不阻塞主线程 |

## 性能影响
- **CPU**：模板查找（`get_template(id)`）为 O(1) 字典查询，<1μs。`get_templates_by_type(type)` O(n) 仅用于非热路径操作（收藏浏览、战利品生成）。`create_instance()` 每次调用的开销可以忽略（new RefCounted + GSM ID 分配）。
- **内存**：222 个模板 × 平均 1.5KB = 约 330KB（只读，共享）。运行时实例的存储占用 <1KB（GSM 中的引用加 CardInstance 对象）。总内存（模板 + 40 张实例）<500KB——远低于 2GB 总预算。
- **加载时间**：`load_threaded_request()` 后台异步——I/O 在后台线程，主线程每帧 10 个完成检查（<0.1ms/帧）。222/10 = 23 帧 ≈ 380ms 总加载时间。非阻塞——主菜单加载不受影响。
- **网络**：不适用（纯单机游戏）。

## 迁移计划
无现有代码需迁移——这是第二个 Foundation ADR。在 CardSystem 实现之前，GSM 以校验跳过模式运行（`validation_enabled = false`），所有 `add_card_to_collection()` 调用返回 false。

## 验证标准
- **GUT 单元测试**：
  - `CardSystemTest`：模板注册表——222 个模板全部成功加载（模拟批量 ResourceLoader），加载后 `templates.size() == 222`，重复 card_id 检测中止，缺文件时跳过 + 日志错误
  - `CardInstanceTest`：`create_instance()` 返回具有唯一 ID 和正确 template_id 的实例，`serialize_instance()` → Dictionary 往返 `deserialize_instance()` 保留所有字段，两个同名实例的 level 独立
  - `GSMIntegrationTest`：校验启用前 `add_card_to_collection()` 返回 false，templates_loaded 信号后 `enable_validation()` 调用后 `add_card_to_collection()` 对有效 template_id 成功
  - `StringNameSerializationTest`：反序列化后 `templates.has(StringName(deserialized.template_id))` 返回 true——确认存档往返不破坏字典查找
- **性能分析**：`templates_loaded` 信号在 `CardSystem._ready()` 后 500ms 内触发（目标硬件 i5 + SSD）。`get_template()` 调用一百万次 <100ms（O(1) 字典查询摊销）。
- **集成测试**：加载存档 → CardInstance 反序列化 → 检查 `get_template(inst.template_id).name` 返回正确的卡牌名称。模板加载完成后 GSM 接受 `add_card_to_collection()` 调用。

## 相关决策
- ADR-0001（游戏状态管理器）——CardInstance ID 分配、收藏持有、校验启用
- ADR-0006（卡牌效果引擎）——消费 CardTemplate 的 effect_type/effect_value
- ADR-0008（战斗系统）——消费角色卡模板的 base_hp/base_attack
- ADR-0003（事件系统）——事件触发卡牌获得/失去时调用 CardSystem
