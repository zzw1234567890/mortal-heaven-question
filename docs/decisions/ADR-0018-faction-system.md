# ADR-0018：阵营系统 — Core 层轻量 Autoload 服务 + 标签库字典 + 实时遍历统计

## 状态
Accepted（2026-07-26——Core 层审查通过。修复：Autoload 计数统一为 25。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Core（阵营系统被 5+ 系统消费，持有只读静态标签库——与 RealmSystem ADR-0010 模式一致） |
| **知识风险** | LOW（Dictionary 查询、StringName 键类型、Array 遍历——均为 Godot 4.x 成熟 API） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **使用的截止后 API** | `Array[StringName]` 类型化集合（4.4+）——CardTemplate.faction_tags 字段使用。FactionSystem 本身使用裸 `Array` 迭代（兼容 4.0+） |
| **需要验证** | `const Dictionary` 嵌套结构在 GDScript 中的实际不可变性——需 GUT 冒烟测试验证标签库内容未被运行时修改 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0006（CardSystem——CardTemplate.faction_tags: Array[StringName] 字段是阵营数据的唯一运行时来源；CardSystem 持有所有上场角色的 CardInstance 引用）；ADR-0001（GSM——通过 `GSM.battle.field_characters` 获取当前场上角色列表）；ADR-0007（三分类信号体系——阵营系统本身不发射信号，阵营判定结果由消费者通过直接调用获取；阵营分布变化是上场/阵亡事件的结果，由 DeploymentSystem/CombatSystem 的信号驱动消费者重新查询） |
| **启用** | 阵法系统（FormationAura——`count_on_field()` / `check_condition()` 阵法激活判定）、卡牌效果引擎（CardEffectEngine——`is_hostile_to()` / `belongs_to_alignment()` 阵营针对性效果结算）、流派系统（SchoolSystem——`get_faction_tags()` 路由条件之一）、探索系统（ExplorationSystem——`get_faction_tags()` 阵营事件选项过滤）、AI 系统（敌方阵营标签查询） |
| **阻塞** | 阵法 Epic（阵法激活的阵营条件判定依赖本系统）、卡牌效果 Epic（`is_hostile_to` 判定效果在效果引擎实现前必须可用）、流派 Epic（流派方向判定依赖阵营标签） |
| **排序说明** | Core 层 ADR——在 CardSystem (ADR-0006) 之后、阵法系统之前被接受。与 RealmSystem (ADR-0010) 并列——两者均为"静态数据表 + 纯查询接口"的轻量 Core 层服务 |

## 上下文

### 问题陈述

阵营系统是游戏的身份标识层——每个角色卡携带最多 3 个阵营标签（大阵营如正道/魔道 + 具体门派如青云剑宗/血海殿），场上阵营分布决定阵法是否激活、卡牌效果是否获得针对性加成、探索事件中哪些选项可用。

核心架构问题：**阵营数据如何被各消费者系统高效、一致地查询？**

当前现状：
- CardTemplate（ADR-0006）已有 `faction_tags: Array[StringName]` 字段——每个角色卡的标签已存储
- `architecture.md` §模块注册表将"阵营系统"归入 Feature 层，仅列出 `get_faction(card)` 和 `check_synergy(f1, f2)` 两个接口
- GDD `faction-system.md` 定义了完整的两层标签结构（大阵营 → 门派）、最多 3 标签规则、场上统计接口、敌对判定规则——但未指定这些接口在 Godot 中的工程实现方式

需要决策的问题：
1. **FactionSystem 的层归属和形态**——是独立的 Autoload 服务，还是嵌入 CardSystem 的工具方法，还是纯静态工具类？
2. **标签库的存储位置**——大阵营/门派/跨阵营标签的定义表放在哪里？CardTemplate 只存标签 ID 数组，标签的元数据（名称、图标、parent_alignment）需要一个权威定义点
3. **场上阵营统计的更新策略**——每次查询时实时遍历上场角色（O(6)），还是维护计数器缓存（部署/阵亡事件驱动更新）？
4. **门派到大阵营的推导机制**——"青云剑宗"角色是否自动计入"正道"计数？推导规则在哪里定义？

### 约束

