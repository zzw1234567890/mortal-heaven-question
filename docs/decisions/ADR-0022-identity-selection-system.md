# ADR-0022：开局身份选择系统 — Feature Autoload + const 模板字典 + 服务编排模型

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Identity Selection |
| **知识风险** | LOW（仅使用 Dictionary、Signal、Autoload、const 数据表——全部自 4.0 起稳定） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——核心逻辑不依赖 4.4+ 新 API |
| **需要验证** | `const Dictionary` 中的 6 个 IdentityTemplate 不被运行时意外修改（GDScript `const` 不冻结嵌套内容——与 ADR-0010/ADR-0019 相同风险）；身份选择 UI 场景加载/卸载生命周期（`pre_transition`/`post_transition` 信号协作）；读档跳过身份选择的 GSM 路径（`player.identity_id` 非空时跳过） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`player.identity_id`、`player.talent_map` 运行时存储；`batch_updated` 信号传播身份选择完成）；ADR-0006（CardSystem——初始卡组中的卡牌模板验证、`create_instance()` 创建初始角色卡实例）；ADR-0007（三分类信号体系——`identity_selected` 归类为 Cat 2b 系统信号）；ADR-0012（ProgressionSystem——`get_talent_tree_state()` 查询轮回天赋解锁状态以确定哪些身份可选）；ADR-0019（ResourceSystem——`add_resource()` 设置初始灵石——遵循"所有资源写入必须通过 ResourceSystem"的强制契约） |
| **启用** | 卡组编辑系统（初始卡组写入 `deck.current_deck`）、探索系统（ADR-0014——身份选择完成后才开始探索流程）、事件系统（事件文本通过 `player.identity_id` 做分支）、战斗系统（天赋效果如首回合+1费、战斗开始护盾在 CombatSystem 中注册）、卡牌掉落/商店/战利品系统（身份ID用于卡池权重过滤） |
| **阻塞** | 身份选择 Epic（UI 界面 + 6 身份卡片 + 确认流程 + 初始状态应用 + 天赋注册）、开局叙事 Epic（身份 flavor_text 的逐行展示）、新游戏流程 Epic（主菜单 → 身份选择 → 开局叙事 → 探索地图） |
| **排序说明** | Feature 层——在 Foundation 层全部 7 个 ADR（#1~#7）+ Core 层关键 ADR（#6 CardSystem、#10 RealmSystem、#12 ProgressionSystem、#19 ResourceSystem）之后被接受。Autoload 初始化顺序：IdentitySelectionSystem 为 Autoload #21（完整 25 链：#1 GSM → #2 InputManager → #3 SceneManager → #4 SaveLoadSystem → #5 EventSystem → #6 CardSystem → #7 CostSystem → #8 StatusEffectSystem → #9 CombatSystem → #10 CardEffectEngine → #11 RealmSystem → #12 ProgressionSystem → #13 BindingManager → #14 ExplorationSystem → #15 FactionSystem → #16 ResourceSystem → #17 DeploymentSystem → #18 AISystem → #19 SchoolSystem → #20 CultivationSystem → #21 IdentitySelectionSystem → #22 DeckEditingSystem → #23 FormationSystem → #24 TribulationSystem → #25 StorySystem） |

## 上下文

### 问题陈述

`identity-selection-system.md` GDD 定义了完整的开局身份选择流程——6 种预设身份（5 默认 + 1 轮回解锁），每种身份绑定固定初始卡组（7 张卡牌）、两名初始角色卡、专属天赋和初始灵石。身份选择是新游戏开始时的「第一个决策点」，一旦选定本局不可更改。

GDD 覆盖了「玩家体验到的身份选择流程」，但以下架构问题需要在 ADR 层面解决：

1. **系统形态**：身份选择系统是否作为独立 Feature Autoload？还是作为 GSM 初始化流程的一部分？身份天赋效果需要贯穿整局游戏（战斗首回合+1费、灵石掉落+15%、丹药概率加成等）——如果只是初始化流程中的一个函数，各下游系统需要自行理解如何查询天赋效果，导致逻辑分散。
2. **模板存储**：6 个 IdentityTemplate 使用 `.tres` Resource 文件还是 `const Dictionary`？CardSystem（ADR-0006）为 222 张卡牌模板选择了 `.tres` 文件（策划可视化编辑需求），但身份模板仅为 6 个——是否需要同样的 I/O 开销？
3. **初始状态写入路径**：GDD 定义的初始状态应用步骤——写入初始卡组、写入初始角色、设置初始灵石、激活专属天赋——应通过直接 GSM 写入还是通过现有服务（ResourceSystem、CardSystem）编排？ADR-0019 已确立"所有资源写入必须通过 ResourceSystem"的强制契约——身份选择系统必须遵守。
4. **与轮回天赋系统的交互**：阵道双杰身份需要轮回天赋「苍玄行者」解锁。身份选择系统如何查询解锁状态？接口由谁定义？
5. **天赋效果注册**：身份专属天赋（如血海殿首回合+1费、玄冰宫战斗开始护盾2）需要被下游系统（CombatSystem、ExplorationSystem、ResourceSystem）感知。GSM `player.talent_map` 作为键值注册表是 GDD 定义的方案——但谁负责写入？谁负责读取？

