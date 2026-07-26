# ADR-0010：境界系统 — 专用 Autoload 服务 + 静态数据表 + GSM 状态所有权分离

## 状态
Accepted（2026-07-26——Core 层审查通过。修复：层归属 "Progression"→"Core" 修正、architecture.md Feature 层境界系统重复条目标注。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Core（RealmSystem 被 13+ 系统消费，作为只读基础设施运行。原 architecture.md 将其归入 Feature 层——本 ADR 论证迁移至 Core 层，见 §层分类决议） |
| **知识风险** | LOW（Godot 字典查询、信号系统、Autoload 模式均为 4.x 成熟 API） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **使用的截止后 API** | None——本 ADR 使用的 Dictionary、signal、const、@onready var 均为 4.0+ 稳定 API |
| **需要验证** | Autoload 初始化顺序：RealmSystem 必须在 GSM._ready() 之后、gsm_initialized 信号之前完成 realm_table 静态数据就绪；`const Dictionary` 内容在 GDScript 中非真正不可变——需 GUT 冒烟测试验证完整性（见 §风险） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`player.realm_level` 所有权、`change_realm()` 原子写入、`realm_changed` 信号、`gsm_initialized` 准入信号）；ADR-0007（三分类信号体系——`realm_upgraded` 分类为 Cat 2b 动作通知信号） |
| **启用** | ADR-0006（CardSystem——通过 `get_realm_property()` 查询 card_pool_tier + `get_rarity_weights()` 查询稀有度权重）；ADR-0008（CombatSystem——通过 `get_realm_property()` 查询 base_speed、cost_per_turn、压制系数）；ADR-0009（CardEffectEngine——通过 `get_realm_property()` 查询 card_pool_tier） |
| **阻塞** | 渡劫突破 Epic（TribulationSystem——依赖 `realm_up()` 执行突破后升级流程）；探索 Epic（ExplorationSystem——依赖 `map_unlock` 数据解锁地图入口）；战斗 Epic（CombatSystem——依赖境界压制系数和基础速度） |
| **排序说明** | Core 层 ADR。境界属性表为 13+ 系统提供只读基础设施，与 CardSystem（ADR-0006，Core 层）的只读模板注册表角色一致 |

## 上下文

### 问题陈述

境界系统定义 5 级大境界（炼气→筑基→金丹→元婴→化神），每个境界携带 15+ 项跨系统引用的属性（max_cultivation、max_deploy、cost_per_turn、deck_limit、action_points、base_speed、max_darkgold、card_pool_tier、map_unlock 等）。13 个以上的消费者系统需要查询境界属性：战斗系统（压制系数、基础速度、费用上限）、上场系统（max_deploy）、卡牌系统（card_pool_tier → 稀有度权重）、卡组编辑（deck_limit）、探索系统（map_unlock）、修为养成系统（max_cultivation）、渡劫突破系统（realm_up）、行动力系统（action_points）、AI 系统（敌方境界查询）、剧情系统（章节 entry_conditions 境界验证）、UI/HUD、地图系统（map_unlock 过滤）。

设计问题：**境界数据的归属方式和访问模式是什么？** 这是一个核心架构决策，因为它直接影响了 GSM 的规模（如果将数据嵌入 GSM，player.* 域会膨胀）、13+ 个系统的耦合方式（它们都通过哪个接口查询境界属性？）、以及未来扩展性（新境界属性的添加成本）。

### 约束

- **GSM 规模约束**：ADR-0001 确立 GSM 为运行时单一数据源。但将 5×15 静态数据表嵌入 GSM 会使其成为"上帝对象"——GSM 不应持有策划级设计数据表
- **查询性能约束**：境界属性查询发生在热路径上——战斗伤害结算每帧多次调用 `get_realm_property()`。必须 O(1)
- **真理来源单一性**：realm-system.md 已声明其境界属性表是 `action_points` 和 `cost_per_turn` 的唯一权威来源。架构设计必须落实此声明——代码层面不得有重复定义
- **初始化顺序约束**：境界数据必须在任何消费者系统查询之前就绪。GSM 的 `gsm_initialized` 信号是消费者系统的准入门槛
- **Godot 4.6 惯用性**：依技术偏好设定（`.claude/docs/technical-preferences.md`），本项目使用 GDScript + Autoload 模式。需评估新增 Autoload 的合理性