- **场上角色上限**：6 人（ADR-0008 战斗系统）——遍历成本 O(6) 在帧预算 16.6ms 中可忽略（<0.01ms）
- **标签数量上限**：每角色最多 3 个标签（1 大阵营 + 最多 2 门派）——单角色阵营判定 O(3)
- **正魔互斥**：同一角色不可同时拥有正道和魔道标签——数据加载时校验，非运行时判定
- **阵亡不计入**：只有当前场上存活角色计入阵营统计（GDD §边缘情况明确要求）
- **只读查询**：阵营系统自身不维护可变运行时状态——所有数据来自 CardTemplate（标签）和场上角色列表（Context）
- **Godot 4.6 惯用性**：依技术偏好设定，使用 GDScript + Autoload。需评估新增 Autoload 的合理性

### 需求

- 5+ 个消费者系统需要查询阵营信息：阵法系统（激活判定）、卡牌效果引擎（is_hostile_to）、流派系统（方向路由）、探索系统（事件选项）、AI 系统（敌方阵营）
- 场上阵营统计必须实时准确——阵亡角色立即从统计中排除
- 门派标签必须能自动推导大阵营归属——消费者查询"正道人数"时不需要手动展开门派列表
- 标签库（名称、图标、parent_alignment）需单一真理来源——策划可在一个文件中查看所有阵营标签定义
- 与现有 ADR 对齐——CardTemplate.faction_tags 已定义（ADR-0006），不改变其数据结构

## 决策

### 层分类决议：Core 层论证

`architecture.md` §模块注册表原先将"阵营系统"归入 Feature 层。本 ADR 论证**迁移至 Core 层**，理由：

1. **被依赖广度**：阵营系统被 5+ 个系统消费（阵法、效果引擎、流派、探索、AI）——符合 Core 层"基础设施"定义
2. **无运行时可变状态**：FactionSystem 仅持有 `const FACTION_LIBRARY`（编译时常量标签库），自身不管理任何可变运行时状态——与 RealmSystem (ADR-0010) 的 `const realm_table` 模式完全一致
3. **纯查询接口**：所有方法为无副作用查询/计算——不写入 GSM、不发射信号、不持有状态
4. **类比先例**：RealmSystem (ADR-0010) 持有 5×15 项境界属性并以 Core 层 Autoload 运行——FactionSystem 以相同模式持有 18+ 项阵营标签定义。角色完全一致

**需同步更新**：`architecture.md` §系统层映射表格中"阵营系统"应从 Feature 层迁移至 Core 层。

### 采用方案 A：FactionSystem Core 层轻量 Autoload + 标签库 const Dictionary + 实时遍历统计

**FactionSystem** 作为一个 Godot Autoload（`res://src/core/faction_system.gd`），负责：

1. **静态标签库持有**：`FACTION_LIBRARY: Dictionary` —— 所有大阵营、门派、跨阵营标签的定义（tag_id → {name, parent_alignment, is_major, icon}），编译时常量
2. **查询 API**：`get_tag_info(tag_id)` / `get_tags_of_character(character_id)` / `belongs_to_alignment(character_id, alignment)` / 等
3. **场上统计 API**：`count_on_field(alignment_or_tag)` —— 实时遍历上场角色，O(6×3) = O(18) 次标签比较，<0.01ms
4. **条件判定 API**：`check_condition(requirement: Dictionary)` —— 阵法条件判定（如 `{tag_id: "zhengdao", min_count: 3}`）
5. **阵营关系 API**：`is_hostile_to(card_a, card_b)` / `get_alignment_relation(a, b)` —— 基于 parent_alignment 推导
6. **门派推导**：`derive_major_alignment(tag_id)` —— 通过 parent_alignment 映射表，门派标签自动推导大阵营

### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│              CardSystem (ADR-0006) — Autoload                │
│  CardTemplate.faction_tags: Array[StringName]                │
│  CardInstance.template_id → CardTemplate                     │
│  get_field_characters() → Array[CardInstance]                │
└──────────────┬──────────────────────────────────────────────┘
               │ 标签数据来源（只读）
               ▼