`architecture.md` 将 IdentitySelectionSystem 标记为 Feature 层——依赖多个 Core/Feature 系统（GSM、CardSystem、ResourceSystem、ProgressionSystem），被探索系统和事件系统消费。

### 约束

- **GSM 数据所有权**：`player.identity_id` 和 `player.talent_map` 由 GSM 持有——IdentitySelectionSystem 通过 GSM 第二层原子方法写入（遵循 ADR-0001 写入者契约）
- **ResourceSystem 写入强制**：初始灵石设置必须通过 `ResourceSystem.add_resource()` ——不得直接写 `GSM.player.resources.ling_shi`（ADR-0019 禁止模式）
- **CardSystem 实例创建**：初始角色卡创建必须通过 `CardSystem.create_instance()` + `GSM.add_card_to_collection()` ——不得手动构造 CardInstance（ADR-0006 契约）
- **Autoload 初始化顺序**：IdentitySelectionSystem 必须在 CardSystem（#6）和 ProgressionSystem（#12）之后初始化——它需要查询模板验证和天赋解锁状态
- **模板不可变**：身份模板数据在运行时只读——与 CardTemplate（ADR-0006）、RealmSystem 数据表（ADR-0010）、ResourceSystem 公式表（ADR-0019）保持相同的不可变约束
- **天赋效果无状态**：身份天赋是整局持续的被动效果——不持有运行时状态（与 StatusEffectInstance 不同），通过 GSM `player.talent_map` 键值注册表被下游系统查询

### 需求

- 6 个身份模板的唯一定义源——杜绝跨系统重复定义
- 身份选择流程编排：读取解锁状态 → UI 展示 → 玩家选择 → 确认 → 应用初始状态 → 发射信号
- 初始状态写入：通过现有服务 API 编排写入（ResourceSystem、CardSystem），而非直接 GSM 裸写
- 天赋效果注册：写入 `GSM.player.talent_map`，下游系统通过键值查询
- 读档跳过：`GSM.player.identity_id` 非空时跳过身份选择
- 轮回解锁查询：通过 `ProgressionSystem.get_talent_tree_state()` 确定可选身份

## 决策

**IdentitySelectionSystem 作为 Feature 层 Autoload（#21）实现——持有 6 个身份模板的 `const Dictionary`、身份选择流程编排逻辑、以及 `apply_identity()` 原子操作（通过现有服务 API 编排状态写入）。不持有任何运行时可变状态——身份选择完成后所有状态存储在 GSM 中。**

### 层分类决议：Feature 层论证

IdentitySelectionSystem 依赖 Foundation 层（GSM）和 Core 层（CardSystem、ResourceSystem、ProgressionSystem），编排多个下游系统完成初始状态写入。它自身是垂直功能——身份选择——而非跨系统基础设施。符合 Feature 层定义："依赖 Core 层，被 Presentation 层消费"。

但是，身份天赋效果（`player.talent_map`）贯穿整局游戏——这意味着即便 IdentitySelectionSystem 在选择完成后不再主动执行逻辑，它仍然作为 Autoload 驻留内存。评估：Autoload 节点本身 <0.5KB（无运行时状态），可接受的常驻开销。替代方案——选择完成后 `queue_free()` 自身——会破坏 Autoload 的生命周期保证且无实质收益。

### 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                    GSM (ADR-0001) — 数据所有权                │
│  player.identity_id: StringName   ← 身份选择后写入           │
│  player.talent_map: Dictionary    ← 天赋效果键值注册表       │
│  deck.current_deck: Array[Dict]   ← 初始卡组（7张）          │
│  deck.slots: Array[Dict]          ← 初始角色（位1、位2）     │
│  player.resources.ling_shi: int   ← 初始灵石                 │
│  narrative.opening_text: String   ← 开局叙事文本             │
└──────────────┬───────────────────────────────────────────────┘
               │ 数据存储所有权
               ▼