### 需求

- 13+ 个消费者系统必须在 O(1) 时间内查询境界属性
- 境界属性表必须为单一真理来源——杜绝 cross-GDD 重复定义（如 W-C4 警告所述）
- `realm_level` 运行时状态的所有权必须明确（GSM vs RealmSystem）
- `realm_up()` 突破升级流程必须原子化（多字段更新 + 溢出结算 + 地图解锁）
- 境界表未来可能扩展（新增第 6 境界、新增属性列）——扩展成本必须低

## 决策

### 层分类决议：Core 层论证

`architecture.md` 系统层映射表格原先将"境界系统"归入 **Feature** 层（与"修为养成 / 渡劫突破"并列）。本 ADR 论证**迁移至 Core 层**，理由如下：

1. **被依赖广度**：RealmSystem 被 13+ 个系统消费（CombatSystem、DeploymentSystem、CardSystem、DeckEdit、ExplorationSystem、CultivationSystem、TribulationSystem、ActionPoints、AI、StorySystem、UI/HUD、MapSystem、CostSystem）——这符合 Core 层的"基础设施"定义，而非 Feature 层的"垂直功能"定义
2. **无运行时可变状态**：RealmSystem 仅持有 `const realm_table`（编译时常量），自身不管理任何可变运行时状态——这与 CardSystem（ADR-0006，Core 层）的只读模板注册表角色类似
3. **类比先例**：CardSystem（ADR-0006）持有 222 个 CardTemplate 的只读注册表，已被分类为 Core 层。RealmSystem 以相同模式持有 5×15 项境界属性数据——角色完全一致

**需同步更新**：`architecture.md` §系统层映射表格中"境界系统"应从 Feature 层迁移至 Core 层。本 ADR 接受后执行此更新。

### 采用方案 A：专用 RealmSystem Autoload + GSM 状态所有权分离

**RealmSystem** 作为一个 Godot Autoload（`res://src/core/realm_system.gd`），负责：

1. **静态数据持有**：`realm_table: Dictionary` —— 5 级境界的 15+ 项属性，编译时常量（`const`），O(1) 键查询
2. **查询 API**：`get_realm_property(level: int, key: StringName) → Variant` —— 所有消费者系统的唯一查询入口
3. **便捷方法**：`get_current_property(key: StringName) → Variant` —— 免传 level 参数（内部从 GSM 读取 `player.realm_level`）
4. **突破编排**：`realm_up(player_realm: int) → void` —— 协调 GSM 写入 + 溢出结算信号 + 地图解锁委托
5. **计算属性**：`realm_penalty(attacker_lv: int, defender_lv: int) → float` —— 境界压制系数（移动自战斗系统）
6. **地图压制**：`map_effective_realm(player_lv: int, map_max_lv: int) → Dictionary` —— 柔性压制模型的 offensive/defensive 分域计算
7. **稀有度权重**：`get_rarity_weights(pool_tier: int) → Dictionary` —— pool_tier → {白, 蓝, 紫, 金, 暗金} 权重映射。权重表定义在 RealmSystem（非 CardSystem），落实 GDD §5 的"境界系统定义稀有度权重"声明

**GSM 保留**：
- `player.realm_level: int` 的所有权（与现有 ADR-0001 的 `player.*` 域一致）
- `change_realm(new_level: int) → void` 原子写入方法
- `realm_changed(old_level: int, new_level: int)` Cat 1 信号

### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    GSM (ADR-0001)                            │
│  player.realm_level: int  ← 唯一运行时状态真理来源            │
│  change_realm(new_level) → void  (原子写入)                   │
│  realm_changed(old, new)  → Cat 1 信号                       │
└──────────────┬──────────────────────────────────────────────┘
               │ 状态所有权
               ▼
┌─────────────────────────────────────────────────────────────┐
│              RealmSystem (ADR-0010) — Autoload               │
│                                                              │
│  realm_table: Dictionary  ← const 编译时常量                  │
│  ┌──────┬──────┬──────┬──────┬──────┬──────┐                │
│  │ L=1  │ L=2  │ L=3  │ L=4  │ L=5  │ ...  │                │
│  │炼气期│筑基期│金丹期│元婴期│化神期│(扩展)│                │
│  └──────┴──────┴──────┴──────┴──────┴──────┘                │
│                                                              │
│  查询 API：                                                   │
│    get_realm_property(L, key) → Variant    O(1)              │
│    get_current_property(key) → Variant     O(1)              │
│                                                              │
│  计算 API：                                                   │
│    realm_penalty(atk, def) → float                           │
│    map_effective_realm(player, map_max) → {off, def}         │
│    get_rarity_weights(pool_tier) → Dictionary                │
│                                                              │
│  编排 API：                                                   │
│    realm_up(player_lv) → void                                │
│                                                              │
│  Cat 2b 信号：                                               │
│    realm_upgraded(old_level, new_level)                      │
└──────────────┬──────────────────────────────────────────────┘
               │ get_realm_property() / get_current_property()
               ▼
   ┌───────────┬──────────┬──────────┬──────────┬──────────┐
   │ Combat    │Deployment│  Card    │  Deck    │Explore   │
   │ System    │ System   │ System   │  Edit    │ System   │
   │(penalty,  │(max_     │(card_    │(deck_    │(map_     │
   │ speed,    │ deploy)  │ pool_tier│ limit)   │ unlock)  │
   │ cost)     │          │ )        │          │          │
   └───────────┴──────────┴──────────┴──────────┴──────────┘
   ┌───────────┬──────────┬──────────┬──────────┬──────────┐
   │Cultivation│Tribulation│ Action   │   AI     │   UI     │
   │ System    │ System   │  Points  │ System   │  / HUD   │
   │(max_cult) │(realm_up)│(action_  │(enemy    │(display) │
   │           │          │ points)  │ realm)   │          │
   └───────────┴──────────┴──────────┴──────────┴──────────┘
```

### 关键接口

```gdscript
# === RealmSystem Autoload ===

## 静态数据表 —— 编译时常量，策划在此定义境界属性
const realm_table: Dictionary = {
    1: {
        name = "炼气期",
        max_cultivation = 1000,
        max_deploy = 2,
        cost_per_turn = 2,
        deck_limit = 20,
        action_points = 5,
        base_speed = 1,
        max_darkgold = 0,
        card_pool_tier = 1,
        map_unlock = "青云剑宗",
    },
    # ... L=2~5
}

## 常量表 —— pool_tier → 稀有度权重映射
## 策划在此定义各掉落池等级的白色/蓝色/紫色/金色/暗金卡牌权重
const DROP_POOL_WEIGHTS: Dictionary = {
    1: {&"white": 60, &"blue": 30, &"purple": 10, &"gold": 0, &"darkgold": 0},
    2: {&"white": 30, &"blue": 40, &"purple": 25, &"gold": 5, &"darkgold": 0},
    3: {&"white": 15, &"blue": 30, &"purple": 35, &"gold": 18, &"darkgold": 2},
    4: {&"white": 10, &"blue": 20, &"purple": 30, &"gold": 30, &"darkgold": 10},
    5: {&"white": 5, &"blue": 15, &"purple": 25, &"gold": 35, &"darkgold": 20},
}

