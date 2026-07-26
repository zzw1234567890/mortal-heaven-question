# ADR-0028：炼丹炼器系统 — RefCounted + class_name 工具类 + const 配方表 + 委托消费架构

- **Status**: proposed
- **Date**: 2026-07-25
- **Authors**: @zwzhang
- **Reviewers**: -
- **Supersedes**: -
- **Superseded by**: -

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Alchemy & Artifact Crafting |
| **知识风险** | LOW（const Dictionary、RefCounted、RandomNumberGenerator、信号系统——全部自 4.0 起稳定。不依赖 4.4+ 新特性） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——全部 API 自 Godot 4.0 起稳定 |
| **需要验证** | `const Dictionary` 配方表不被运行时修改（GDScript `const` 不冻结嵌套内容——与 ADR-0010、ADR-0019 相同风险）；`RandomNumberGenerator` 独立实例的 PRD 模式与 ADR-0009 一致 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0019（ResourceSystem——灵材消耗 `spend_resource()`、灵材库存查询 `get_resource()`、炼制物拆解折价 `dismantle_crafted_value()`）；ADR-0006（CardSystem——`create_instance()` 创建丹药/法宝卡牌实例、`get_template()` 模板查询）；ADR-0023（DeckEditingSystem——`add_cards_to_deck()` 产出卡牌进入卡组）；ADR-0001（GSM——`player.resources` 灵材数据、`batch_updated` Cat 1 信号传播）；ADR-0010（RealmSystem——境界层级 → 炼丹/炼器等级计算）；ADR-0020（CultivationSystem——大境界突破 → 炼丹等级 +1、境界层级 L 查询） |
| **启用** | 法宝铭刻系统 ADR（铭刻作为炼器产出的后续养成步骤——依赖本 ADR 定义的配方产出物）、卡组编辑系统（炼制产物通过 `add_cards_to_deck` 进入卡组）、HUD/UI 系统（炼制界面展示） |
| **阻塞** | 法宝铭刻系统 ADR——铭刻的输入是炼器产出的法宝卡牌实例，在本 ADR 定义产出路径前铭刻系统的完整数据流不可行。不阻塞上游系统（ResourceSystem、CardSystem、DeckEditingSystem 均已定义） |
| **排序说明** | Feature 层——在 Core 层 ResourceSystem（ADR-0019）、CardSystem（ADR-0006）、RealmSystem（ADR-0010）和 Feature 层 CultivationSystem（ADR-0020）、DeckEditingSystem（ADR-0023）被接受后编写。Autoload 链无需新增——本系统选择 **RefCounted 工具类**模式，不占用 Autoload 槽位。与铭刻系统 ADR 紧密关联——两个 ADR 共享配方模式和灵材消耗接口，但分别决策各自的模块归属 |

## 上下文和问题

### 问题陈述

`alchemy-crafting-system.md` GDD 定义了炼丹炼器系统的完整设计——8 个配方（4 炼丹 + 4 炼器）、品质浮动机制（含重掷风险策略）、丹药效果缩放、法宝白值生成、炼制物拆解折价、化神期「丹道大成」被动能力。但 GDD 关注的是"玩家体验到什么"，本 ADR 需要解决的是"系统如何工程化实现"：

1. **模块归属**：炼丹炼器系统消费 5 个已有系统（ResourceSystem、CardSystem、DeckEditingSystem、RealmSystem、CultivationSystem），自身无运行时持久状态——炼制是瞬间操作（玩家点击→扣灵材→掷品质骰→产出卡牌→写入卡组→完成）。是否需要独立 Autoload？当前 Autoload 链已有 **25 个**（#1 GSM ~ #25 StorySystem），超出 Godot 建议的 20 软上限——新增第 26 个 Autoload 需要更强的论证。
2. **配方数据存储**：8 个配方的灵材消耗、产出稀有度、卡牌类型——是使用 Resource (.tres) 文件（策划可视化编辑）还是 const Dictionary（与 ADR-0019 ResourceSystem 的公式表模式一致）？
3. **品质决定的随机数策略**：`quality_roll` 的随机数生成——是使用全局 `randf()` 还是独立 `RandomNumberGenerator` 实例（与 ADR-0009 PRD 模式一致）？
4. **系统合并 vs 分离**：炼丹、炼器、铭刻三个系统共享配方模式和灵材消耗——是否合并为一个系统？
5. **refine 重掷的状态管理**：品质重掷需要保留"第一次掷骰结果"状态——这个瞬态数据存在哪里？

### 约束

- **25 个 Autoload 现状**：Godot 建议 ≤20 Autoload。当前链 #1~#25。新增 #26 需论证不可替代性——本系统需要证明 RefCounted 工具类模式不适用于其职责
- **GSM 数据所有权不变**：灵材数据存储在 GSM `player.resources.ling_cai.{low,medium,high,top}`——炼制系统不持有数据副本
- **卡牌实例创建必须通过 CardSystem**：ADR-0006 契约——`create_instance(template_id)` 是唯一入口
- **资源写入必须通过 ResourceSystem**：ADR-0019 禁止模式——不直接写 GSM `player.resources.*`
- **品质随机数隔离**：`quality_roll` 不应与战斗 PRD 或探索 RNG 共享全局状态——确保炼制结果可复现测试
- **铭刻系统紧密关联**：铭刻是炼器产出法宝的后续养成步骤——本 ADR 需定义铭刻系统消费的接口契约（产出法宝卡牌的数据模型），但不定义铭刻逻辑本身

### 需求

- 8 个配方的单一真理来源——灵材消耗、产出稀有度、卡牌类型
- 炼制流程编排：校验灵材余额 → 扣减灵材 → 品质掷骰 → 生成卡牌实例 → 写入卡组
- 品质浮动机制：随机掷骰 + 灵材品质加权 + 万象真人加成 + 玩家重掷决策
- 丹药效果缩放和法宝白值生成的公式实现
- 化神期「丹道大成」被动能力的触发判定
- 炼制物 `is_crafted = true` 标记——供 ResourceSystem `dismantle_crafted_value()` 拆解折价判断

## 决策

**炼丹炼器系统作为 RefCounted + class_name 工具类（`AlchemySystem`）实现——持有 8 个配方的 const Dictionary 配方表和 3 条纯函数公式（品质掷骰、丹药效果缩放、法宝属性生成），通过 CardSystem.create_instance() 产出卡牌实例，通过 ResourceSystem.spend_resource() 消费灵材，通过 DeckEditingSystem.add_cards_to_deck() 写入卡组。自身不持有任何运行时持久状态，不注册 Autoload（不占用 #26 槽位）。**