┌──────────────────────────────────────────────────────────────┐
│        IdentitySelectionSystem (ADR-0022) — Autoload #21     │
│                                                              │
│  ┌─ 身份模板表（const Dictionary，编译时常量）──────┐        │
│  │ IDENTITY_TEMPLATES: Dict[StringName, Dictionary] │        │
│  │   6 个模板，每个含：                               │        │
│  │   - name, description, flavor_text, style_tag    │        │
│  │   - initial_deck: {cards: [{card_id, count}],    │        │
│  │                     character_slots: [{card_id,   │        │
│  │                     slot_index}]}                 │        │
│  │   - initial_resources: {ling_shi: int}           │        │
│  │   - talent: {id, name, desc, magnitude}          │        │
│  │   - unlock_condition: {default_unlocked: bool,   │        │
│  │                         require_talent: StringName│        │
│  │                        | null}                    │        │
│  └──────────────────────────────────────────────────┘        │
│                                                              │
│  ┌─ 流程编排 API ───────────────────────────────────┐        │
│  │ get_available_identities() → Array[Dict]         │        │
│  │   → 查询 ProgressionSystem 天赋解锁状态           │        │
│  │   → 返回已解锁身份列表（含 unlock_condition 元数据）│        │
│  │                                                   │        │
│  │ get_identity_preview(id) → Dict                  │        │
│  │   → 返回完整模板数据供 UI 预览面板使用             │        │
│  │                                                   │        │
│  │ apply_identity(identity_id: StringName) → bool   │        │
│  │   → 原子操作：全部初始状态写入，失败则全部回滚     │        │
│  └──────────────────────────────────────────────────┘        │
│                                                              │
│  ┌─ 内部——apply_identity() 编排流程 ───────────────┐        │
│  │ ① 验证 identity_id 有效 + 已解锁                 │        │
│  │ ② 验证所有 card_id 在 CardSystem.templates 中存在│        │
│  │ ③ ResourceSystem.add_resource("ling_shi", N)     │        │
│  │ ④ CardSystem.create_instance() → 初始角色×2      │        │
│  │    CardSystem.create_instance() → 初始卡牌×N      │        │
│  │    GSM.add_card_to_collection() → 全部写入        │        │
│  │ ⑤ 写入 deck.current_deck + deck.slots            │        │
│  │ ⑥ GSM.player.talent_map[talent.id] = magnitude   │        │
│  │ ⑦ GSM.set("player.identity_id", identity_id)     │        │
│  │ ⑧ 发射 identity_selected(identity_id)             │        │
│  └──────────────────────────────────────────────────┘        │
│                                                              │
│  信号: identity_selected(identity_id: StringName)  — Cat 2b  │
│         身份选择确认后发射——探索系统、事件系统、叙事系统消费 │
└──────────────┬──────────────────────────────────────────────┘
               │ get_available_identities() 查询
               ▼
┌──────────────────────────────────────────────────────────────┐
│          ProgressionSystem (ADR-0012) — Autoload #12         │
│  get_talent_tree_state() → Dict                              │
│    {unlocked: ["talent_01", ...], equipped: [...], ...}      │
│                                                              │
│  解锁身份条件："formation_duo" 需要 "cang_xuan_walker"       │
│  已在 unlocked_talents 列表中                                │
└──────────────────────────────────────────────────────────────┘
```

### 关键接口

```gdscript
# === IdentitySelectionSystem Autoload ===

## 启动时合约
func _ready() -> void:
    # ① 验证 IDENTITY_TEMPLATES 中所有 card_id 有效性
    #    ——在 CardSystem.templates_loaded 信号后执行
    #    ——任何无效 card_id：记录错误，该身份标记为不可选
    # ② 无其他初始化——模板为 const，无需加载

## 查询可用身份——结合轮回天赋解锁状态
func get_available_identities() -> Array[Dictionary]:
    var talent_state: Dictionary = ProgressionSystem.get_talent_tree_state()
    var unlocked: Array[String] = talent_state.get("unlocked", [])
    var result: Array[Dictionary] = []

    for id in IDENTITY_TEMPLATES:
        var tmpl: Dictionary = IDENTITY_TEMPLATES[id]
        var cond: Dictionary = tmpl["unlock_condition"]

        var is_unlocked: bool = cond.get("default_unlocked", true)
        if not is_unlocked:
            var required: StringName = cond.get("require_talent", "")
            if required != "" and required in unlocked:
                is_unlocked = true

        var entry: Dictionary = {
            "identity_id": id,
            "name": tmpl["name"],
            "description": tmpl["description"],
            "style_tag": tmpl["style_tag"],
            "initial_ling_shi": tmpl["initial_resources"]["ling_shi"],
            "talent_name": tmpl["talent"]["name"],
            "talent_desc": tmpl["talent"]["description"],
            "character_display_names": _get_character_names(tmpl),
            "is_unlocked": is_unlocked,
            "is_recommended": tmpl.get("recommended_for_new_player", false),
        }
        result.append(entry)

    return result