┌─────────────────────────────────────────────────────────────┐
│           FactionSystem (ADR-0018) — Autoload                │
│                                                              │
│  FACTION_LIBRARY: Dictionary  ← const 编译时常量              │
│  ┌──────────────┬──────────────┬────────────────┐           │
│  │ 大阵营 (2)    │ 门派 (12+)   │ 跨阵营 (4+)     │           │
│  │ 正道 / 魔道   │ 青云剑宗…    │ 碎星群岛…       │           │
│  └──────────────┴──────────────┴────────────────┘           │
│                                                              │
│  查询 API（所有 O(1) 或 O(场上角色数)）：                     │
│    get_tag_info(tag_id) → Dictionary                         │
│    get_tags_of_character(character_id) → Array[StringName]   │
│    belongs_to_alignment(character_id, alignment) → bool      │
│    derive_major_alignment(tag_id) → StringName               │
│                                                              │
│  统计 API（实时遍历上场角色）：                               │
│    count_on_field(alignment_or_tag) → int                    │
│    get_field_faction_distribution() → Dictionary             │
│                                                              │
│  判定 API：                                                  │
│    check_condition(req: Dictionary) → bool                   │
│    is_hostile_to(card_a, card_b) → bool                      │
│    get_alignment_relation(a, b) → FactionRelation            │
└──────────────┬──────────────────────────────────────────────┘
               │ 直接调用（纯查询——无副作用，无信号）
               ▼
   ┌───────────┬──────────┬──────────┬──────────┬──────────┐
   │  阵法系统  │ 效果引擎  │ 流派系统  │ 探索系统  │ AI 系统  │
   │ count_on_ │is_hostile│get_tags_ │get_tags_ │get_tags_ │
   │ field()   │ _to()    │ of_char()│ of_char()│ of_char()│
   └───────────┴──────────┴──────────┴──────────┴──────────┘
```

### 关键接口

```gdscript
# === FactionSystem Autoload ===
# 路径: res://src/core/faction_system.gd
# 初始化顺序: 在 CardSystem 之后注册（依赖 CardSystem 提供角色标签数据）

enum FactionRelation { SAME = 0, HOSTILE = 1, NEUTRAL = 2 }

## 阵营标签定义库 —— 编译时常量
## 策划在此定义所有阵营标签的元数据
const FACTION_LIBRARY: Dictionary = {
    # --- 大阵营 (is_major=true, parent_alignment=null) ---
    &"zhengdao": {
        name = "正道",
        parent_alignment = &"",        # 大阵营自身无父级
        is_major = true,
        icon = "res://assets/icons/factions/zhengdao.png",
        color = Color(0.29, 0.62, 0.43),   # 青金色 #4A9E6E
    },
    &"modao": {
        name = "魔道",
        parent_alignment = &"",
        is_major = true,
        icon = "res://assets/icons/factions/modao.png",
        color = Color(0.75, 0.22, 0.17),   # 赤紫色 #C0392B
    },

    # --- 正道门派 (parent_alignment="zhengdao") ---
    &"qixuanmen": {
        name = "青云剑宗", parent_alignment = &"zhengdao", is_major = false,
        icon = "res://assets/icons/factions/qixuanmen.png",
    },
    &"dangxia_valley": {
        name = "丹霞谷", parent_alignment = &"zhengdao", is_major = false,
        icon = "res://assets/icons/factions/dangxia_valley.png",
    },
    &"xuanbing_palace": {
        name = "玄冰宫", parent_alignment = &"zhengdao", is_major = false,
        icon = "res://assets/icons/factions/xuanbing_palace.png",
    },
    &"dongyu": {
        name = "东域", parent_alignment = &"zhengdao", is_major = false,
        icon = "res://assets/icons/factions/dongyu.png",
    },
    &"xingdou_sect": {
        name = "星斗宗", parent_alignment = &"zhengdao", is_major = false,
        icon = "res://assets/icons/factions/xingdou_sect.png",
    },
    &"wei_family": {
        name = "卫家", parent_alignment = &"zhengdao", is_major = false,
        icon = "res://assets/icons/factions/wei_family.png",
    },

    # --- 魔道门派 (parent_alignment="modao") ---
    &"xuehai_temple": {
        name = "血海殿", parent_alignment = &"modao", is_major = false,
        icon = "res://assets/icons/factions/xuehai_temple.png",
    },
    &"meiying_pavilion": {
        name = "魅影阁", parent_alignment = &"modao", is_major = false,
        icon = "res://assets/icons/factions/meiying_pavilion.png",
    },
    &"samsara_hall": {
        name = "轮回殿", parent_alignment = &"modao", is_major = false,
        icon = "res://assets/icons/factions/samsara_hall.png",
    },
    &"xuesha_cult": {
        name = "血煞教", parent_alignment = &"modao", is_major = false,
        icon = "res://assets/icons/factions/xuesha_cult.png",
    },
    &"heisha_cult": {
        name = "黑煞教", parent_alignment = &"modao", is_major = false,
        icon = "res://assets/icons/factions/heisha_cult.png",
    },
    &"yunmeng": {
        name = "云蒙", parent_alignment = &"modao", is_major = false,
        icon = "res://assets/icons/factions/yunmeng.png",
    },

    # --- 跨阵营中立标签 (parent_alignment=null) ---
    &"suixing_islands": {
        name = "碎星群岛", parent_alignment = &"", is_major = false,
        icon = "res://assets/icons/factions/suixing_islands.png",
    },
    &"guixu_abyss": {
        name = "归墟之境", parent_alignment = &"", is_major = false,
        icon = "res://assets/icons/factions/guixu_abyss.png",
    },
    &"wanxiang_pavilion": {
        name = "万象阁", parent_alignment = &"", is_major = false,
        icon = "res://assets/icons/factions/wanxiang_pavilion.png",
    },
    &"jiyin_island": {
        name = "极阴岛", parent_alignment = &"", is_major = false,
        icon = "res://assets/icons/factions/jiyin_island.png",
    },
}