## 查询指定掉落池等级的稀有度权重 —— O(1) 字典查询
## pool_tier: int ∈ [1, 5]。返回 {white: int, blue: int, purple: int, gold: int, darkgold: int}
## 无效 tier 返回空 Dictionary + WARN 日志
func get_rarity_weights(pool_tier: int) -> Dictionary:
    if not DROP_POOL_WEIGHTS.has(pool_tier):
        push_warning("RealmSystem: invalid pool_tier %d" % pool_tier)
        return {}
    return DROP_POOL_WEIGHTS[pool_tier]

## 查询指定境界的任意属性 —— O(1) 字典查询
## level: int ∈ [1, 5]。key: StringName（如 &"cost_per_turn"）
## 返回 Variant；无效 key 返回 null + WARN 日志
func get_realm_property(level: int, key: StringName) -> Variant:
    if not realm_table.has(level):
        push_warning("RealmSystem: invalid level %d" % level)
        return null
    var realm_data: Dictionary = realm_table[level]
    if not realm_data.has(key):
        push_warning("RealmSystem: key '%s' not found in level %d" % [key, level])
        return null
    return realm_data[key]

## 便捷方法 —— 查询当前境界属性（内部从 GSM 读取 realm_level）
func get_current_property(key: StringName) -> Variant:
    if not is_instance_valid(GSM) or GSM.player == null:
        push_error("RealmSystem: GSM not ready for get_current_property('%s')" % key)
        return null
    return get_realm_property(GSM.player.realm_level, key)

## 境界压制系数
func realm_penalty(attacker_lv: int, defender_lv: int) -> float:
    var delta: int = defender_lv - attacker_lv
    if delta <= 0: return 1.0
    if delta == 1: return 0.8
    return 0.5  # delta >= 2

## 柔性地图境界压制 —— 进攻/防御属性分域
func map_effective_realm(player_lv: int, map_max_lv: int) -> Dictionary:
    if player_lv <= map_max_lv:
        return {"offensive_lv": player_lv, "defensive_lv": player_lv}
    return {"offensive_lv": map_max_lv, "defensive_lv": player_lv}

## 突破升级编排 —— 原子多方协调
## 仅在渡劫突破成功后由 TribulationSystem 调用
func realm_up(current_level: int) -> void:
    var new_level: int = current_level + 1
    if new_level > realm_table.size():
        push_error("RealmSystem: cannot upgrade beyond max realm (%d)" % realm_table.size())
        return

    # 1. 更新 GSM 中的境界等级（原子写入）
    GSM.change_realm(new_level)

    # 2. 触发溢出修为结算（通过信号委托——RealmSystem 不直接调用 CultivationSystem）
    realm_upgraded.emit(current_level, new_level)
    # CultivationSystem 监听此信号 → 执行 overflow_pool → 属性丹结算
    # TribulationSystem 监听此信号 → 回满行动力
    # ExplorationSystem 监听此信号 → 解锁新地图入口
    # CardSystem 监听此信号 → 扩展掉落池