## 获取完整预览——供 UI 预览面板使用
func get_identity_preview(identity_id: StringName) -> Dictionary:
    var tmpl: Dictionary = IDENTITY_TEMPLATES.get(identity_id, {})
    if tmpl.is_empty():
        return {}

    return {
        "identity_id": identity_id,
        "name": tmpl["name"],
        "description": tmpl["description"],
        "flavor_text": tmpl["flavor_text"],
        "style_tag": tmpl["style_tag"],
        "initial_deck_cards": tmpl["initial_deck"]["cards"],
        "character_slots": tmpl["initial_deck"]["character_slots"],
        "character_details": tmpl["character_details"],
        "initial_ling_shi": tmpl["initial_resources"]["ling_shi"],
        "talent": tmpl["talent"],
        "unlock_condition": tmpl["unlock_condition"],
        "playstyle_hint": tmpl.get("playstyle_hint", ""),
    }

## 应用身份——编排多系统写入的原子操作
func apply_identity(identity_id: StringName) -> bool:
    # ① 前置校验
    var tmpl: Dictionary = IDENTITY_TEMPLATES.get(identity_id, {})
    if tmpl.is_empty():
        push_error("IdentitySelectionSystem: unknown identity_id '%s'" % identity_id)
        return false

    # 校验解锁状态
    var available: Array[Dictionary] = get_available_identities()
    var is_unlocked: bool = false
    for entry in available:
        if entry["identity_id"] == identity_id and entry["is_unlocked"]:
            is_unlocked = true
            break
    if not is_unlocked:
        push_error("IdentitySelectionSystem: identity '%s' is locked" % identity_id)
        return false

    # ② 校验所有卡牌模板有效性
    for card_entry in tmpl["initial_deck"]["cards"]:
        var card_id: String = card_entry["card_id"]
        if not CardSystem.has_template(StringName(card_id)):
            push_error("IdentitySelectionSystem: card template missing: '%s'" % card_id)
            return false
    for char_entry in tmpl["initial_deck"]["character_slots"]:
        var char_id: String = char_entry["card_id"]
        if not CardSystem.has_template(StringName(char_id)):
            push_error("IdentitySelectionSystem: character template missing: '%s'" % char_id)
            return false

    # ③ 批量应用初始状态
    #   (先写 GSM.identity_id 以满足"选择身份"的语义——后续写入可引用之)
    GSM.set("player.identity_id", identity_id)

    # ④ 设置初始灵石——通过 ResourceSystem（ADR-0019 强制契约）
    var ling_shi: int = tmpl["initial_resources"]["ling_shi"]
    if not ResourceSystem.add_resource(&"ling_shi", ling_shi):
        push_error("IdentitySelectionSystem: failed to set initial ling_shi")
        GSM.set("player.identity_id", "")  # 回滚 identity_id
        return false

    # ⑤ 创建初始卡牌实例——通过 CardSystem（ADR-0006 契约）
    _create_initial_cards(tmpl["initial_deck"]["cards"])

    # ⑥ 创建初始角色实例——写入 deck.slots
    _create_initial_characters(tmpl["initial_deck"]["character_slots"])

    # ⑦ 注册身份天赋——写入 GSM talent_map
    var talent_def: Dictionary = tmpl["talent"]
    GSM.set_talent(StringName(talent_def["id"]), talent_def["magnitude"])

    # ⑧ 写入开局叙事文本
    GSM.set_narrative_flag(&"opening_text", tmpl["flavor_text"])

    # ⑨ 发射身份选择完成信号
    identity_selected.emit(identity_id)

    return true

## 信号定义（Cat 2b——系统特定事件）
signal identity_selected(identity_id: StringName)
  # 身份选择完成并全部初始状态写入后发射
  # 消费者：探索系统（开始地图选择）、叙事系统（展示开局叙事）、
  #          事件系统（准备身份分支事件）

## 工具方法
func is_identity_selected() -> bool:
    return not GSM.player.identity_id.is_empty()

func get_current_identity() -> StringName:
    return GSM.player.identity_id

## 查询身份天赋——供下游系统直接查询
func get_identity_talent_value(talent_id: StringName) -> int:
    return GSM.player.talent_map.get(talent_id, 0)
```

### GSM 第二层扩展方法（IdentitySelectionSystem 专用）

遵循 ADR-0001 先例（CombatSystem 定义 `_set_battle_*`，ExplorationSystem 定义 `set_exploration_*`）：

```gdscript
# === GSM 第二层：身份选择专用原子写入 ===

GSM.set("player.identity_id", value: StringName) → void
  # 写入 GSM.player.identity_id + 发射 batch_updated
  # 注意：GSM 已有通用 set() 方法，此处的 set() 复用现有 API

GSM.set_talent(talent_id: StringName, magnitude: int) → void
  # 写入 GSM.player.talent_map[talent_id] = magnitude + 发射 batch_updated
  # talent_id 唯一性——如果已存在则覆盖（最后一局的身份选择胜出——但正常不应重复选择）