### 层分类决议：Feature 层论证

炼丹炼器系统不是 Foundation 层（依赖 GSM），不是 Core 层（不是被 8+ 个系统消费的基础设施——仅有 HUD/UI 和铭刻系统两个消费者）。它是典型的 Feature 层"垂直功能"——编排多个底层系统完成"灵材→卡牌"这一特定玩家体验。与 AISystem（#18，编排敌方行为）和 CombatSystem（#9，编排战斗流程）属于同一层级。

**关键区别**：与 CombatSystem（#9 Autoload——有运行时状态机 `CombatPhase`）、DeckEditingSystem（#22 Autoload——有 `session_remove_count` 跨场景持久状态）不同，炼丹炼器系统**无运行时持久状态**——炼制是瞬间操作（玩家点击 → 扣灵材 → 掷骰 → 产出卡牌 → 完成），所有数据在操作完成后即持久化到 GSM（通过 ResourceSystem 和 CardSystem）。唯一的瞬态数据是品质重掷的第一次掷骰结果——这不需要 Autoload 的生命周期管理，由炼制流程的本地变量承载即可。

### 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                    GSM (ADR-0001)                             │
│  player.resources.ling_cai.{low, medium, high, top}: int      │
│  batch_updated(changes) → Cat 1 信号                          │
└──────────────┬───────────────────────────────────────────────┘
               │ 数据存储所有权
               ▼