## Cat 2b 动作通知信号 —— realm_up() 完成后发射
signal realm_upgraded(old_level: int, new_level: int)
```

### 接口契约

| 接口 | 签名 | 调用方 | 被调用方 | 分类 (ADR-0007) |
|------|------|--------|---------|-----------------|
| 查询 | `RealmSystem.get_realm_property(level, key) → Variant` | 13+ 消费者系统 | RealmSystem | 直接调用（只读查询——无副作用） |
| 便捷查询 | `RealmSystem.get_current_property(key) → Variant` | UI/HUD/探索系统 | RealmSystem → GSM（只读） | 直接调用 |
| 稀有度权重 | `RealmSystem.get_rarity_weights(pool_tier) → Dictionary` | CardSystem | RealmSystem | 直接调用（纯查询） |
| 压制计算 | `RealmSystem.realm_penalty(atk, def) → float` | CombatSystem | RealmSystem | 直接调用（纯计算） |
| 地图压制 | `RealmSystem.map_effective_realm(player, map_max) → Dictionary` | ExplorationSystem | RealmSystem | 直接调用（纯计算） |
| 突破编排 | `RealmSystem.realm_up(current_lv) → void` | TribulationSystem | RealmSystem → GSM | 直接调用（编排器→子系统，ADR-0008/0009 模式） |
| 状态写入 | `GSM.change_realm(new_level) → void` | RealmSystem | GSM | 直接调用（GSM 第二层原子写入） |
| 生命周期信号 | `RealmSystem.realm_upgraded(old, new)` | RealmSystem | CultivationSystem、TribulationSystem、ExplorationSystem、CardSystem | Cat 2b（ADR-0007——单一事件通知，无 pre/post 配对） |
| 状态变更信号 | `GSM.realm_changed(old, new)` | GSM | 所有消费者 | Cat 1（ADR-0007——GSM 状态变更广播） |

## 考虑的替代方案

### 替代方案 B：仅嵌入 GSM —— 境界数据和逻辑完全存在于 GameStateManager 内部

- **描述**：`realm_table` 字典作为 GSM 的私有常量。所有查询通过 `GSM.get_realm_property(level, key)`。`realm_up()` 逻辑在 GSM 内部。不创建独立 Autoload。
- **优点**：
  - 减少 1 个 Autoload（Autoload 数量保持在 5 个）
  - realm_level 状态与 realm_table 数据在同一对象中——概念简单
  - 无跨 Autoload 初始化顺序依赖
- **缺点**：
  - GSM 成为"上帝对象"——5×15=75 项策划级静态数据 + 30+ 个运行时方法。违反单一职责原则（GSM 的职责是运行时状态管理，不是设计数据字典）
  - 消费者系统热路径上持续调用 `GSM.get_realm_property()`——GSM 的接口表面积膨胀
  - 新增境界属性需要修改 GSM 文件——GSM 是 Foundation 层最敏感的文件，高频修改风险高
  - realm-system.md 已声明境界属性表为独立权威来源——嵌入 GSM 在概念上与 GDD 设计意图不一致
- **拒绝原因**：GSM 的规模已经很大（35 个消费者、10+ 个域）。将设计数据表嵌入 GSM 会进一步违反单一职责原则——GSM 应管理运行时可变状态，而非策划级静态设计数据。

### 替代方案 C：基于 Resource —— 境界定义以 .tres 文件存在

- **描述**：每个境界为一个 `RealmDefinition` Resource（`.tres` 文件）。5 个 `.tres` 文件存放在 `assets/data/realms/`。运行时通过 `ResourceLoader.load()` 或 `@export var realm_defs: Array[RealmDefinition]` 加载。查询时遍历数组找匹配 level。
- **优点**：
  - 策划可在 Godot Inspector 中编辑境界属性——非程序员友好
  - 新增境界只需添加 `.tres` 文件——无需修改代码
  - 与 ADR-0002（CardTemplate Resource）和 ADR-0009（EffectTemplate Resource）模式一致
- **缺点**：
  - 加载开销——5 个 Resource 文件的同步或异步加载增加启动时间
  - 查询性能——O(n) 数组遍历 vs O(1) 字典查询（n=5 时可忽略，但模式上不优雅）
  - 属性变更需要重新保存 `.tres` 文件——git diff 不友好（二进制资源文件）
  - 境界数据量小（5×15=75 项）——Resource 系统的开销（序列化、引用计数）不划算
  - GDScript `const Dictionary` 在编译时验证——Resource 加载在运行时，加载失败只有运行时错误
- **拒绝原因**：5 个境界的静态数据规模太小，不值得引入 Resource 系统的开销。相比之下，`const Dictionary` 在编译时验证、O(1) 查询、零加载开销、git diff 友好。若未来境界数量增长到 20+ 且策划需要 Inspector 编辑，可升级为 Resource 模式——当前规模下，const Dictionary 是最优解。

### 替代方案 D：非 Autoload 服务类模式 —— RealmData 作为 RefCounted 工具类

- **描述**：RealmSystem 不作为 Autoload，而是作为 `class_name RealmData` 的 RefCounted 工具类。消费者系统通过 `RealmData.new()` 创建实例或通过依赖注入获取共享实例。
- **优点**：
  - 非 Autoload——不占用 Autoload 槽位
  - 可测试性更好——测试中可创建独立实例
  - 与 ADR-0009 替代方案 D 的推理一致（减少 Autoload 数量）
- **缺点**：
  - 需要额外的依赖注入机制——谁持有共享实例？谁负责创建？
  - 13+ 个消费者系统都需要引用同一个 RealmData 实例——在没有 DI 容器的 GDScript 中，这要么是 Autoload，要么是每个系统手动 `@export var realm_data: RealmData`
  - 如果 GSM 持有共享实例并暴露 `GSM.realm_data`，等同于嵌入 GSM（退化为替代方案 B）
  - `const Dictionary` 类变量在所有实例间共享——多个 `RealmData.new()` 不会复制数据，但实例管理本身增加复杂度
- **拒绝原因**：境界系统有 13+ 个消费者，需要一个项目级别的单一访问点。在 GDScript 中，这天然对应 Autoload。非 Autoload 服务类模式适合消费者较少的系统（如 PRDEngine 可嵌入 CardEffectEngine 内部），但境界系统是全局基础设施——Autoload 是正选。

## 后果

### 积极的

- **单一真理来源**：`realm_table` 是境界属性的唯一定义点。action-point-system.md、cost-system.md、combat-system.md 等 GDD 中不再需要重复境界数值——它们引用 `RealmSystem.get_realm_property()` 即可。解决了跨审查警告 W-C4
- **O(1) 查询性能**：`const Dictionary` 编译时分配，运行时零加载开销。热路径查询 < 0.01ms（两次字典查找）
- **关注点分离**：GSM 管理可变运行时状态（`realm_level`），RealmSystem 持有不可变设计数据（`realm_table`）。修改 `realm_table` 不触及 GSM——降低 Foundation 层修改风险
- **扩展成本低**：新增境界属性只需在 `realm_table` 的每个 level entry 中添加一个 key-value 对 + 在 `get_realm_property()` 文档中注明。新增第 6 境界只需在 `realm_table` 中添加 `6: {...}` entry
- **信号委托模式一致**：`realm_up()` 遵循 ADR-0004 确立的"编排器通过信号委托给子系统"模式——RealmSystem 不直接调用 CultivationSystem/ExplorationSystem/CardSystem/TribulationSystem 的内部方法
- **与 ADR-0001 的边界清晰**：`player.realm_level` 所有权不变——仍在 GSM。RealmSystem 是只读查询者 + 编排者（调用 GSM 写入），不是状态所有者

### 消极的

- **增加 1 个 Autoload**：项目 Autoload 从 architecture.md 当前记录的 10 个增加到 11 个（GSM → CardEffectEngine + RealmSystem）。根据 Godot 文档，Autoload 数量 < 20 对启动时间的影响可忽略不计（每个 Autoload 的 `_ready()` 在主循环开始前同步执行，20 个 Autoload 顺序初始化 < 50ms）。当前 11 个仍在安全范围内
- **初始化顺序依赖**：`RealmSystem._ready()` 必须在 GSM 的 `_ready()` 之后执行——因为 `get_current_property()` 通过 `GSM.player.realm_level` 读取。Godot Autoload 按 `project.godot` 中 `[autoload]` 部分的定义顺序初始化——需确保 RealmSystem 列在 GSM **之后**
- **间接性成本**：消费者系统需要同时引用 GSM（读 `realm_level`）和 RealmSystem（查 `realm_table`）。但大多数消费者只需调用 `get_current_property(key)`——一个调用即可，无需同时持有两个引用

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Autoload 数量持续增长（11→15→20+） | 中 | 启动时间增加、初始化顺序复杂度 | 当前 11 个安全（< 20 阈值）。若达到 15+ 个，在 ADR 中评估合并/服务类迁移。本 ADR 的"Autoload 扩容"风险已明确记录，后续 ADR 创建新 Autoload 时需引用本风险 |
| `const Dictionary` 内容被意外修改（GDScript `const` 不冻结嵌套内容） | 低 | 运行时数据损坏，跨系统不一致 | 团队约定：仅通过 `get_realm_property()` 和 `get_rarity_weights()` 读取，禁止直接写入 `realm_table` / `DROP_POOL_WEIGHTS` 内容。架构注册表新增 `forbidden_pattern` 条目。GUT 冒烟测试在 `_ready()` 中验证 `realm_table[1].max_cultivation == 1000` 等基准值 |
| `realm_table` 与 GDD 境界属性表不同步 | 低 | 运行时行为与设计意图不一致 | `realm_table` 在 `const` 中集中定义——审计单一文件即可。境界系统 GDD 验收标准可转化为对 `get_realm_property()` 返回值的自动化测试 |
| `get_realm_property()` 无效 key 静默返回 null | 低 | 消费者收到 null 后静默失败（如 cost_per_turn=null → 0 费） | 无效 key 触发 `push_warning()`——开发阶段可见。消费者系统应在 `_ready()` 中增加 `assert(get_realm_property(1, &amp;"cost_per_turn") != null)` 自检 |
| `realm_upgraded` 信号与 `realm_changed` 信号重复语义 | 低 | 消费者订阅混乱——不知道该监听哪个 | `realm_changed` (Cat 1) 表示"GSM 中 realm_level 值已变更"——任何写入都触发。`realm_upgraded` (Cat 2b) 表示"突破升级流程已完成"——仅在 realm_up() 成功后触发。语义不同，文档明确区分 |
| GSM 初始化前 RealmSystem 被查询 | 低 | `GSM.player` 为 null → 空指针异常 | `get_current_property()` 内置 `is_instance_valid(GSM) and GSM.player != null` 守卫——返回 null + push_error 而非崩溃。Autoload 初始化顺序确保 GSM 在 RealmSystem 之前 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| realm-system.md | §2「境界属性表（跨系统引用核心）」——所有其他系统通过 `get_realm_property(L, key)` 接口查询 | 定义 `RealmSystem.get_realm_property(level, key)` 为唯一查询入口。`realm_table` const Dictionary 为唯一数据源 |
| realm-system.md | §2「权威来源声明」——此表是 action_points 和 cost_per_turn 的唯一权威来源 | `realm_table` 在 RealmSystem 中集中定义。action-point-system.md 和 cost-system.md 通过 `get_realm_property()` 引用，消除 cross-GDD 重复 |
| realm-system.md | §3「境界压制规则」——境界系统定义压制数值系数，战斗系统在伤害结算时调用 | `realm_penalty(attacker_lv, defender_lv)` 纯计算方法——CombatSystem 在伤害结算时调用 |
| realm-system.md | §4「境界提升流程」——突破成功后 realm_up() 协调多方状态变更 | `realm_up()` 编排器：GSM.change_realm() + realm_upgraded 信号委托给 CultivationSystem/TribulationSystem/ExplorationSystem/CardSystem |
| realm-system.md | §5「卡牌掉落池与境界绑定」——card_pool_tier → 稀有度权重映射 | `get_rarity_weights(pool_tier)` 在 RealmSystem 中集中定义权重表——CardSystem 调用此方法获取稀有度分布，不自行维护权重表副本。落实 GDD §5 的"境界系统定义稀有度权重"声明 |
| realm-system.md | §6「境界与地图关系」——境界解锁地图、柔性压制 | `map_effective_realm(player_lv, map_max_lv)` 提供进攻/防御分域计算。`map_unlock` 属性提供解锁地图名称 |
| realm-system.md | §7「境界显示」——HUD 中始终显示当前境界名称 + 层级 | UI/HUD 通过 `get_current_property(&"name")` 获取显示名称 |
| cultivation-system.md | §2「修为上限由境界决定」——`max_cultivation(realm_level) = BASE_MAX × 1.5^(realm_level - 1)` | CultivationSystem 通过 `get_current_property(&"max_cultivation")` 获取当前上限值 |
| cultivation-system.md | §7「溢出属性丹自动发放」——突破成功后溢出池结算 | RealmSystem 发射 `realm_upgraded` 信号 → CultivationSystem 监听并执行 overflow_pool → 属性丹结算 |

## 性能影响
- **CPU**：`get_realm_property()` < 0.01ms（两次字典查找——`realm_table[level]` + `realm_data[key]`）。在战斗帧（16.6ms 预算）中可忽略不计。`realm_penalty()` 纯整数比较——< 0.001ms
- **内存**：`realm_table` const Dictionary——5×15 项 ≈ 2KB。Autoload 节点本身 ≈ 0.5KB。总计 < 3KB 常驻内存
- **加载时间**：const Dictionary 编译时分配——零运行时加载开销。Autoload `_ready()` 为空（无需异步初始化）——不增加启动时间
- **网络**：不适用（单机游戏）

## 迁移计划
本 ADR 创建新系统，非修改现有代码。实施顺序：
1. 创建 `res://src/core/realm_system.gd` —— RealmSystem Autoload（const realm_table + 查询/计算/编排 API）
2. 在 `project.godot` 中注册 Autoload —— 排在 GSM 之后
3. 战斗系统实现时：从直接硬编码境界数值迁移到 `RealmSystem.get_realm_property()` 调用
4. 渡劫突破系统实现时：从直接操作 `GSM.player.realm_level` 迁移到 `RealmSystem.realm_up()` 编排调用
5. GDD 同步：action-point-system.md 和 cost-system.md 中独立的境界-数值映射表替换为对 RealmSystem 的引用