```

### 信号传播路径

`IdentitySelectionSystem.apply_identity()` → 多次 GSM 第二层原子写入 → 批量 `batch_updated` 信号 → HUD、UI、下游系统刷新。

`identity_selected`（Cat 2b）是额外的语义信号——它携带身份 ID，让探索系统和叙事系统知道「身份选择已完成，可以开始了」。GSM 的 `batch_updated` 可以传播所有数据变更（`player.identity_id`、`player.resources.ling_shi`、`player.talent_map.*`），但 `identity_selected` 传递的是**流程状态信息**（"身份选择这个流程已完成"）而非数据变更——符合 ADR-0007 的 Cat 2b 分类标准。

### 天赋效果——键值映射制（遵循 GDD §公式#1）

GDD 已明确定义天赋效果为键值映射制：`GSM.player.talent_map[talent_id] = magnitude`。本 ADR 确认此设计：

```
# 身份选择时写入（IdentitySelectionSystem.apply_identity()）
GSM.player.talent_map["ling_shi_boost"] = 15
GSM.player.talent_map["first_strike_extra_cost"] = 1
GSM.player.talent_map["frost_guard_shield"] = 2
GSM.player.talent_map["alchemy_affinity"] = 20    # shop_bonus 子值
GSM.player.talent_map["re_forge_opportunity"] = 1
GSM.player.talent_map["formation_master"] = 1