## 查询标签元数据 —— O(1) 字典查询
func get_tag_info(tag_id: StringName) -> Dictionary:
    if not FACTION_LIBRARY.has(tag_id):
        push_warning("FactionSystem: unknown tag_id '%s'" % tag_id)
        return {}
    return FACTION_LIBRARY[tag_id]

## 获取角色的全部阵营标签
func get_tags_of_character(character_id: int) -> Array[StringName]:
    var template: CardTemplate = CardSystem.get_template_by_instance_id(character_id)
    if template == null:
        return []
    return template.faction_tags

## 获取大阵营标签列表（正道/魔道）
func get_major_alignments() -> Array[StringName]:
    var result: Array[StringName] = []
    for tag_id in FACTION_LIBRARY:
        if FACTION_LIBRARY[tag_id].is_major:
            result.append(tag_id)
    return result

## 门派标签 → 大阵营推导 —— O(1)
func derive_major_alignment(tag_id: StringName) -> StringName:
    var info: Dictionary = get_tag_info(tag_id)
    if info.is_empty():
        return &""
    if info.is_major:
        return tag_id  # 自身就是大阵营
    return info.get("parent_alignment", &"") as StringName

## 角色是否属于某大阵营 —— O(3)
func belongs_to_alignment(character_id: int, alignment: StringName) -> bool:
    var tags: Array[StringName] = get_tags_of_character(character_id)
    for tag in tags:
        if derive_major_alignment(tag) == alignment:
            return true
    return false

## 场上某阵营/标签的角色数量 —— 实时遍历，O(场上角色数 × 标签数) ≤ O(6×3)
func count_on_field(tag_or_alignment: StringName) -> int:
    var field_chars: Array = _get_field_characters()
    var count: int = 0
    for char_instance in field_chars:
        var tags: Array[StringName] = get_tags_of_character(char_instance.card_instance_id)
        for tag in tags:
            # 判定逻辑：直接匹配 或 门派推导为大阵营匹配
            if tag == tag_or_alignment or derive_major_alignment(tag) == tag_or_alignment:
                count += 1
                break  # 同一角色只计一次
    return count

## 场上阵营分布完整快照
func get_field_faction_distribution() -> Dictionary:
    var dist: Dictionary = {}
    for tag_id in FACTION_LIBRARY:
        var c: int = count_on_field(tag_id)
        if c > 0:
            dist[tag_id] = c
    return dist

## 阵法条件判定
## requirement 格式: { tag_id: StringName, min_count: int }
func check_condition(requirement: Dictionary) -> bool:
    var tag_id: StringName = requirement.get("tag_id", &"")
    var min_count: int = requirement.get("min_count", 0)
    if tag_id.is_empty():
        return false
    return count_on_field(tag_id) >= min_count

## 阵营敌对判定 —— 基于 parent_alignment 比较
func is_hostile_to(card_a_instance_id: int, card_b_instance_id: int) -> bool:
    return get_alignment_relation(card_a_instance_id, card_b_instance_id) == FactionRelation.HOSTILE

## 阵营关系判定
func get_alignment_relation(a_instance_id: int, b_instance_id: int) -> int:
    var a_tags: Array[StringName] = get_tags_of_character(a_instance_id)
    var b_tags: Array[StringName] = get_tags_of_character(b_instance_id)

    var a_major: StringName = &""
    var b_major: StringName = &""

    for tag in a_tags:
        var derived: StringName = derive_major_alignment(tag)
        if not derived.is_empty():
            a_major = derived
            break
    for tag in b_tags:
        var derived: StringName = derive_major_alignment(tag)
        if not derived.is_empty():
            b_major = derived
            break

    if a_major.is_empty() or b_major.is_empty():
        return FactionRelation.NEUTRAL  # 跨阵营角色 → 中立
    if a_major == b_major:
        return FactionRelation.SAME
    return FactionRelation.HOSTILE