┌──────────────────────────────────────────────────────────────┐
│   ResourceSystem (#16 Autoload)          CardSystem (#6)      │
│   spend_resource("ling_cai", qty, quality)  create_instance() │
│   get_resource("ling_cai", quality)         get_template()    │
│   can_spend(...)                                              │
└──────────────┬──────────────────────────────┬────────────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────────────────────────────────────────┐
│          AlchemySystem (RefCounted + class_name)              │
│                                                               │
│  ┌─ 配方表（const Dictionary，编译时常量）──────────────────┐ │
│  │ ALCHEMY_RECIPES = {                                      │ │
│  │   "hui_chun_dan": {materials: {LOW:2}, rarity:2, ...},   │ │
│  │   "yu_ling_dan":  {materials: {MEDIUM:2, LOW:1}, ...},   │ │
│  │   ...                                                    │ │
│  │ }                                                        │ │
│  │ ARTIFACT_RECIPES = { ... }                               │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─ 公式 API（纯函数，不修改状态，不发射信号）──────────────┐ │
│  │ quality_roll(recipe_base, alchemy_level, bonuses, rng)    │ │
│  │ quality_reroll(recipe_base, alchemy_level, bonuses, rng)  │ │
│  │ pill_effect(base_value, quality_mod, bonus_pct)           │ │
│  │ forge_artifact_stat(rarity, quality_mod)                  │ │
│  │ jindan_cumulative_threshold(craft_count)                  │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─ 炼制编排（消费 ResourceSystem + CardSystem）────────────┐ │
│  │ craft_recipe(recipe_id, quality_bonuses, rng) → result    │ │
│  │   ├→ ResourceSystem.spend_resource()  # 扣灵材            │ │
│  │   ├→ quality_roll()                   # 品质掷骰          │ │
│  │   ├→ CardSystem.create_instance()     # 创建卡牌实例      │ │
│  │   └→ DeckEditingSystem.add_cards_to_deck() # 写入卡组    │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────┬──────────────────────────────────────────────┘
               │ 产出卡牌 → 写入卡组
               ▼
┌──────────────────────────────────────────────────────────────┐
│            DeckEditingSystem (#22 Autoload)                   │
│            add_cards_to_deck([card_id], "craft", detail)      │
└──────────────────────────────────────────────────────────────┘
```

### 关键接口

```gdscript
# === AlchemySystem (RefCounted + class_name) ===
class_name AlchemySystem
extends RefCounted

# === 灵材品质枚举（与 ResourceSystem 的 LingCaiQuality 值一致） ===
const LING_CAI_LOW    := 1
const LING_CAI_MEDIUM := 2
const LING_CAI_HIGH   := 3
const LING_CAI_TOP    := 4

# === 稀有度常量 ===
const RARITY_WHITE     := 1
const RARITY_BLUE      := 2
const RARITY_PURPLE    := 3
const RARITY_GOLD      := 4
const RARITY_DARK_GOLD := 5

# === 配方表（const Dictionary——编译时常量） ===

const ALCHEMY_RECIPES: Dictionary = {
  "hui_chun_dan": {
    "name": "回春丹",
    "materials": {LING_CAI_LOW: 2},
    "rarity": RARITY_BLUE,
    "card_type": "pill",
    "template_id": "pill_hui_chun_dan",   # 对应 CardTemplate.card_id
    "base_effect": 4,                      # 基础回复 HP
    "unlock_level": 0,                     # 所需炼丹等级
    "stack_limit": 3,                      # 丹药卡 stack_limit
  },
  "yu_ling_dan": {
    "name": "玉灵丹",
    "materials": {LING_CAI_MEDIUM: 2, LING_CAI_LOW: 1},
    "rarity": RARITY_PURPLE,
    "card_type": "pill",
    "template_id": "pill_yu_ling_dan",
    "base_effect": 8,
    "unlock_level": 1,
    "stack_limit": 3,
  },
  "tian_luo_dan": {
    "name": "天罗丹",
    "materials": {LING_CAI_HIGH: 2, LING_CAI_MEDIUM: 1},
    "rarity": RARITY_GOLD,
    "card_type": "pill",
    "template_id": "pill_tian_luo_dan",
    "base_effect": 6,
    "unlock_level": 2,
    "stack_limit": 3,
  },
  "jiu_zhuan_jin_dan": {
    "name": "九转金丹",
    "materials": {LING_CAI_TOP: 2, LING_CAI_HIGH: 1},
    "rarity": RARITY_DARK_GOLD,
    "card_type": "pill",
    "template_id": "pill_jiu_zhuan_jin_dan",
    "base_effect": 1,                     # 永久 +1 最大 HP
    "unlock_level": 3,
    "stack_limit": 1,
  },
}

const ARTIFACT_RECIPES: Dictionary = {
  "ji_chu_fa_qi": {
    "name": "基础法器",
    "materials": {LING_CAI_LOW: 3},
    "rarity": RARITY_BLUE,
    "card_type": "artifact",
    "template_id": "artifact_ji_chu_fa_qi",
    "base_atk": 3,    # 未使用 quality_mod 时的基准值——实际由 forge_artifact_stat 生成
    "base_def": 2,
    "unlock_level": 0,
  },
  "zhong_pin_fa_qi": {
    "name": "中品法器",
    "materials": {LING_CAI_MEDIUM: 3},
    "rarity": RARITY_PURPLE,
    "card_type": "artifact",
    "template_id": "artifact_zhong_pin_fa_qi",
    "base_atk": 4,
    "base_def": 3,
    "unlock_level": 1,
  },
  "shang_pin_fa_qi": {
    "name": "上品法器",
    "materials": {LING_CAI_HIGH: 3},
    "rarity": RARITY_GOLD,
    "card_type": "artifact",
    "template_id": "artifact_shang_pin_fa_qi",
    "base_atk": 6,
    "base_def": 5,
    "unlock_level": 2,
  },
  "tong_tian_ling_bao": {
    "name": "通天灵宝",
    "materials": {LING_CAI_TOP: 3, LING_CAI_HIGH: 1},
    "rarity": RARITY_DARK_GOLD,
    "card_type": "artifact",
    "template_id": "artifact_tong_tian_ling_bao",
    "base_atk": 10,
    "base_def": 8,
    "unlock_level": 3,
  },
}

# === 品质倍率映射 ===
const QUALITY_MOD = {DOWNGRADE: 0.8, STANDARD: 1.0, UPGRADE: 1.3}

# === 炼制结果枚举 ===
enum CraftResult { SUCCESS, INSUFFICIENT_MATERIALS, RECIPE_LOCKED, INVALID_RECIPE }

# === 品质掷骰结果枚举 ===
enum QualityOutcome { DOWNGRADE = -1, STANDARD = 0, UPGRADE = 1 }


# === 公式 API（纯函数——不修改状态，不发射信号）===

## 品质掷骰——首次掷骰
## @param recipe_base_rarity: int [1, 5]——配方基础稀有度
## @param alchemy_level: int [0, 4]——当前炼丹/炼器等级
## @param bonuses: float——外部加成（万象真人 +0.15 + 材料溢出每槽 +0.10）
## @param rng: RandomNumberGenerator——独立 RNG 实例
## @return QualityOutcome——DOWNGRADE / STANDARD / UPGRADE
static func quality_roll(recipe_base_rarity: int, alchemy_level: int, bonuses: float, rng: RandomNumberGenerator) -> QualityOutcome:
    var high_chance: float = minf(0.10 + alchemy_level * 0.05 + bonuses, 0.8)
    var low_chance: float = 0.1 if recipe_base_rarity > 1 else 0.0
    var roll: float = rng.randf()
    if roll < low_chance:
        return QualityOutcome.DOWNGRADE
    if roll < low_chance + high_chance:
        return QualityOutcome.UPGRADE
    return QualityOutcome.STANDARD

## 品质重掷——玩家选择重掷后的掷骰
## 升品概率 +15%，降品概率升至 25%
static func quality_reroll(recipe_base_rarity: int, alchemy_level: int, bonuses: float, rng: RandomNumberGenerator) -> QualityOutcome:
    var high_chance: float = minf(0.10 + alchemy_level * 0.05 + bonuses + 0.15, 0.8)
    var low_chance: float = 0.25 if recipe_base_rarity > 1 else 0.0
    var roll: float = rng.randf()
    if roll < low_chance:
        return QualityOutcome.DOWNGRADE
    if roll < low_chance + high_chance:
        return QualityOutcome.UPGRADE
    return QualityOutcome.STANDARD

## 丹药效果缩放
## @param base_value: int——配方基础效果值
## @param quality_mod: float——品质倍率 {0.8, 1.0, 1.3}
## @param bonus_pct: float——炼丹精通加成（炼丹等级≥2时+0.1，其余 0）
## @return int——最终效果值（至少 1）
static func pill_effect(base_value: int, quality_mod: float, bonus_pct: float) -> int:
    return maxi(1, floori(base_value * quality_mod * (1.0 + bonus_pct)))

## 法宝属性生成
## @param rarity: int [1, 5]——产出稀有度索引（白=1→暗金=5）
## @param quality_mod: float——品质倍率 {0.8, 1.0, 1.3}
## @return Dictionary {atk: int, def: int}
static func forge_artifact_stat(rarity: int, quality_mod: float) -> Dictionary:
    const BASE_ATK := [1, 3, 4, 6, 10]   # 白→暗金
    const BASE_DEF := [1, 2, 3, 5, 8]    # 白→暗金
    var idx: int = clampi(rarity, 1, 5) - 1
    return {
        "atk": maxi(1, floori(BASE_ATK[idx] * quality_mod)),
        "def": maxi(0, floori(BASE_DEF[idx] * quality_mod)),
    }

## 九转金丹累积阈值——计算第 N 次 +1HP 所需累计炼制颗数
static func jindan_cumulative_threshold(craft_count: int) -> int:
    return craft_count * (craft_count + 1) / 2

## 获取品质修改后的稀有度
## @param recipe_base_rarity: int——配方基础稀有度
## @param outcome: QualityOutcome——品质掷骰结果
## @return int——最终稀有度（钳制在 [1, 5]）
static func resolve_final_rarity(recipe_base_rarity: int, outcome: QualityOutcome) -> int:
    match outcome:
        QualityOutcome.DOWNGRADE:
            return maxi(recipe_base_rarity - 1, 1)
        QualityOutcome.UPGRADE:
            return mini(recipe_base_rarity + 1, 5)
        _:  # STANDARD
            return recipe_base_rarity


# === 炼制编排（消费 ResourceSystem + CardSystem + DeckEditingSystem）===

## 执行炼丹——完整编排流程
## @param recipe_id: String——配方键（如 "hui_chun_dan"）
## @param quality_bonuses: float——外部品质加成
## @param rng: RandomNumberGenerator——独立 RNG 实例
## @param is_dadao_active: bool——化神期「丹道大成」是否可用（本局首次=必升品）
## @return Dictionary {result: CraftResult, first_roll: QualityOutcome|null, card_instance_id: int, ...}
static func craft_pill(recipe_id: String, quality_bonuses: float, rng: RandomNumberGenerator, is_dadao_active: bool = false) -> Dictionary:
    # 1. 查配方
    var recipe: Dictionary = ALCHEMY_RECIPES.get(recipe_id, {})
    if recipe.is_empty():
        return {"result": CraftResult.INVALID_RECIPE}
    
    # 2. 检查解锁
    var alchemy_level: int = _get_alchemy_level()
    if alchemy_level < recipe.unlock_level:
        return {"result": CraftResult.RECIPE_LOCKED}
    
    # 3. 校验灵材余额并扣减
    for quality in recipe.materials:
        var qty: int = recipe.materials[quality]
        if not ResourceSystem.can_spend("ling_cai", qty, quality):
            return {"result": CraftResult.INSUFFICIENT_MATERIALS}
    for quality in recipe.materials:
        ResourceSystem.spend_resource("ling_cai", recipe.materials[quality], quality)
    
    # 4. 品质掷骰
    var outcome: int
    if is_dadao_active:
        outcome = QualityOutcome.UPGRADE  # 丹道大成——跳过掷骰，必升品
    else:
        outcome = quality_roll(recipe.rarity, alchemy_level, quality_bonuses, rng)
    
    # 5. 生成卡牌实例
    var final_rarity: int = resolve_final_rarity(recipe.rarity, outcome)
    var inst: CardInstance = CardSystem.create_instance(recipe.template_id)
    # 丹药实例的稀有度和效果由炼制结果决定——覆盖模板默认值（模板稀有度为配方基准，实例稀有度可不同）
    _apply_pill_instance_data(inst, recipe, final_rarity, outcome, alchemy_level)
    
    # 6. 序列化并写入卡组
    var inst_dict: Dictionary = CardSystem.serialize_instance(inst)
    DeckEditingSystem.add_cards_to_deck([inst_dict.card_instance_id], "craft", recipe.name)
    
    return {
        "result": CraftResult.SUCCESS,
        "first_roll": outcome,
        "card_instance_id": inst.card_instance_id,
        "final_rarity": final_rarity,
        "quality_mod": _quality_mod_from_outcome(outcome),
    }

## 执行炼器——与炼丹相同的编排流程
static func craft_artifact(recipe_id: String, quality_bonuses: float, rng: RandomNumberGenerator, is_dadao_active: bool = false) -> Dictionary:
    # 结构同 craft_pill——使用 ARTIFACT_RECIPES 和 forge_artifact_stat
    var recipe: Dictionary = ARTIFACT_RECIPES.get(recipe_id, {})
    if recipe.is_empty():
        return {"result": CraftResult.INVALID_RECIPE}
    
    var alchemy_level: int = _get_alchemy_level()
    if alchemy_level < recipe.unlock_level:
        return {"result": CraftResult.RECIPE_LOCKED}
    
    for quality in recipe.materials:
        var qty: int = recipe.materials[quality]
        if not ResourceSystem.can_spend("ling_cai", qty, quality):
            return {"result": CraftResult.INSUFFICIENT_MATERIALS}
    for quality in recipe.materials:
        ResourceSystem.spend_resource("ling_cai", recipe.materials[quality], quality)
    
    var outcome: int
    if is_dadao_active:
        outcome = QualityOutcome.UPGRADE
    else:
        outcome = quality_roll(recipe.rarity, alchemy_level, quality_bonuses, rng)
    
    var final_rarity: int = resolve_final_rarity(recipe.rarity, outcome)
    var inst: CardInstance = CardSystem.create_instance(recipe.template_id)
    _apply_artifact_instance_data(inst, recipe, final_rarity, outcome)
    
    var inst_dict: Dictionary = CardSystem.serialize_instance(inst)
    DeckEditingSystem.add_cards_to_deck([inst_dict.card_instance_id], "craft", recipe.name)
    
    return {
        "result": CraftResult.SUCCESS,
        "first_roll": outcome,
        "card_instance_id": inst.card_instance_id,
        "final_rarity": final_rarity,
    }

# === 品质重掷（玩家交互后的二次掷骰）===
## 重掷——在 craft_pill/artifact 返回 first_roll 后，玩家选择重掷时调用
## 灵材已在首次炼制时扣除——重掷不额外消耗灵材
static func apply_reroll(recipe_id: String, quality_bonuses: float, rng: RandomNumberGenerator, existing_instance_id: int) -> Dictionary:
    # 1. 查配方
    var recipe: Dictionary = _get_recipe(recipe_id)
    if recipe.is_empty():
        return {"result": CraftResult.INVALID_RECIPE}
    
    # 2. 重掷品质（降品概率 25%，升品概率 +15%）
    var alchemy_level: int = _get_alchemy_level()
    var outcome: int = quality_reroll(recipe.rarity, alchemy_level, quality_bonuses, rng)
    
    # 3. 重新计算稀有度和实例数据——更新已有实例
    var final_rarity: int = resolve_final_rarity(recipe.rarity, outcome)
    # 重掷结果覆盖实例数据——注意：此操作修改 CardInstance 对象，需在 CardSystem 层面支持
    _apply_reroll_to_instance(existing_instance_id, recipe, final_rarity, outcome, alchemy_level)
    
    return {
        "result": CraftResult.SUCCESS,
        "final_roll": outcome,           # 重掷后必须接受结果——无第三次重掷
        "final_rarity": final_rarity,
        "can_reroll": false,             # 重掷后不可再次重掷
    }


# === 炼丹/炼器等级计算（委托 RealmSystem + CultivationSystem）===

## 炼丹/炼器等级 = 境界层级 - 1（炼气 L=1 → 等级 0；化神 L=5 → 等级 4）
static func _get_alchemy_level() -> int:
    var realm_L: int = GSM.player.realm.level  # 境界层级（1=炼气, 2=筑基, 3=金丹, 4=元婴, 5=化神）
    return maxi(0, realm_L - 1)

# === 品质倍率映射 ===
static func _quality_mod_from_outcome(outcome: QualityOutcome) -> float:
    match outcome:
        QualityOutcome.DOWNGRADE: return 0.8
        QualityOutcome.UPGRADE:   return 1.3
        _:                         return 1.0

# === 炼丹精通加成 ===
static func _get_bonus_pct(alchemy_level: int) -> float:
    return 0.1 if alchemy_level >= 2 else 0.0
```

### 炼制流程数据流

```
[玩家点击炼制] → AlchemySystem.craft_pill(recipe_id, bonuses, rng, is_dadao_active)
  │
  ├─ 1. 查 ALCHEMY_RECIPES[recipe_id] → 获取配方数据
  │
  ├─ 2. _get_alchemy_level() → GSM.player.realm.level - 1
  │     ├─ 若 < recipe.unlock_level → 返回 RECIPE_LOCKED
  │     └─ 若 ≥ → 继续
  │
  ├─ 3. ResourceSystem.can_spend("ling_cai", qty, quality) → 校验灵材
  │     └─ 灵材不足 → 返回 INSUFFICIENT_MATERIALS
  │     └─ 灵材充足 → ResourceSystem.spend_resource() 逐品质扣减
  │         └─ GSM._set_resource_ling_cai() → batch_updated 信号
  │
  ├─ 4. quality_roll(recipe.rarity, alchemy_level, bonuses, rng) → QualityOutcome
  │     └─ 若 is_dadao_active → 跳过掷骰，直接 UPGRADE
  │
  ├─ 5. CardSystem.create_instance(recipe.template_id) → CardInstance
  │     └─ GSM.allocate_card_id() → 全局唯一 ID
  │     └─ inst.acquired_method = CRAFT
  │     └─ _apply_pill_instance_data() → 设置稀有度、效果值
  │
  ├─ 6. CardSystem.serialize_instance(inst) → Dictionary
  │     └─ DeckEditingSystem.add_cards_to_deck([card_instance_id], "craft", detail)
  │         └─ GSM._set_deck_cards() → batch_updated 信号
  │
  └─ 7. 返回 {result: SUCCESS, first_roll: outcome, card_instance_id, ...}
        │
        ├─ [玩家选择接受] → 炼制完成，卡牌已入卡组
        │
        └─ [玩家选择重掷] → AlchemySystem.apply_reroll(recipe_id, bonuses, rng, inst_id)
            └─ quality_reroll() → 更新实例数据（必须接受新结果）
```

### 信号传播路径

AlchemySystem 自身**不发射任何 Cat 2b 信号**——炼制的数据变更是通过两个渠道间接传播的：

```
灵材扣减: AlchemySystem → ResourceSystem.spend_resource()
  → GSM._set_resource_ling_cai() → batch_updated({"player.resources.ling_cai.low": {old, new}})
  → HUD 刷新灵材库存

卡牌获得: AlchemySystem → DeckEditingSystem.add_cards_to_deck()
  → GSM._set_deck_cards() → batch_updated({"player.deck.current_deck": {old, new}})
  → HUD 刷新卡组计数 / 卡组查看界面更新
```

炼制结果动画和 UI 反馈由 HUD/UI 系统监听 GSM `batch_updated` 信号后触发——AlchemySystem 只返回结果 Dictionary，不负责 UI 展示。

### 铭刻系统接口契约

本 ADR 定义的炼器产出——法宝卡牌实例——是铭刻系统的输入。铭刻系统 ADR 将依赖以下契约：

| 契约项 | 本 ADR 的保证 | 铭刻系统的消费方式 |
|--------|-------------|------------------|
| 法宝实例存在 | `CardSystem.create_instance()` 产生带 `card_instance_id` 的 CardInstance | 通过 `card_instance_id` 在 GSM 收藏中查询 |
| 法宝类型 = "artifact" | `recipe.card_type == "artifact"` 的配方产出 | 铭刻操作前校验 `template.type == CardType.ARTIFACT` |
| 法宝白值（ATK/DEF） | `forge_artifact_stat()` 生成的攻防值存储在实例数据中 | 铭刻不修改白值——仅附加副属性 |
| `is_crafted = true` 标记 | 实例的 `acquired_method = CRAFT` | 拆解时通过此标记触发炼制物折价（ResourceSystem `dismantle_crafted_value()`） |
| 铭刻消耗灵材公式 | 本 ADR **不定义**铭刻消耗——铭刻系统 GDD 权威定义 `inscribe_cost()` | 铭刻系统 ADR 自行定义——本 ADR 仅提供炼器产出契约 |
| `inscription_count` / `inscriptions` 字段 | 初始值为 0 / []（CardInstance 字段，ADR-0006 已定义） | 铭刻系统 ADR 负责读写这些字段 |

### 实例数据中的炼制标记

CardInstance 的 `acquired_method`（ADR-0006 已定义）在炼制时设置为 `CRAFT`（新增枚举值）。此标记供以下消费者使用：

1. **ResourceSystem `dismantle_crafted_value()`**：拆解时检测 `is_crafted` → 折价 50%
2. **铭刻系统**：铭刻只能在 `acquired_method == CRAFT` 的法宝上进行（铭刻是炼器专属的养成管线）
3. **HUD/UI**：卡牌详情展示"炼制"来源标签
4. **流派系统（SchoolSystem）**：百艺炼丹流 `alchemy_completed` 计数——检测 `acquired_method == CRAFT`

> **ADR-0006 需补充**：在 `acquired_method` 枚举中新增 `CRAFT = 4`（当前枚举：DROP / SHOP / EVENT / CRAFT / TRIBULATION）。

## 考虑的替代方案

### 替代方案 A：独立 Feature 层 Autoload（#26）——与 CombatSystem、DeckEditingSystem 同级

- **描述**：AlchemySystem 作为独立的 Feature 层 Autoload 注册在 #26 位置。持有配方表、炼制流程编排、品质重掷状态管理。所有方法为实例方法（非 static）。
- **优点**：语义清晰——"这是系统级服务"的信号对新人友好。与 CombatSystem（#9）、DeckEditingSystem（#22）的 Feature 层 Autoload 模式一致——统一的学习曲线。品质重掷的瞬态状态可以存储在实例变量中（`_pending_reroll_data: Dictionary`），代码结构自然。
- **缺点**：增加第 26 个 Autoload——Godot 建议 ≤20 Autoload，当前已超出 25%。但实际性能差异可忽略——Autoload 节点常驻内存 <1KB。真正需要 Autoload 的根本论证是：**系统是否有跨场景持久状态需要 Autoload 的生命周期保证？** 炼丹炼器系统的答案是**没有**——炼制是瞬间操作，重掷的瞬态状态在单次炼制流程结束后即销毁。Autoload 的 `_ready()` 为空，`_process()` 为空——为它注册 Autoload 是过度工程化。
- **拒绝原因**：Autoload 的身份应该留给有运行时持久状态（如 CombatSystem 的 `CombatPhase` 状态机、DeckEditingSystem 的 `session_remove_count`）或需要跨场景生命周期管理的系统。炼丹炼器系统两者都不需要。Autoload 不是荣誉徽章——它是需要论证的工程选择。本系统的"瞬间操作"特性更适合 RefCounted 工具类的按需实例化模式。

### 替代方案 B：RefCounted + class_name 工具类（本 ADR 的推荐方案）

- **描述**：`class_name AlchemySystem extends RefCounted`。所有公式方法为 `static func`（纯函数），炼制编排 `craft_pill()` / `craft_artifact()` 为 `static func`（消费 ResourceSystem、CardSystem、DeckEditingSystem）。不注册 Autoload。调用方在需要时直接 `AlchemySystem.craft_pill(...)` 调用。重掷状态由调用方（HUD/UI 系统）管理——`craft_pill()` 返回包含 `first_roll` 的 Dictionary，UI 决定是否重掷，然后调用 `apply_reroll(...)`。
- **优点**：极简——无 Autoload 注册、无 `_ready()`、无 `_process()`、无生命周期管理。Godot 惯用模式——`class_name` 是 Godot 4.x 的原生全局注册表，等价于 C# 的静态类。不占用 Autoload 槽位——25 个已超软上限，不减反增需充分论证。可测试性更好——无需模拟 Autoload 环境，直接实例化 `AlchemySystem.new()` 或调用静态方法。与 ADR-0019 替代方案 B 的评估一致："若未来发现公式服务不需要 Autoload 的生命周期管理，迁移到静态工具类是低成本重构"——本系统天生就是这种情况。
- **缺点**：没有"系统级服务"的语义标识——新开发者可能不熟悉 `class_name` 全局注册表，需要一个"在哪里找炼制逻辑"的引导。重掷瞬态状态不由 AlchemySystem 管理——调用方（HUD/UI）需自己持有 `first_roll` 结果并传递给 `apply_reroll()`。这本质上是关注点分离——UI 持有展示状态，AlchemySystem 持有公式逻辑。
- **评估**：此替代方案完美匹配本系统的特性——纯公式计算 + 委托编排 + 无运行时持久状态。`class_name` 在 Godot 4.6 中是成熟的全局注册机制（`class_name` 直接在 GDScript 中声明，无需手动导入——编译器自动注册到全局命名空间）。重掷状态由 UI 管理的架构选择是干净的——UI 层持有"当前炼制会话"的瞬态上下文，AlchemySystem 是纯粹的逻辑层。

### 替代方案 C：嵌入 ResourceSystem——炼制公式和流程作为 ResourceSystem 的扩展

- **描述**：`craft_pill()` / `craft_artifact()` 作为 ResourceSystem 的方法。配方表作为 ResourceSystem 的 const Dictionary。理由：ResourceSystem 已是灵材的读写入口——炼制本质上就是"灵材消费 + 卡牌产出"。
- **优点**：减少 1 个模块——所有材料经济逻辑在一个类中。灵材消耗和炼制编排的共处简化了调用链（不需要跨类委托）。
- **缺点**：ResourceSystem 的职责是"资源公式 + 灵材读写 API"（ADR-0019）——加入炼丹/炼器配方表 + 品质掷骰公式 + 卡牌实例创建流程会使其从约 150 行膨胀到约 350+ 行——职责漂移。ResourceSystem 作为 Core 层服务需要保持稳定——Feature 层的炼制品级机制（升品/降品/重掷/丹道大成）不应该推入 Core 层。违反单一职责原则——ResourceSystem 是"钱"，AlchemySystem 是"工厂"——钱不应该知道工厂怎么生产产品。
- **拒绝原因**：ADR-0019 已明确 ResourceSystem 的边界——公式服务 + 类型安全读写。炼制是 Feature 层编排逻辑——它协调 ResourceSystem（扣钱）、CardSystem（造卡）、DeckEditingSystem（入库）完成一个完整的玩家体验。将这个流程推入 ResourceSystem 会使 Core 层变得不稳定。

### 替代方案 D：炼丹 + 炼器 + 铭刻合并为一个系统

- **描述**：将炼丹、炼器、铭刻三个系统合并为一个 `CraftingAndInscriptionSystem` Autoload。理由：三个系统共享配方模式和灵材消耗——合并减少模块数量。
- **优点**：减少 2 个模块——配方表统一管理，灵材消耗路径唯一。铭刻的递增成本逻辑与炼制的配方成本逻辑可以共享同一个消耗抽象。
- **缺点**：铭刻系统有跨场景持久状态——`inscription_count` 和 `total_materials_spent` 需要在法宝拆解时精确计算返还灵材。铭刻候选生成（`generate_candidates()`）是独立的复杂算法——权重表 + 境界加成 + 已有属性惩罚 + 不放回抽取——与炼丹的品质掷骰逻辑合并会形成约 500+ 行的单文件。炼丹（瞬间操作）和铭刻（法宝养成深度）的玩家体验完全不同——合并使一个模块同时处理"一次性创造"和"反复养成"两种不同的设计意图。
- **拒绝原因**：GDD 已明确炼丹炼器系统与法宝铭刻系统为两个独立系统——铭刻 GDD §依赖关系明确定义了"炼丹炼器系统 → 法宝铭刻系统（终端系统）"的顺序。合并违反 GDD 设计意图。且铭刻系统的 Autoload vs RefCounted 决策应独立评估——铭刻有跨场景持久状态（`total_materials_spent`），与炼丹的无状态特性不同。预判铭刻的模块选择是不必要的耦合——让铭刻 ADR 自己做决定。

## 后果

### 积极的

- **不增加 Autoload 数量**：保持 25 个 Autoload——不进一步超出 Godot 软上限。AlchemySystem 作为 `class_name` 的全局注册机制在性能上与 Autoload 无差异（编译时注册到全局命名空间，调用开销等价于静态函数）
- **纯函数可测试性强**：`quality_roll()`、`pill_effect()`、`forge_artifact_stat()` 全部为 `static func`——无需模拟任何 Autoload 或场景树。GUT 测试直接调用静态方法，注入虚拟 RNG 实例（`RandomNumberGenerator.seed = 42`）
- **配方表唯一真理来源**：8 个配方的灵材消耗、产出稀有度、解锁等级在 `ALCHEMY_RECIPES` 和 `ARTIFACT_RECIPES` const Dictionary 中唯一定义——策划调参修改一处，所有消费方自动生效
- **与 ADR-0019 的 ResourceSystem 模式一致**：const Dictionary 公式表 + 纯查询 API + 委托 GSM 读写——开发者学习 ResourceSystem 模式即可理解 AlchemySystem
- **铭刻系统接口清晰**：本 ADR 明确炼器产出契约——铭刻系统 ADR 可独立编写，不耦合于炼丹炼器的内部实现
- **信号合规**：AlchemySystem 自身不发射 Cat 2b 信号——灵材扣减和卡组变更均通过 ResourceSystem 和 DeckEditingSystem 委托 GSM `batch_updated`（Cat 1）传播（ADR-0007 禁止模式 #11——不重复 GSM 信号）
- **质量掷骰 RNG 隔离**：`quality_roll` 接受 `RandomNumberGenerator` 参数——调用方注入独立 RNG 实例（不共享战斗 PRD 或探索 RNG 的全局状态）。与 ADR-0009（卡牌效果引擎 PRD 模式）一致。单元测试可通过 `rng.seed = 42` 实现确定性复现

### 消极的

- **调用方需要同时了解 4 个系统**：炼制操作需要 AlchemySystem（配方+公式）+ ResourceSystem（灵材查询）+ CardSystem（卡牌模板显示）+ DeckEditingSystem（卡组查看）。HUD/UI 系统需要协调 4 个入口——增加了 UI 层的认知负载。缓解：文档明确"炼制流程用 AlchemySystem.craft_pill()——内部自动处理灵材扣减和卡组写入"
- **重掷状态管理由 UI 负责**：第一次掷骰的结果（`first_roll`）由 HUD/UI 持有并传递给 `apply_reroll()`——如果 UI 层在使用后未清空此状态，可能导致跨炼制会话的状态污染。缓解：UI 在炼制流程完成（无论接受还是重掷）后显式清空瞬态上下文。GUT 集成测试验证重掷状态的生命周期正确性
- **无"系统级"语义标识**：`class_name` 的全局注册与 Autoload 的"系统节点"在 Godot 编辑器的 Remote 树中不可见——不便于调试时查看系统状态。缓解：AlchemySystem 不持有状态——调试时查看 ResourceSystem 和 DeckEditingSystem 的 GSM 数据即可了解全部炼制产物的状态
- **`acquired_method` 枚举扩展影响 ADR-0006**：新增 `CRAFT = 4` 枚举值需要 ADR-0006 补充确认。CardSystem 的 `serialize_instance()` / `deserialize_instance()` 需正确处理新枚举值

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| `const Dictionary` 配方表被运行时意外修改 | 低 | 配方数据损坏——灵材消耗错误 | 与 ADR-0010、ADR-0019 相同风险。GUT 冒烟测试验证基准配方值（`ALCHEMY_RECIPES["hui_chun_dan"]["rarity"] == 2` 等）。团队约定：配方表只读 |
| 品质重掷的瞬态状态在 UI 层泄漏——玩家快速连续点击导致状态不一致 | 低 | 重掷应用到错误的炼制会话 | UI 层在 `apply_reroll()` 调用后立即清空瞬态上下文。`apply_reroll()` 入口处验证 `existing_instance_id` 是否与当前会话匹配——不匹配则拒绝 |
| 万象真人阵亡后的品质加成仍被传入 | 低 | 品质掷骰概率不正确 | 调用方（HUD/UI）在传入 `quality_bonuses` 前检查万象真人存活状态。AlchemySystem 自身不校验 bonuses 的合法性——由调用方保证正确性 |
| `RandomNumberGenerator` 实例被共享导致确定性测试失败 | 低 | 测试不可复现 | 文档明确：每个 `craft_pill()` / `craft_artifact()` 调用必须传入独立的 RNG 实例（或在测试中重置 seed） |
| 化神期「丹道大成」的"本局首次"判定——读档后状态丢失 | 中 | 读档后丹道大成被多触发 | GSM 需持久化 `dadao_used_this_run: bool` 字段——存档/读档后正确恢复。本 ADR 不定义此字段的存储位置——由调用方（HUD/UI 或 DeckEditingSystem）管理 `is_dadao_active` 的判定逻辑 |
| 铭刻系统消费的接口契约未被铭刻 ADR 遵循 | 低 | 铭刻无法正确读取炼器产出的法宝数据 | 本 ADR §铭刻系统接口契约明确定义契约项——铭刻 ADR 编写时需交叉引用。GUT 集成测试验证炼器产出 → 铭刻读取的端到端数据流 |

### 化神期「丹道大成」的状态管理

化神期「丹道大成」——每局首次炼丹/炼器必定升品——需要一个"本局是否已使用过"的持久标记。此标记不在 AlchemySystem 中管理（AlchemySystem 不持有状态），而是由调用方传入 `is_dadao_active: bool` 参数。

**建议存储位置**：GSM `player.deck` 域或 GSM `player` 域中新增 `dadao_used_this_run: bool` 字段。DeckEditingSystem 的 `initialize_initial_deck()` 将其重置为 `false`（每局开始）。炼制完成后由 HUD/UI 或 DeckEditingSystem 将其设为 `true`。

> 此决策可在铭刻系统 ADR 或独立的"化神期特殊能力"ADR 中最终确定。本 ADR 的接口设计已为两种存储方案留出灵活性（`is_dadao_active` 作为参数传入，AlchemySystem 不关心其来源）。

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| alchemy-crafting-system.md | §1a 炼丹配方——4 个配方 + 灵材消耗 + 产出稀有度 | `ALCHEMY_RECIPES` const Dictionary——灵材消耗逐品质定义，产出稀有度键值 |
| alchemy-crafting-system.md | §1b 炼丹品质浮动机器——升品概率、降品概率、品质效果缩放 | `quality_roll()` + `pill_effect()` + `QUALITY_MOD` 映射——三方独立可测 |
| alchemy-crafting-system.md | §1b 品质重掷——玩家决策：+15%升品概率、25%降品概率 | `quality_reroll()` + `apply_reroll()`——独立于首次掷骰的可测试入口 |
| alchemy-crafting-system.md | §1c 丹药效果定义——回春丹/玉灵丹/天罗丹/九转金丹的具体效果值 | 配方表中的 `base_effect` + `pill_effect()` 缩放公式 |
| alchemy-crafting-system.md | §2a 炼器配方——4 个配方 + 灵材消耗 + 法宝白值基准 | `ARTIFACT_RECIPES` const Dictionary + `forge_artifact_stat()` 生成攻防值 |
| alchemy-crafting-system.md | §2b 炼器品质机制——与炼丹共用 quality_roll，影响法宝白值 | `forge_artifact_stat(rarity, quality_mod)`——品质倍率映射到攻防值 |
| alchemy-crafting-system.md | §3 炼丹/炼器等级——境界驱动、配方解锁 | `_get_alchemy_level()` = `GSM.player.realm.level - 1`；配方表中的 `unlock_level` 字段 |
| alchemy-crafting-system.md | §3 化神期「丹道大成」——每局首次炼制必升品 | `is_dadao_active` 参数——调用方传入判定结果，AlchemySystem 执行跳过掷骰 |
| alchemy-crafting-system.md | §4 炼制位置——地图丹炉节点触发 | AlchemySystem 不管理触发入口——由探索系统和 HUD/UI 系统调用 `craft_pill()` / `craft_artifact()` |
| alchemy-crafting-system.md | §5 品质掷骰→品质倍率映射 | `QUALITY_MOD` const 映射：`DOWNGRADE → 0.8, STANDARD → 1.0, UPGRADE → 1.3` |
| alchemy-crafting-system.md | §4 拆解炼制物价值——炼制物折价 50% | `acquired_method = CRAFT` 标记 → ResourceSystem `dismantle_crafted_value()` 自动应用折价 |
| alchemy-crafting-system.md | §5 九转金丹递减收益 | `jindan_cumulative_threshold()`——第 N 次 +1HP 需累计颗数 |
| alchemy-crafting-system.md | 边界情况——灵材不足时灰显 | `craft_pill()` 返回 `INSUFFICIENT_MATERIALS`——UI 据此灰显按钮 |
| alchemy-crafting-system.md | 边界情况——暗金配方升品仍为暗金（上限 5） | `resolve_final_rarity()` 内部 `mini(rarity + 1, 5)`——钳制上限 |
| alchemy-crafting-system.md | 边界情况——万象真人阵亡后加成消失 | 调用方在传入 `quality_bonuses` 前检查存活状态——AlchemySystem 不校验 |
| alchemy-crafting-system.md | §其他系统的交互——资源系统/卡牌系统/卡组编辑系统/修为养成系统/境界系统 | `craft_pill()` 编排流程序列化调用：ResourceSystem → CardSystem → DeckEditingSystem |

## 性能影响
- **CPU**：所有公式为纯整数/浮点运算——单次 `quality_roll()` <0.001ms。`craft_pill()` 编排含 3 次 ResourceSystem 调用 + 1 次 CardSystem 调用 + 1 次 DeckEditingSystem 调用——总计 <0.05ms。非热路径（仅在玩家点击炼制时调用，非每帧）
- **内存**：const 配方表（8 个配方 × 约 200B）<2KB。AlchemySystem 为 RefCounted——按需实例化，无持久内存占用。调用静态方法时零内存分配
- **加载时间**：零——const Dictionary 编译时分配，无文件 I/O
- **网络**：不适用（单机游戏）

## 迁移计划
本 ADR 为新建架构——无现有代码需迁移。实现顺序：
1. 在 CardSystem（ADR-0006）的 `acquired_method` 枚举中新增 `CRAFT = 4`
2. 创建 `res://src/feature/alchemy_system.gd`——配方表 + 公式 + 炼制编排
3. 在 GSM `player` 域中添加 `dadao_used_this_run: bool` 字段（化神期丹道大成判定）
4. HUD/UI 系统实现炼制界面时：调用 `AlchemySystem.craft_pill()` / `craft_artifact()`
5. 探索系统实现丹炉/炼器台节点时：触发炼制界面打开
6. GUT 测试覆盖：品质掷骰概率正确性、丹药效果缩放、法宝白值生成、重掷逻辑、化神期丹道大成必升品、九转金丹递减收益

## 验证标准
- **GIVEN** 灵材库存: 低级灵材×2，炼丹等级=0，**WHEN** `AlchemySystem.craft_pill("hui_chun_dan", 0.0, rng)`，**THEN** 返回 `result=SUCCESS`，灵材-2，卡组新增 1 张回春丹（稀有度为蓝/白/紫之一，取决于 quality_roll 结果）
- **GIVEN** 灵材库存: 低级灵材×1，**WHEN** `AlchemySystem.craft_pill("hui_chun_dan", 0.0, rng)`，**THEN** 返回 `result=INSUFFICIENT_MATERIALS`，灵材不变，卡组不变
- **GIVEN** 炼丹等级=0（炼气期），**WHEN** `AlchemySystem.craft_pill("yu_ling_dan", 0.0, rng)`，**THEN** 返回 `result=RECIPE_LOCKED`
- **GIVEN** recipe_base=2, alchemy_level=2, bonuses=0, rng.seed=42, **WHEN** `AlchemySystem.quality_roll(2, 2, 0.0, rng)`，**THEN** 结果可复现（确定性测试）
- **GIVEN** quality_mod=1.3, base_value=4, bonus_pct=0, **WHEN** `AlchemySystem.pill_effect(4, 1.3, 0.0)`，**THEN** 返回 5（floor(4 × 1.3) = 5）
- **GIVEN** rarity=4 (金), quality_mod=0.8, **WHEN** `AlchemySystem.forge_artifact_stat(4, 0.8)`，**THEN** 返回 `{atk: 4, def: 4}`（floor(6×0.8)=4, floor(5×0.8)=4）
- **GIVEN** rarity=2 (蓝), quality_mod=1.3, **WHEN** `AlchemySystem.forge_artifact_stat(2, 1.3)`，**THEN** 返回 `{atk: 3, def: 2}`（升品→紫色基准 atk=4→floor(4×1.3)=5, def=3→floor(3×1.3)=3——需先映射到升品稀有度的基准值）
- **GIVEN** is_dadao_active=true, **WHEN** `AlchemySystem.craft_pill("hui_chun_dan", 0.0, rng, true)`，**THEN** 返回 `first_roll=UPGRADE`，跳过 quality_roll()
- **GIVEN** 首次掷骰 quality_roll 结果 = STANDARD（蓝），玩家选择重掷，**WHEN** `AlchemySystem.apply_reroll("hui_chun_dan", 0.0, rng, inst_id)`，**THEN** 返回 `can_reroll=false`，新结果为 quality_reroll() 的结果（high_chance +15%, low_chance=25%）

## 相关决策
- ADR-0019（资源系统——`spend_resource()` 灵材消耗、`can_spend()` 灵材校验、`dismantle_crafted_value()` 拆解折价）
- ADR-0006（卡牌数据模型——`create_instance()` 创建卡牌实例、`serialize_instance()` 序列化、`acquired_method` 枚举扩展 CRAFT=4）
- ADR-0023（卡组编辑系统——`add_cards_to_deck()` 炼制产出写入卡组）
- ADR-0001（游戏状态管理器——`player.resources.ling_cai.*` 灵材数据、`batch_updated` Cat 1 信号）
- ADR-0010（境界系统——`GSM.player.realm.level` 查询境界层级 → 炼丹/炼器等级计算）
- ADR-0020（修为养成系统——大境界突破 → 炼丹等级 +1）
- ADR-0025（流派系统——百艺炼丹流检测 `acquired_method == CRAFT` 的计数）
- ADR-0009（卡牌效果引擎——`RandomNumberGenerator` 独立实例的 PRD 模式先例）
- ADR-0007（三分类信号体系——AlchemySystem 不发射自有 Cat 2b 信号；灵材扣减和卡组变更通过 GSM Cat 1 `batch_updated` 传播）
- 法宝铭刻系统 ADR（待创建——依赖本 ADR 的炼器产出契约）