# 下游系统查询（无写回——只读消费）
# ResourceSystem: if "ling_shi_boost" in GSM.player.talent_map: ...
# CombatSystem:   if "first_strike_extra_cost" in GSM.player.talent_map and turn == 1: ...
# EventSystem:    if "re_forge_opportunity" in GSM.player.talent_map: ...
```

此设计的关键属性：
- **与轮回天赋天然隔离**：身份天赋写入 `GSM.player.talent_map`（单局数据），轮回天赋写入 `ProgressionSystem._talents`（跨局数据，ADR-0012）——两者物理分离，不存在命名冲突
- **叠加友好**：GSM 键值映射天然支持多来源同类效果叠加——`if talent_id in map: sum += map[talent_id]`
- **零开销查询**：下游系统直接 `GSM.player.talent_map.get(id, 0)` —— O(1)，无方法调用

## 启动合约

1. IdentitySelectionSystem 在 CardSystem.templates_loaded 信号后完成验证——检查 IDENTITY_TEMPLATES 中所有 card_id 在 CardSystem 注册表中存在
2. 验证失败的 card_id → 记录错误日志，该身份标记为不可选
3. 在 CardSystem 模板加载完成前，`apply_identity()` 拒绝执行（返回 false + 警告）
4. 读档检测：`GSM.player.identity_id` 非空 → 身份选择已完成，跳过

## 读档行为

- **新游戏**：`GSM.player.identity_id` 为空 → 进入身份选择界面 → `apply_identity()` 写入
- **读档**：存档中包含 `player.identity_id` → GSM 恢复后 `is_identity_selected()` 返回 true → 跳过身份选择，直接进入游戏
- **身份选择进行中退出**：未调用 `apply_identity()`，GSM 中无 `identity_id`——下次新游戏仍从身份选择界面开始

## 考虑的替代方案

### 替代方案 A：身份选择作为 GSM 初始化流程的一部分——非独立系统

- **描述**：身份选择在 GSM 的 `_ready()` 或新游戏流程中作为一系列函数调用执行——`select_identity_menu()`、`apply_identity_setup()` 等。不创建独立 Autoload。
- **优点**：减少 1 个 Autoload——链长度保持在 18。身份选择本身是一次性操作（新游戏开始时），不需要独立的生命周期。
- **缺点**：
  1. 天赋效果查询入口缺失——下游系统需要知道「去 GSM 查 talent_map」而非「去 IdentitySelectionSystem 查天赋」。GSM 是所有数据的集合，但没有提供"身份相关查询"的语义封装。如果未来身份系统需要扩展（如新增天赋效果类型），调用方需要自行理解 `talent_map` 的内部结构。
  2. 解锁逻辑分散——检查阵道双杰是否解锁的逻辑要么写死在 GSM（违反不膨胀原则），要么分散在 UI 脚本中（违反单一真理来源）。
  3. UI 数据准备逻辑无处归属——身份选择界面需要 6 个身份的结构化预览数据（名称、角色、天赋、灵石），这些数据的构造应该在 Feature 系统中完成，而非在 UI 脚本中硬编码重复。
  4. 违反先例：RealmSystem（ADR-0010）、ProgressionSystem（ADR-0012）、BindingManager（ADR-0013）、ExplorationSystem（ADR-0014）均为独立 Autoload——身份选择系统如果合并到 GSM，将破坏"同级别功能相同级别的模块化"的模式一致性。
- **拒绝原因**：身份选择系统虽然触发频率低（每局一次），但它拥有明确的领域逻辑——解锁条件判定、模板验证、多服务编排写入、天赋效果注册——这些属于 Feature Autoload 的职责范畴。将其压缩到 GSM 中将重复 ADR-0019 替代方案 A 的错误（GSM 膨胀为上帝对象）。

### 替代方案 B：身份模板使用 `.tres` Resource 文件

- **描述**：6 个 IdentityTemplate 各自存储为 `assets/identities/azure_sword_disciple.tres` 等 Resource 文件——与 CardSystem 的 222 个 CardTemplate `.tres` 文件保持一致。
- **优点**：与 CardSystem 一致的编辑器可视化工作流——策划可在 Godot Inspector 中编辑身份数据。与现有 `.tres` 工作流一致。
- **缺点**：
  1. 仅为 6 个模板配置 I/O 加载管线——`ResourceLoader.load()` 或 `load_threaded_request()` 的开销对于 6 个文件可以忽略不计，但管线本身的代码量不小（目录枚举、进度跟踪、加载完成信号）
  2. 身份模板字段是平坦结构（名称、描述、灵石数量、天赋值等）——没有 CardTemplate 那样复杂的类型专属字段和 222 个文件的规模。`const Dictionary` 可被文本编辑器直接阅读，而 `.tres` 需要 Godot 编辑器
  3. 策划可能不擅长 `.tres` 格式——相比 C#/JSON 等格式，`.tres` 的 Resource 语法不够直观
- **拒绝原因**：6 个模板的数量级不值得 I/O 管线的代价。`const Dictionary` 对齐 ResourceSystem（ADR-0019）和 RealmSystem（ADR-0010）的 `const` 数据表模式——这些系统同样有少量静态数据且选择了 `const` 而非 `.tres`。如果未来身份数量增长到 20+ 且有复杂嵌套结构，迁移到 `.tres` 是低成本重构（替换 `const` 为 `ResourceLoader.load()`，API 不变）。

### 替代方案 C：初始状态全部通过直接 GSM 写入——绕过现有服务

- **描述**：`apply_identity()` 直接写入 `GSM.player.resources.ling_shi = value`、直接拼装 CardInstance Dictionary 写入 `GSM.collection.owned_cards`，不经过 ResourceSystem 和 CardSystem。
- **优点**：最简——一个函数完成所有写入。无服务间依赖——IdentitySelectionSystem 仅依赖 GSM。
- **缺点**：
  1. 违反 ADR-0019 强制契约："所有资源写入必须通过 ResourceSystem"——直接写 `GSM.player.resources.ling_shi` 跳过余额校验和信号传播
  2. 违反 ADR-0006 契约：CardInstance 创建必须通过 `CardSystem.create_instance()` + `GSM.allocate_card_id()`——手动构造 Dictionary 绕过全局唯一 ID 分配机制
  3. 与身份天赋的"服务编排"角色矛盾——如果身份选择系统直接裸写 GSM，那么其他系统（如事件系统的"身份相关事件奖励额外灵石"）也会效仿绕过 ResourceSystem——契约腐蚀会扩散
- **拒绝原因**：架构一致性优先于局部便利。身份选择系统是多个下游系统的编排者——它应该委托给专业系统（ResourceSystem 管理资源、CardSystem 管理卡牌），而非自行实施这些系统的核心逻辑。遵循 ADR-0001 的"写入者契约"——所有状态写入通过 GSM 第二层原子方法，但业务逻辑在各 Feature/Core 系统中。

## 后果

### 积极的

- **身份模板单一真理来源**：6 个模板在 `IDENTITY_TEMPLATES` const Dictionary 中唯一定义——策划修改一个文件，所有消费者自动生效
- **与现有架构模式一致**：const 数据表（对齐 RealmSystem、ResourceSystem）+ Autoload 编排（对齐 ExplorationSystem、BindingManager）+ 服务委托写入（对齐 ADR-0019 契约）
- **天赋效果零开销消费**：下游系统通过 `GSM.player.talent_map.get(id, 0)` 查询——O(1) 字典查找，无额外服务调用。身份天赋与轮回天赋物理分离，符号空间无冲突
- **读档兼容**：`is_identity_selected()` 仅检查 `GSM.player.identity_id` 非空——存档恢复后自动跳过身份选择，无额外逻辑
- **解锁逻辑集中**：`get_available_identities()` 唯一定义解锁条件判定——如果未来新增第 7 个身份或修改解锁条件，仅需修改此函数和 const 模板表

### 消极的

- **增加第 21 个 Autoload（25 链中）**：初始化链增长。但 IdentitySelectionSystem 依赖链仅 GSM（#1）+ CardSystem（#6）+ ProgressionSystem（#12）+ ResourceSystem（#16）——4 个上游依赖，无循环依赖
- **const Dictionary 嵌套深度达 3 层**：模板结构包含 `initial_deck.cards[]`、`initial_deck.character_slots[]`、`character_details[]` 三层嵌套——可读性不如扁平 `.tres`。缓解：每个身份的段落使用清晰命名和注释分隔（见实现时的代码风格要求）
- **卡牌模板验证依赖于 CardSystem 就绪**：IdentitySelectionSystem 的 `_ready()` 验证需要在 `templates_loaded` 之后——依赖信号时序。缓解：`_ready()` 中连接 `CardSystem.templates_loaded` 信号进行延迟验证，此期间 `apply_identity()` 拒绝执行

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| `const Dictionary` 被意外修改 | 低 | 运行时身份数据错误 | 团队约定：模板只读。GUT 冒烟测试验证 6 个模板关键字段的基准值（azure_sword_disciple.initial_resources.ling_shi == 15 等）。与 ADR-0010/ADR-0019 风险一致 |
| 身份天赋 ID 与轮回天赋 ID 冲突 | 低 | 不同来源的效果被误叠加 | 采用命名约定隔离：身份天赋前缀 `identity_`（如 `identity_first_strike`），轮回天赋前缀 `talent_`。GUT 测试验证 ProgressionSystem 的 `unlocked_talents` 集合与 `IDENTITY_TEMPLATES` 中所有 `talent.id` 无交集 |
| `apply_identity()` 中途失败——部分状态已写入 GSM | 低 | GSM 部分数据残留，导致重新选择身份时出现混合状态 | 遵循 "先校验全部，再写入全部" 的原则——卡牌模板验证 + 解锁验证在写入前全部完成。如果 ResourceSystem.add_resource() 失败，回滚 `player.identity_id`（设为空字符串）。CardInstance 创建失败同理 |
| 阵道双杰解锁条件依赖 ProgressionSystem | 低 | 如果 ProgressionSystem 的 `get_talent_tree_state()` 返回格式变更，解锁判定静默失败 | GUT 集成测试验证 `get_available_identities()` 在 ProgressionSystem 返回各种合法/边界状态下返回正确结果 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| identity-selection-system.md | §概述——6 种身份选择作为第一决策点 | 确立 IdentitySelectionSystem 为身份选择的唯一权威——持有 6 个模板、编排选择流程、提供预览数据 |
| identity-selection-system.md | §1 身份定义结构——IdentityTemplate 数据结构 | 将 `IDENTITY_TEMPLATES` const Dictionary 确立为 6 个身份模板的单一真理来源 |
| identity-selection-system.md | §3 身份选择流程——新游戏→检查→UI→确认→应用→进入游戏 | 确立 `apply_identity()` 8 步原子操作序列——验证→灵石→卡牌→角色→天赋→叙事→信号 |
| identity-selection-system.md | §5 身份影响范围——天赋贯穿整局 | 确立 GSM `player.talent_map` 键值注册表——下游系统通过 O(1) 字典查询消费 |
| identity-selection-system.md | §6 身份重选/读档——读档跳过身份选择 | 确立 `is_identity_selected()` 通过 `GSM.player.identity_id` 判定——存档恢复后自动跳过 |
| identity-selection-system.md | §7 身份与轮回天赋交互——阵道双杰解锁条件 | 确立 `get_available_identities()` 查询 `ProgressionSystem.get_talent_tree_state()` 解锁状态 |
| identity-selection-system.md | §公式 #1 天赋效果注册——键值映射制 | 确立 GSM `player.talent_map[talent_id] = magnitude` 为天赋效果的唯一运行时表示 |
| identity-selection-system.md | §依赖——GSM、CardSystem、ResourceSystem | 确立跨系统编排模型——委托写入而非直接裸写 GSM——遵循各自 ADR 的契约 |
| identity-selection-system.md | §验收标准——18 条核心 AC | 本 ADR 的验证标准覆盖全部 18 条 GDD 验收标准中的架构相关项（AC#1~#22） |

## 性能影响

- **CPU**：`apply_identity()` 仅在每局新游戏开始时调用一次——非热路径。8 步序列中：模板验证（6 个身份 × 7 张卡 × O(1) 字典查找）<0.1ms，创建初始卡牌实例（9 张 × CardSystem.create_instance()）<0.5ms，GSM 写入 + 信号发射 <0.5ms。总计 <2ms——在身份选择 UI 确认按钮响应的可接受延迟内
- **内存**：`IDENTITY_TEMPLATES` const Dictionary（6 个模板，每条约 500B）≈ 3KB——编译时常量。Autoload 节点 <1KB。GSM `player.talent_map` 每个身份 ≤6 个条目 ≈ 250B。总计常驻内存 <5KB
- **加载时间**：零——const Dictionary 编译时分配，`_ready()` 中仅做信号连接 + 模板有效性异步验证（不阻塞主线程）
- **网络**：不适用（单机游戏）

## 迁移计划

本 ADR 为新建架构——无现有代码需迁移。实现顺序：

1. 创建 `res://src/feature/identity_selection_system.gd`——IDENTITY_TEMPLATES const Dictionary + `get_available_identities()` + `get_identity_preview()` + `apply_identity()`
2. 在 `project.godot` 中注册 Autoload（#21，排在 ResourceSystem #16 和 AISystem #18 之后）
3. 在 GSM 中添加 `set_talent(talent_id, magnitude)` 第二层原子方法（如尚未存在）
4. 身份选择 UI 场景（`IdentitySelectionScreen.tscn`）——消费 `get_available_identities()` + `get_identity_preview()` 数据
5. 确认后调用 `apply_identity(selected_id)` → 订阅 `identity_selected` 信号进入游戏
6. GUT 测试覆盖：模板有效性验证、解锁状态查询、`apply_identity()` 原子性、读档跳过