## 内部辅助 —— 获取当前场上存活角色列表
func _get_field_characters() -> Array:
    if not is_instance_valid(CardSystem):
        return []
    return CardSystem.get_field_characters()
```

### 接口契约

| 接口 | 签名 | 调用方 | 分类 (ADR-0007) |
|------|------|--------|-----------------|
| 标签查询 | `get_tag_info(tag_id) → Dictionary` | 所有消费者 | 直接调用（纯查询） |
| 角色标签 | `get_tags_of_character(id) → Array[StringName]` | 流派/探索/AI/效果引擎 | 直接调用（纯查询） |
| 大阵营推导 | `derive_major_alignment(tag_id) → StringName` | 内部 + 效果引擎 | 直接调用（纯查询） |
| 阵营归属 | `belongs_to_alignment(id, alignment) → bool` | 效果引擎/阵法 | 直接调用（纯查询） |
| 场上统计 | `count_on_field(tag) → int` | 阵法系统 | 直接调用（纯查询） |
| 阵法判定 | `check_condition(req) → bool` | 阵法系统 | 直接调用（纯查询） |
| 敌对判定 | `is_hostile_to(a, b) → bool` | 效果引擎 | 直接调用（纯查询） |
| 关系判定 | `get_alignment_relation(a, b) → int` | 效果引擎/AI | 直接调用（纯查询） |

**信号策略**：FactionSystem 不发射任何自有信号。阵营分布变化是上场/阵亡事件的结果——由 DeploymentSystem 的 `character_deployed` / `character_withdrawn` 和 CombatSystem 的 `character_died` 信号驱动。需要响应阵营变化的消费者（如阵法系统）**监听这些 Deployment/Combat 信号，在收到信号后主动调用 FactionSystem 的查询接口重新判定**。这一模式与 ADR-0007 的"直接调用决策矩阵"一致——纯查询接口不需要信号包装。

### 实时遍历 vs 缓存——性能论证

场上角色上限 6 人，每人最多 3 个标签。最坏情况遍历：6 × 3 = 18 次标签比较。每次比较是一次 `StringName` 判等（Godot 中 `StringName` 判等是 O(1) 指针比较）。18 次比较的总耗时 < 0.001ms。在 16.6ms 帧预算中，即使每帧调用 10 次 `count_on_field()`，总计 < 0.01ms——可忽略不计。

## 考虑的替代方案

### 替代方案 B：仅嵌入 CardSystem —— 阵营判定作为 CardSystem 的方法

- **描述**：所有阵营判定接口（`count_on_field`、`is_hostile_to`、`belongs_to_alignment`）作为 CardSystem 的扩展方法。不创建独立的 FactionSystem Autoload。标签库字典嵌入 CardSystem。
- **优点**：
  - 不增加 Autoload 数量
  - 标签数据（CardTemplate.faction_tags）和判定逻辑在同一系统中——无跨 Autoload 调用开销
  - 实现简单——不需要额外的初始化顺序管理
- **缺点**：
  - CardSystem 职责膨胀——它已经是模板注册表 + 实例工厂 + 收藏管理（ADR-0006 约 300 行核心逻辑）。加上阵营标签库 + 统计 + 敌对判定 + 条件判定，违反单一职责原则
  - 阵营判定涉及"场上角色列表"——这是 DeploymentSystem 的概念，不是 CardSystem 的概念。CardSystem 本不应知道"上场"语义
  - `architecture.md` 已将阵营系统列为独立系统——嵌入 CardSystem 在概念上与架构设计意图不一致
  - 未来若新增阵营动态变化（如剧情事件"堕入魔道"修改角色阵营标签），嵌入 CardSystem 会使修改波及面更大——修改 CardSystem（Foundation 依赖）比修改独立 FactionSystem（Core 层）风险更高
- **拒绝原因**：阵营系统有独立的标签库（18+ 定义项）和独立的判定规则（敌对/中立/同阵营三层关系）。将这些逻辑堆入 CardSystem 违反单一职责原则。CardSystem 的职责是"卡牌数据是什么"，阵营系统的职责是"卡牌的阵营身份意味着什么"——两者是不同的概念边界。

### 替代方案 C：基于信号的实时缓存 —— 维护阵营计数器，由部署/阵亡事件驱动更新

- **描述**：FactionSystem 内部维护 `_ field _counts: Dictionary`（tag_id → int）。监听 DeploymentSystem 的 `character_deployed` / `character_withdrawn` 信号和 CombatSystem 的 `character_died` 信号，在信号处理器中更新计数器。`count_on_field()` 直接返回缓存值（O(1)）。
- **优点**：
  - 查询 O(1) —— 无需遍历
  - 计数器始终热备——适合高频查询场景
- **缺点**：
  - **一致性问题**：缓存是冗余状态——如果某个系统在不发射信号的情况下修改场上角色列表，缓存将漂移。例如：战斗中"暂时离场"效果（非阵亡）如果绕过了 DeploymentSystem 信号，计数器不会更新
  - **启动/恢复时需要重建**：从存档加载后，需要遍历所有场上角色初始化计数器——逻辑上与实时遍历等同，但多了一套初始化代码
  - **信号连接管理复杂**：FactionSystem 需要确保与 DeploymentSystem 和 CombatSystem 的信号连接在两者就绪后才建立——增加了初始化顺序依赖
  - **过度工程化**：场上角色 ≤6 人，遍历成本 < 0.001ms。为消除 0.001ms 开销而引入 50+ 行缓存维护代码，是负收益的优化
- **拒绝原因**：实时遍历方案在 O(6×3) = 18 次比较下已经是 O(1) 级别的实际开销。维护缓存引入的状态一致性问题（信号遗漏、加载恢复、暂时离场）的复杂度远超其消除的遍历开销。遵循"不做过早优化"原则——当场上角色上限增长到 50+ 时再考虑缓存策略。

### 替代方案 D：非 Autoload 服务 —— RefCounted 纯工具类 + CardSystem 持有共享实例

- **描述**：FactionData 作为 `class_name FactionData extends RefCounted` 工具类。CardSystem 在 `_ready()` 中创建一个实例并通过 `CardSystem.faction_data` 暴露。消费者通过 `CardSystem.faction_data.count_on_field()` 调用。
- **优点**：
  - 不占用 Autoload 槽位
  - 可测试性更好——测试中可创建独立 FactionData 实例
- **缺点**：
  - 消费者必须通过 CardSystem 间接访问——`CardSystem.faction_data.count_on_field()` 而非 `FactionSystem.count_on_field()`——增加间接层级
  - 如果 CardSystem 被重新加载，FactionData 实例丢失——RefCounted 的生命周期绑定到持有者
  - `const FACTION_LIBRARY` 类变量在所有实例间共享——多个 `FactionData.new()` 不会复制数据，但暴露方式不如 Autoload 直接
- **拒绝原因**：阵营系统有 5+ 个消费者，需要一个项目级别的单一访问点。在 GDScript 中，这天然对应 Autoload。`class_name` 工具类适合消费者少于 2 个的场景。FactionSystem 与 RealmSystem (ADR-0010) 的模式完全一致——同为静态数据表 + 纯查询接口，采用一致的模式降低认知负担。

## 后果

### 积极的

- **单一真理来源**：`FACTION_LIBRARY` 是阵营标签元数据的唯一定义点。门派名称、图标路径、parent_alignment 映射——所有消费者通过 FactionSystem 查询，杜绝跨 GDD 重复定义
- **O(1) 标签库查询**：`const Dictionary` 编译时分配，运行时零加载开销。`get_tag_info()` / `derive_major_alignment()` 均为 O(1) 字典查询
- **关注点分离**：CardSystem 管理"卡牌的数据"（faction_tags 字段是数据），FactionSystem 管理"阵营的含义"（标签库元数据 + 判定规则 + 推导逻辑）。修改阵营判定规则不触及 CardSystem
- **阵营推导自动化**：消费者查询"正道人数"时，FactionSystem 自动将门派标签（青云剑宗、丹霞谷…）推导为大阵营正道并计入——消费者无需手动展开门派列表。新增门派只需在 `FACTION_LIBRARY` 中添加定义条目
- **无缓存一致性问题**：实时遍历消除了缓存漂移风险。阵亡角色自动不计入（因为不在场上角色列表中）
- **与 RealmSystem 模式一致**：两者均为 Core 层 Autoload + const Dictionary + 纯查询接口 + 无自有信号——降低团队认知负担

### 消极的

- **增加 1 个 Autoload**：FactionSystem 为 Autoload #15——项目 Autoload 总计 25 个（见 `production/session-state/active.md` Autoload 全链）。FactionSystem 仅持有 18+ 条目的 const Dictionary——不显著增加初始化开销
- **初始化顺序依赖**：FactionSystem 的 `_ready()` 必须在 CardSystem 的 `_ready()` 之后——因为 `get_tags_of_character()` 通过 CardSystem 查询模板。需在 `project.godot` 中确保 FactionSystem 列在 CardSystem 之后
- **遍历查询无法缓存单次调用结果**：连续多次 `count_on_field("zhengdao")` 在同一帧内会重复遍历场上角色——每次 O(6×3)。调用方如需多次使用同一统计结果，应自行缓存返回值。框架不介入优化——遵循"调用方负责"原则

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Autoload 数量持续增长 | 中 | 启动时间增加、初始化顺序复杂度 | 当前 25 个已超过 20 警戒线。本 ADR 的"Autoload 扩容"风险已明确记录于 `active.md`。后续 ADR 创建新 Autoload 时需引用本风险并论证为何不可用 RefCounted 替代 |
| `FACTION_LIBRARY` 内容被意外修改 | 低 | 运行时数据损坏 | 团队约定：仅通过 `get_tag_info()` 读取，禁止直接写入 `FACTION_LIBRARY` 内容。GUT 冒烟测试在 `_ready()` 中验证 `FACTION_LIBRARY["zhengdao"].name == "正道"` |
| CardTemplate.faction_tags 与标签库不同步（标签 ID 在模板中存在但不在库中） | 中 | `derive_major_alignment()` 返回空字符串——该标签在统计中被忽略 | `get_tag_info()` 无效 tag_id 时触发 `push_warning()`——开发阶段可见。建议增加启动时全量校验：遍历所有 CardTemplate 的 faction_tags，对每个 tag_id 检查是否存在于 FACTION_LIBRARY |
| 场上角色遍历遗漏"暂时离场"角色 | 低 | 阵营统计与实际不一致 | 阵营统计依赖 `CardSystem.get_field_characters()`——此方法由 DeploymentSystem 维护。若 DeploymentSystem 正确排除暂时离场角色，阵营统计自动正确。与 DeploymentSystem 的契约由集成测试覆盖 |
| 阵营标签库不支持动态变化（如剧情事件"堕入魔道"修改角色阵营） | 低 | 未来需求变更时需要重构 | GDD §待解决问题 #1 明确将此列为未来叙事系统的开放问题。当前设计为静态标签——角色标签在数据中固定。若未来需要动态变化，可通过 CardInstance 上新增 `runtime_faction_overrides: Array[StringName]` 字段实现——不影响 FactionSystem 核心查询逻辑 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| faction-system.md | §1 阵营标签结构——两层标签体系（大阵营 + 门派 + 跨阵营） | `FACTION_LIBRARY` const Dictionary 定义所有标签元数据，含 parent_alignment 映射实现两层推导 |
| faction-system.md | §2 角色阵营分配规则——最多 3 标签、正魔不可同体 | 通过 CardTemplate.faction_tags 存储（ADR-0006 已定义）。正魔同体校验在数据加载阶段由 CardSystem 执行——非 FactionSystem 运行时职责 |
| faction-system.md | §3 阵营判定接口——get_tags / has_tag / belongs_to_alignment / count_on_field / check_condition / is_hostile_to | 全部八个接口在本 ADR 中定义，与 GDD §3 一一对应 |
| faction-system.md | §4 阵营 buff 叠加规则——不同阵营来源 buff 可共存 | FactionSystem 提供判定接口（count_on_field / check_condition）——buff 叠加逻辑由阵法系统/效果引擎实现，不在 FactionSystem 中 |
| faction-system.md | §5 阵营对卡牌效果的影响——伤害加成/免疫/被动增益/限制条件 | `is_hostile_to()` 和 `belongs_to_alignment()` 为效果引擎提供判定基础 |
| faction-system.md | §6 阵法与阵营联动——4 种阵法的阵营条件 | `check_condition()` 直接服务于阵法激活判定。`count_on_field()` 为阵法系统提供场上人数查询 |
| faction-system.md | §7 战斗外应用——探索事件、商店折扣、剧情分支 | `get_tags_of_character()` 和 `belongs_to_alignment()` 为探索/叙事系统提供查询接口 |
| faction-system.md | §边缘情况——阵亡不计入、跨阵营角色、正魔不可同体、单角色判定 | 实时遍历自动排除阵亡角色（不在场上列表中）。跨阵营标签 parent_alignment=null → 不贡献大阵营计数。单角色只计一次（break 机制） |
| faction-system.md | §公式——阵营敌对判定（parent_alignment 比较） | `get_alignment_relation()` 实现 GDD §公式 #2 的三层判定逻辑（同阵营/敌对/中立） |
| faction-system.md | §调优参数——角色标签上限=3、阵法条件≥3、敌对伤害基准+20% | 标签上限在 CardTemplate.faction_tags 中通过校验强制（非 FactionSystem 职责）。阵法条件和伤害基准值由阵法系统和效果引擎配置——FactionSystem 只提供判定接口 |

## 性能影响

- **CPU**：`count_on_field()` 最坏情况 < 0.001ms（18 次 StringName 判等）。单帧内即使被多个系统调用 5 次，总计 < 0.005ms——在 16.6ms 帧预算中占 0.03%
- **内存**：`FACTION_LIBRARY` const Dictionary——18+ 条目 × ~200B/条目 ≈ 3.6KB。Autoload 节点本身 ≈ 0.5KB。总计 < 5KB 常驻内存
- **加载时间**：const Dictionary 编译时分配——零运行时加载开销。Autoload `_ready()` 为空
- **网络**：不适用（单机游戏）

## 迁移计划

本 ADR 创建新系统，非修改现有代码。实施顺序：
1. 创建 `res://src/core/faction_system.gd` —— FactionSystem Autoload（const FACTION_LIBRARY + 全部查询/统计/判定 API）
2. 在 `project.godot` 中注册 Autoload —— 排在 CardSystem 之后
3. 与 CardSystem 集成——CardSystem 加载模板后，FactionSystem 运行标签库全量校验
4. 阵法系统实现时：通过 `FactionSystem.count_on_field()` 和 `FactionSystem.check_condition()` 判定激活条件
5. 效果引擎实现时：通过 `FactionSystem.is_hostile_to()` 判定阵营针对性伤害
6. `architecture.md` 更新：阵营系统从 Feature 层迁移至 Core 层