## 验证标准
- **GIVEN** RealmSystem 已初始化，**WHEN** 调用 `get_realm_property(3, &"cost_per_turn")`，**THEN** 返回 8
- **GIVEN** RealmSystem 已初始化，**WHEN** 调用 `get_realm_property(1, &"max_deploy")`，**THEN** 返回 2
- **GIVEN** realm_level=4，**WHEN** 调用 `get_current_property(&"deck_limit")`，**THEN** 返回 35
- **GIVEN** attacker_lv=1, defender_lv=2，**WHEN** 调用 `realm_penalty(1, 2)`，**THEN** 返回 0.8
- **GIVEN** attacker_lv=2, defender_lv=1，**WHEN** 调用 `realm_penalty(2, 1)`，**THEN** 返回 1.0（无压制）
- **GIVEN** current_level=2，**WHEN** 调用 `realm_up(2)`，**THEN** GSM.realm_level 变为 3 + `realm_upgraded(2, 3)` 信号已发射
- **GIVEN** `realm_upgraded` 信号已发射，**WHEN** CultivationSystem 收到信号，**THEN** 触发溢出池结算
- **GIVEN** realm_level=6（超出范围），**WHEN** 调用 `realm_up(5)`，**THEN** push_error + 不修改 GSM
- **GIVEN** 无效 key `get_realm_property(1, &"nonexistent")`，**WHEN** 调用，**THEN** 返回 null + push_warning

## 相关决策
- ADR-0001：游戏状态管理器 Autoload 三层 API —— `player.realm_level` 状态所有权、`change_realm()` 原子写入、`realm_changed` 信号
- ADR-0006：CardSystem（模板-实例分离）—— 通过 `get_realm_property()` 和 `get_rarity_weights()` 查询 card_pool_tier 及稀有度权重
- ADR-0007：三分类信号体系 —— `realm_upgraded` 分类为 Cat 2b 动作通知信号
- ADR-0008：战斗系统 7 阶段状态机 —— 通过 `get_realm_property()` 查询 base_speed、cost_per_turn、realm_penalty
- ADR-0009：卡牌效果引擎 Resource-RefCounted 模型 —— 通过 `get_realm_property()` 查询 card_pool_tier