## 验证标准

- **GIVEN** CardSystem 模板加载完成（templates_loaded 已发射），**WHEN** `get_available_identities()`，**THEN** 返回包含 5 个解锁身份 + 阵道双杰（unlocked 取决于 ProgressionSystem 状态）
- **GIVEN** ProgressionSystem 中 `unlocked_talents` 不包含 "cang_xuan_walker"，**WHEN** 对阵道双杰执行 `get_available_identities()`，**THEN** 该条目 `is_unlocked == false`
- **GIVEN** ProgressionSystem 中 `unlocked_talents` 包含 "cang_xuan_walker"，**WHEN** 对阵道双杰执行 `get_available_identities()`，**THEN** `is_unlocked == true`
- **GIVEN** identity_id="azure_sword_disciple" 有效且已解锁，**WHEN** `apply_identity("azure_sword_disciple")`，**THEN** 返回 true，GSM 中 `player.identity_id == "azure_sword_disciple"`，`player.resources.ling_shi == 15`，`player.talent_map["ling_shi_boost"] == 15`，`identity_selected` 信号已发射
- **GIVEN** identity_id="formation_duo" 未解锁，**WHEN** `apply_identity("formation_duo")`，**THEN** 返回 false，GSM 中 `player.identity_id` 仍为空（无部分写入残留）
- **GIVEN** IDENTITY_TEMPLATES 中某 card_id 不在 CardSystem.templates 中（模拟模板缺失），**WHEN** `apply_identity()`，**THEN** 返回 false + 日志错误（卡牌模板验证失败阻止写入）
- **GIVEN** 选择血海殿遗孤，**WHEN** 检查 `GSM.player.talent_map`，**THEN** 包含 `"first_strike_extra_cost"` 值为 1
- **GIVEN** 选择玄冰宫弟子，**WHEN** 检查 `GSM.player.talent_map`，**THEN** 包含 `"frost_guard_shield"` 值为 2
- **GIVEN** 选择碎星群岛散修，**WHEN** 检查初始灵石，**THEN** `GSM.player.resources.ling_shi == 18`
- **GIVEN** 存档中包含 `player.identity_id = "azure_sword_disciple"`，**WHEN** 读档后调用 `is_identity_selected()`，**THEN** 返回 true——跳过身份选择
- **GIVEN** identity_id="invalid_fake_identity"，**WHEN** `apply_identity("invalid_fake_identity")`，**THEN** 返回 false，GSM 状态不变
- **GIVEN** 选择任意身份，**WHEN** 在 `apply_identity()` 执行中 ResourceSystem.add_resource() 失败（模拟），**THEN** `player.identity_id` 被回滚为空字符串