## 验证标准

- **GIVEN** FactionSystem 已初始化，**WHEN** 调用 `get_tag_info(&"zhengdao")`，**THEN** 返回 `{name="正道", is_major=true, ...}`
- **GIVEN** 林渊角色卡（faction_tags=[zhengdao, qixuanmen]），**WHEN** 调用 `belongs_to_alignment(lin_yuan_id, &"zhengdao")`，**THEN** 返回 true
- **GIVEN** 林渊角色卡，**WHEN** 调用 `derive_major_alignment(&"qixuanmen")`，**THEN** 返回 `&"zhengdao"`
- **GIVEN** 场上 3 个正道角色 + 1 个魔道角色，**WHEN** 调用 `count_on_field(&"zhengdao")`，**THEN** 返回 3
- **GIVEN** 场上有青云剑宗角色，**WHEN** 调用 `count_on_field(&"zhengdao")`，**THEN** 门派角色自动计入正道计数
- **GIVEN** 场上正道角色 = 3，**WHEN** 调用 `check_condition({tag_id=&"zhengdao", min_count=3})`，**THEN** 返回 true
- **GIVEN** 场上正道角色 = 2，**WHEN** 同样调用，**THEN** 返回 false
- **GIVEN** 角色 A 为正道、角色 B 为魔道，**WHEN** 调用 `is_hostile_to(a_id, b_id)`，**THEN** 返回 true
- **GIVEN** 角色 A 为正道、角色 B 为碎星群岛（跨阵营），**WHEN** 调用 `is_hostile_to(a_id, b_id)`，**THEN** 返回 false（NEUTRAL）
- **GIVEN** 角色 A 阵亡，**WHEN** 调用 `count_on_field()`，**THEN** 阵亡角色不计入
- **GIVEN** 无效 tag_id，**WHEN** 调用 `get_tag_info(&"nonexistent")`，**THEN** 返回空 Dictionary + push_warning

## 相关决策

- ADR-0001：游戏状态管理器 Autoload 三层 API —— `GSM.battle.field_characters` 为 FactionSystem 提供场上角色列表
- ADR-0006：卡牌数据模型 Template/Iinstance 分离 —— `CardTemplate.faction_tags: Array[StringName]` 字段为阵营数据的运行时来源
- ADR-0007：信号驱动通信三分类体系 —— FactionSystem 为纯查询接口，不发射信号，由 Deployment/Combat 信号驱动消费者重新查询
- ADR-0008：战斗系统 7 阶段状态机 —— 场上角色上限 6 人，阵亡角色自动离场
- ADR-0009：卡牌效果引擎 —— 通过 `is_hostile_to()` / `belongs_to_alignment()` 判定阵营针对性效果
- ADR-0010：境界系统 Core 层轻量 Autoload —— 本 ADR 采用相同模式（const Dictionary + 纯查询接口 + 无自有信号）