> **集成测试（需下游系统实现后执行）：**
> - **GIVEN** `GSM.player.talent_map["first_strike_extra_cost"] == 1`，**WHEN** 战斗开始首回合，**THEN** CombatSystem 读取此值并为玩家增加 1 费用上限
> - **GIVEN** `GSM.player.talent_map["frost_guard_shield"] == 2`，**WHEN** 战斗开始，**THEN** CombatSystem 为全体友方角色施加 2 点护盾
> - **GIVEN** `GSM.player.talent_map["ling_shi_boost"] == 15`，**WHEN** 探索中获得 N 灵石，**THEN** ResourceSystem 的 `apply_ling_shi_bonus()` 计算 floor(N × 1.15)

## 相关决策

- ADR-0001（游戏状态管理器——`player.identity_id`、`player.talent_map` 数据所有权；GSM 第二层原子写入 `set_talent()`）
- ADR-0006（卡牌数据模型——`create_instance()` 创建初始角色/卡牌实例；模板验证阻止无效 card_id）
- ADR-0007（三分类信号体系——`identity_selected` 归类为 Cat 2b 系统信号）
- ADR-0012（跨局元进度——`get_talent_tree_state()` 查询轮回天赋解锁状态）
- ADR-0019（资源系统——`add_resource()` 设置初始灵石——遵循强制写入契约）
- ADR-0014（探索系统——`identity_selected` 信号触发地图选择流程）
- ADR-0013（绑定系统——初始功法卡牌在游戏开始后的首次战斗中通过 BindingManager 绑定到角色）
