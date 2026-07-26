# ADR-0030：法宝铭刻系统 — RefCounted + class_name 工具类 + const 权重表 + 委托消费架构

- **Status**: proposed
- **Date**: 2026-07-26
- **Authors**: @zwzhang
- **Reviewers**: -
- **Supersedes**: -
- **Superseded by**: -

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Artifact Inscription |
| **知识风险** | LOW（const Dictionary、RefCounted、RandomNumberGenerator、Array 操作——全部自 4.0 起稳定。不依赖 4.4+ 新特性） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——全部 API 自 Godot 4.0 起稳定 |
| **需要验证** | `const Dictionary` 权重表不被运行时修改（GDScript `const` 不冻结嵌套内容——与 ADR-0010、ADR-0019、ADR-0028 相同风险）；加权不放回抽取的确定性（`RandomNumberGenerator` 独立实例 seed 固定时应可复现） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0019（ResourceSystem——`spend_resource("ling_cai", N, MEDIUM)` 灵材消耗、`can_spend()` 余额校验）；ADR-0006（CardSystem——CardInstance 的 `inscriptions`/`inscription_count` 字段读写、`serialize_instance()`/`deserialize_instance()` 序列化往返）；ADR-0001（GSM——`player.resources.ling_cai.*` 灵材数据、`batch_updated` Cat 1 信号传播）；ADR-0028（AlchemySystem——炼器产出法宝卡牌实例是本系统的输入）；ADR-0010（RealmSystem——`GSM.player.realm.level` 境界层级查询决定 T4 可用性和 bonus 加值）；ADR-0007（三分类信号体系——铭刻系统不发射自有 Cat 2b 信号） |
| **启用** | 战斗系统（铭刻副属性在战斗中生效：暴击率、暴伤、吸血、虚弱、破甲、灵力萃取、费用-1、回合回血）；卡组编辑系统（法宝详情面板展示铭刻数据）；HUD/UI 系统（铭刻候选选择界面、替换界面、铭刻结果展示） |
| **阻塞** | 不阻塞上游系统——CardSystem、ResourceSystem、RealmSystem 均已定义。不阻塞 AlchemySystem（铭刻是炼器产出的下游消费方）。阻塞战斗系统铭刻属性生效逻辑和 UI 铭刻界面——在上述系统实现铭刻相关功能前必须接受本 ADR |
| **排序说明** | Feature 层——在 Core 层 ResourceSystem（ADR-0019）、CardSystem（ADR-0006）、RealmSystem（ADR-0010）和 Feature 层 AlchemySystem（ADR-0028）被接受后编写。Autoload 链无需新增——本系统选择 **RefCounted 工具类**模式，不占用 Autoload 槽位（当前链 25 个已超 Godot 建议的 20 软上限）。与 ADR-0028 共享灵材消耗接口和配方模式，但各自独立决策模块归属 |

## 上下文和问题

### 问题陈述

`inscription-system.md` GDD 定义了法宝铭刻系统的完整设计——11 种副属性权重表、候选生成算法（不放回加权抽取）、递增灵材成本、境界门槛、定向铭刻、3 条满后替换流程、拆解返还。但 GDD 关注的是"玩家体验到什么"，本 ADR 需要解决的是"系统如何工程化实现"：

1. **模块归属**：铭刻系统是作为独立模块还是嵌入 AlchemySystem（ADR-0028）？ADR-0028 替代方案 D 已预判分离——铭刻的候选生成算法（6 步权重变换管线）与炼丹的品质掷骰逻辑在复杂度和设计意图上完全不同，合并将形成 500+ 行单文件。
2. **数据存储**：铭刻数据（`inscriptions`/`inscription_count`/`total_materials_spent`）存储在 CardInstance 上（ADR-0006 已定义前两个字段；`total_materials_spent` 需补充定义）。铭刻系统不持有数据副本——所有状态随 CardInstance 通过 GSM 持久化。
3. **候选生成的随机数策略**：`generate_candidates()` 使用独立 `RandomNumberGenerator` 实例还是全局 `randf()`？应与 ADR-0009（PRD 模式）、ADR-0028（品质掷骰）保持一致——独立 RNG 实例确保候选生成结果可复现测试。
4. **递增成本的灵材消耗路径**：铭刻消耗中级灵材（第 N 次 = min(N, 5)）——是否通过 ResourceSystem 统一扣减？必须遵循 ADR-0019 的资源写入契约。
5. **"磨灭"功能不在范围内**：GDD 未定义单独移除铭文的操作——仅定义了"3 条满后替换"和"拆解返还"。本 ADR 不设计磨灭接口。

### 约束

- **25 个 Autoload 现状**：Godot 建议 ≤20 Autoload。当前链 #1~#25。铭刻系统无运行时持久状态——所有数据存储在 CardInstance 上（已通过 GSM 持久化）。铭刻是瞬间操作（点击→扣灵材→选候选→完成），不需要 Autoload 的生命周期管理
- **GSM 数据所有权不变**：灵材数据存储在 GSM `player.resources.ling_cai.*`——铭刻系统不持有数据副本
- **资源写入必须通过 ResourceSystem**：ADR-0019 禁止模式——不直接写 GSM `player.resources.*`
- **铭刻数据归属 CardInstance**：ADR-0006 已定义 `inscriptions`（Array[Dictionary]）和 `inscription_count`（int）字段。`total_materials_spent`（int）需补充到 ADR-0006
- **候选生成 RNG 隔离**：`generate_candidates()` 不应与战斗 PRD 或探索 RNG 共享全局状态——确保候选生成结果可复现测试
- **铭刻操作不可逆**：GDD §核心规则 #1——选定即生效，无法撤销。确认即扣灵材——候选展示后灵材不退还

### 需求

- 11 种副属性的权重表 + 品质梯级标记 + 境界门槛——单一真理来源
- 候选生成算法：6 步权重变换管线（定向加权 → 境界加成 → T4 门槛移除 → 已有属性惩罚 → 费用-1 特殊处理 → 不放回抽取）
- 铭刻编排流程：校验灵材余额 → 确认扣减灵材 → 生成候选 → 玩家选择 → 写入 CardInstance
- 递增成本公式 `inscription_cost(N) = min(N, 5)` 中级灵材
- 3 条满后的替换流程：玩家手动选择被替换属性 → 排除该属性后的候选生成 → 新属性替换
- 拆解返还：`dismantle_refund(total_materials_spent) = max(1, floor(total_materials_spent × 0.5))`
- 定向铭刻：攻击向/防御向/战术向——对应属性权重 ×1.5（不额外消耗灵材）

## 决策

**法宝铭刻系统作为 RefCounted + class_name 工具类（`InscriptionSystem`）实现——持有 11 种副属性的 const Dictionary 权重表和 1 个纯函数候选生成算法（`generate_candidates()`），通过 ResourceSystem.spend_resource() 消费灵材，通过 CardSystem 读写 CardInstance 的铭刻字段。自身不持有任何运行时持久状态，不注册 Autoload（不占用 #26 槽位）。**

### 层分类决议：Feature 层论证

铭刻系统不是 Foundation 层（依赖 GSM），不是 Core 层（不是被 8+ 个系统消费的基础设施——仅有战斗系统和 HUD/UI 两个消费者）。它是典型的 Feature 层"垂直功能"——编排多个底层系统完成"灵材→铭刻属性"这一特定玩家体验。与 AlchemySystem（ADR-0028）和 CombatSystem（ADR-0008）属于同一层级。

**关键区别**：与 CombatSystem（#9 Autoload——有 `CombatPhase` 状态机）、DeckEditingSystem（#22 Autoload——有 `session_remove_count` 跨场景持久状态）不同，铭刻系统**无运行时持久状态**——铭刻是瞬间操作（玩家点击 → 扣灵材 → 选候选 → 完成），所有数据在操作完成后即持久化到 CardInstance（通过 GSM 的序列化机制）。唯一的瞬态数据是候选生成的中间结果——这不需要 Autoload 的生命周期管理，由铭刻流程的本地变量承载即可。

### 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                    GSM (ADR-0001)                             │
│  player.resources.ling_cai.{low, medium, high, top}: int      │
│  player.realm.level: int  (1=炼气, 2=筑基, ... 5=化神)       │
│  batch_updated(changes) → Cat 1 信号                          │
└──────────────┬───────────────────────────────────────────────┘
               │ 数据存储所有权
               ▼
┌──────────────────────────────────────────────────────────────┐
│   ResourceSystem (#16 Autoload)          CardSystem (#6)      │
│   spend_resource("ling_cai", N, MEDIUM)  get_instance(id)     │
│   can_spend("ling_cai", N, MEDIUM)       serialize/deserialize│
└──────────────┬──────────────────────────────┬────────────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────────────────────────────────────────┐
│        InscriptionSystem (RefCounted + class_name)            │
│                                                               │
│  ┌─ 权重表（const Dictionary，编译时常量）─────────────────┐ │
│  │ SUBSTAT_WEIGHTS = {                                     │ │
│  │   "atk+1":       {w:22, tier:1, direction:"attack"},    │ │
│  │   "def+1":       {w:18, tier:1, direction:"defense"},   │ │
│  │   "crit+3":      {w:15, tier:2, direction:"attack"},    │ │
│  │   "crit_dmg+5":  {w:12, tier:2, direction:"attack"},    │ │
│  │   "hp+2":        {w:10, tier:3, direction:"defense"},   │ │
│  │   "lifesteal+2": {w:8,  tier:3, direction:"tactical"},  │ │
│  │   "weakness":    {w:6,  tier:3, direction:"tactical"},  │ │
│  │   "cost-1":      {w:4,  tier:4, direction:"special"},   │ │
│  │   "regen+1":     {w:3,  tier:4, direction:"defense"},   │ │
│  │   "armor_break": {w:3,  tier:4, direction:"tactical"},  │ │
│  │   "mana_extract":{w:2,  tier:4, direction:"tactical"},  │ │
│  │ }                                                       │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─ 候选生成（纯函数——不修改状态，不发射信号）─────────────┐ │
│  │ generate_candidates(existing, realm_L, to_replace, dir)   │ │
│  │   ├→ Step 2.5: 定向铭刻方向加权 (×1.5)                   │ │
│  │   ├→ Step 3:   境界加成 (T4 bonus) / 炼气期移除 T4       │ │
│  │   ├→ Step 3.5: 费用-1 已存在时完全移除                   │ │
│  │   ├→ Step 4:   已有属性权重减半 (×0.5, min=1)            │ │
│  │   └→ Step 5:   不放回抽取 3 个互不相同候选                │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─ 铭刻编排（消费 ResourceSystem + CardSystem）───────────┐ │
│  │ inscribe(artifact_inst, direction, rng) → result          │ │
│  │   ├→ inscription_cost() 计算费用                          │ │
│  │   ├→ ResourceSystem.spend_resource()  # 扣灵材            │ │
│  │   ├→ generate_candidates()             # 生成候选          │ │
│  │   ├→ 玩家从候选中选择（UI 交互——系统返回候选，UI 回调选择） │ │
│  │   └→ _apply_inscription()              # 写入 CardInstance │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────┬──────────────────────────────────────────────┘
               │ 铭刻数据写入 CardInstance.inscriptions[]
               ▼
┌──────────────────────────────────────────────────────────────┐
│              CardInstance (ADR-0006) — GSM 持久化              │
│  inscriptions: Array[Dictionary]                              │
│  inscription_count: int                                       │
│  total_materials_spent: int  (← ADR-0006 需补充此字段)        │
└──────────────────────────────────────────────────────────────┘
```

### 关键接口

```gdscript
# === InscriptionSystem (RefCounted + class_name) ===
class_name InscriptionSystem
extends RefCounted

# === 方向枚举 ===
enum Direction { NONE, ATTACK, DEFENSE, TACTICAL }

# === 副属性权重表（const Dictionary——编译时常量） ===
const SUBSTAT_WEIGHTS: Dictionary = {
  "atk+1":       {"weight": 22, "tier": 1, "direction": Direction.ATTACK},
  "def+1":       {"weight": 18, "tier": 1, "direction": Direction.DEFENSE},
  "crit+3":      {"weight": 15, "tier": 2, "direction": Direction.ATTACK},
  "crit_dmg+5":  {"weight": 12, "tier": 2, "direction": Direction.ATTACK},
  "hp+2":        {"weight": 10, "tier": 3, "direction": Direction.DEFENSE},
  "lifesteal+2": {"weight": 8,  "tier": 3, "direction": Direction.TACTICAL},
  "weakness":    {"weight": 6,  "tier": 3, "direction": Direction.TACTICAL},
  "cost-1":      {"weight": 4,  "tier": 4, "direction": -1},  # T4 稀有
  "regen+1":     {"weight": 3,  "tier": 4, "direction": Direction.DEFENSE},
  "armor_break": {"weight": 3,  "tier": 4, "direction": Direction.TACTICAL},
  "mana_extract":{"weight": 2,  "tier": 4, "direction": Direction.TACTICAL},
}

# === 定向铭刻方向加权倍率 ===
const DIRECTION_BONUS_MULTIPLIER := 1.5

# === 已有属性权重减半倍率 ===
const DUPLICATE_PENALTY_MULTIPLIER := 0.5

# === 候选数量 ===
const CANDIDATE_COUNT := 3

# === 递增成本软上限 ===
const COST_SOFT_CAP := 5

# === 拆解返还比例 ===
const DISMANTLE_REFUND_RATIO := 0.5

# === 铭刻结果枚举 ===
enum InscribeResult { SUCCESS, INSUFFICIENT_MATERIALS, NOT_ARTIFACT, FULL_NEED_REPLACE }

# === 候选生成（纯函数——严格按 GDD §公式 第 171-227 行） ===

## 生成铭刻候选副属性——6 步权重变换管线
## @param existing: Array[Dictionary]——当前法宝已有铭刻（可为空）
## @param realm_level: int [1,5]——当前境界层级
## @param to_replace_idx: int——被替换属性索引，-1 表示无替换
## @param direction: Direction——定向铭刻方向，NONE=无偏向
## @param rng: RandomNumberGenerator——独立 RNG 实例
## @return Array[String]——3 个互不相同的候选副属性键
static func generate_candidates(existing: Array, realm_level: int, to_replace_idx: int, direction: int, rng: RandomNumberGenerator) -> Array:
    # Step 1: 构建有效已有列表（排除被替换属性）
    var effective: Array = []
    for i in range(existing.size()):
        if i != to_replace_idx:
            effective.append(existing[i])
    
    # Step 2: 从权重表复制基础权重
    var weights: Dictionary = {}
    for key in SUBSTAT_WEIGHTS:
        weights[key] = SUBSTAT_WEIGHTS[key]["weight"]
    
    # Step 2.5: 定向铭刻方向加权（在境界加成前应用）
    if direction == Direction.ATTACK:
        for key in ["atk+1", "crit+3", "crit_dmg+5"]:
            if key in weights:
                weights[key] = floori(weights[key] * DIRECTION_BONUS_MULTIPLIER)
    elif direction == Direction.DEFENSE:
        for key in ["def+1", "hp+2"]:
            if key in weights:
                weights[key] = floori(weights[key] * DIRECTION_BONUS_MULTIPLIER)
        if realm_level >= 2 and "regen+1" in weights:
            weights["regen+1"] = floori(weights["regen+1"] * DIRECTION_BONUS_MULTIPLIER)
    elif direction == Direction.TACTICAL:
        for key in ["lifesteal+2", "weakness"]:
            if key in weights:
                weights[key] = floori(weights[key] * DIRECTION_BONUS_MULTIPLIER)
        if realm_level >= 2:
            if "armor_break" in weights:
                weights["armor_break"] = floori(weights["armor_break"] * DIRECTION_BONUS_MULTIPLIER)
            if "mana_extract" in weights:
                weights["mana_extract"] = floori(weights["mana_extract"] * DIRECTION_BONUS_MULTIPLIER)
    
    # Step 3: 境界加成或 T4 移除
    if realm_level >= 2:
        var bonus: int = floori(realm_level * 2)
        for key in ["cost-1", "regen+1", "armor_break", "mana_extract"]:
            if key in weights:
                weights[key] += bonus
    else:
        # 炼气期：移除 T4 属性
        for key in ["cost-1", "regen+1", "armor_break", "mana_extract"]:
            weights.erase(key)
    
    # Step 3.5: 费用-1 已存在时完全移除（不叠加→死抽候选，不应出现）
    var has_cost_minus := false
    for entry in effective:
        if entry.get("type", "") == "cost-1":
            has_cost_minus = true
            break
    if has_cost_minus:
        weights.erase("cost-1")
    
    # Step 4: 已有相同属性权重减半（作用于已含加成后的权重）
    for entry in effective:
        var stat: String = entry.get("type", "")
        if stat in weights and weights[stat] > 0:
            weights[stat] = maxi(1, floori(weights[stat] * DUPLICATE_PENALTY_MULTIPLIER))
    
    # Step 5: 不放回抽取 3 个互不相同的候选
    return _weighted_sample_without_replacement(weights, CANDIDATE_COUNT, rng)


# === 铭刻费用（递增，软上限 5） ===

## 第 N 次铭刻消耗 = min(N, 5) 中级灵材（N = 当前 inscription_count + 1）
static func inscription_cost(inscription_count: int) -> int:
    return mini(inscription_count + 1, COST_SOFT_CAP)


# === 拆解返还 ===

## 返还铭刻总消耗灵材的 50%（向下取整，至少返 1）
static func dismantle_inscription_refund(total_materials_spent: int) -> int:
    if total_materials_spent == 0:
        return 0  # 从未铭刻过的法宝拆解不返还额外灵材
    return maxi(1, floori(total_materials_spent * DISMANTLE_REFUND_RATIO))


# === 铭刻编排 ===

## 执行铭刻——完整编排流程
## @param artifact_inst: CardInstance——目标法宝实例
## @param direction: Direction——定向铭刻方向
## @param rng: RandomNumberGenerator——独立 RNG 实例
## @param to_replace_idx: int——被替换属性索引，-1=无替换（新增）
## @param existing: Array——当前已有铭刻数组（从 inst.inscriptions 读取）
## @return Dictionary {result: InscribeResult, candidates: Array|[], ...}
static func inscribe(artifact_inst: CardInstance, direction: int, rng: RandomNumberGenerator, to_replace_idx: int = -1) -> Dictionary:
    # 1. 校验法宝类型
    var template: CardTemplate = CardSystem.get_template(artifact_inst.template_id)
    if template.type != CardType.ARTIFACT:
        return {"result": InscribeResult.NOT_ARTIFACT}
    
    # 2. 计算费用并校验灵材
    var cost: int = inscription_cost(artifact_inst.inscription_count)
    if not ResourceSystem.can_spend("ling_cai", cost, ResourceSystem.LingCaiQuality.MEDIUM):
        return {"result": InscribeResult.INSUFFICIENT_MATERIALS, "cost": cost}
    
    # 3. 灵材扣减（确认即扣——与 GDD AC-3 一致）
    ResourceSystem.spend_resource("ling_cai", cost, ResourceSystem.LingCaiQuality.MEDIUM)
    # GSM._set_resource_ling_cai() → batch_updated 信号
    
    # 4. 获取境界层级
    var realm_L: int = GSM.player.realm.level  # 1=炼气, 2=筑基, ...
    
    # 5. 生成候选
    var candidates: Array = generate_candidates(
        artifact_inst.inscriptions, realm_L, to_replace_idx, direction, rng
    )
    
    # 6. 如果是替换模式且之前非满，标记
    var is_replace: bool = to_replace_idx >= 0
    
    return {
        "result": InscribeResult.SUCCESS,
        "candidates": candidates,
        "cost": cost,
        "is_replace": is_replace,
        "to_replace_idx": to_replace_idx,
    }

## 应用玩家选择的候选——在 UI 回调玩家选择后调用
## @param artifact_inst: CardInstance——目标法宝实例
## @param chosen_stat: String——玩家选择的副属性键
## @param to_replace_idx: int——被替换属性索引，-1=新增
static func apply_inscription(artifact_inst: CardInstance, chosen_stat: String, to_replace_idx: int, cost: int) -> void:
    var entry: Dictionary = {"type": chosen_stat, "value": null}
    # 有值属性设置 value（attack/defense/hp/crit 等），无值属性 value 保持 null
    
    if to_replace_idx >= 0:
        artifact_inst.inscriptions[to_replace_idx] = entry
    else:
        artifact_inst.inscriptions.append(entry)
    
    artifact_inst.inscription_count += 1
    artifact_inst.total_materials_spent += cost
    # 注：CardInstance 数据变更通过 CardSystem 序列化后触发 GSM 持久化——
    # InscriptionSystem 不直接操作 GSM
```

### 候选生成数据流

```
[玩家点击铭刻确认] → InscriptionSystem.inscribe(inst, direction, rng)
  │
  ├─ 1. CardSystem.get_template(inst.template_id) → 校验 type == ARTIFACT
  │
  ├─ 2. inscription_cost(inst.inscription_count) → min(N+1, 5)
  │     ├→ ResourceSystem.can_spend("ling_cai", cost, MEDIUM) → 余额不足则返回
  │     └→ ResourceSystem.spend_resource("ling_cai", cost, MEDIUM) → 扣灵材
  │         └→ GSM._set_resource_ling_cai(MEDIUM, new_val) → batch_updated 信号
  │
  ├─ 3. generate_candidates(inscriptions, realm_L, to_replace, dir, rng)
  │     ├→ 定向加权 → 境界加成/T4移除 → 费用-1特殊处理 → 已有属性减半 → 不放回抽取
  │     └→ 返回 3 个互不相同的候选 [String]
  │
  ├─ 4. 返回 {result: SUCCESS, candidates: [...], cost: N, ...}
  │     └→ [HUD/UI 展示候选，等待玩家选择]
  │
  └─ 5. [玩家选择候选后] → apply_inscription(inst, chosen, to_replace, cost)
        └→ 写入 inst.inscriptions[] / inst.inscription_count / inst.total_materials_spent
```

### 信号传播路径

InscriptionSystem 自身**不发射任何 Cat 2b 信号**——铭刻的数据变更是通过以下渠道间接传播的：

```
灵材扣减: InscriptionSystem → ResourceSystem.spend_resource()
  → GSM._set_resource_ling_cai() → batch_updated({"player.resources.ling_cai.medium": {old, new}})
  → HUD 刷新灵材库存

铭刻数据变更: InscriptionSystem → CardInstance 字段直接写入
  → CardInstance 数据通过 GSM 序列化机制持久化（存档时）
  → 战斗系统在下一场战斗初始化时读取 CardInstance.inscriptions[] 计算属性加成
  → HUD/UI 在法宝详情面板打开时重新读取 CardInstance 数据展示铭刻属性
```

### 实例数据中的铭刻字段

CardInstance 的 `inscriptions`/`inscription_count`（ADR-0006 已定义）是铭刻系统的读写目标。`total_materials_spent`（int，累计消耗中级灵材数，单调递增永不重置）需补充到 ADR-0006 的 CardInstance 定义中——用于拆解返还计算。

| 字段 | 类型 | 所有权 | 描述 |
|------|------|:------:|------|
| `inscriptions` | Array[Dictionary] | 铭刻系统 | 当前副属性列表，每项 `{type: String, value: Variant}`。无值属性（虚弱/破甲/灵力萃取）value 为 null |
| `inscription_count` | int | 铭刻系统 | 该法宝累计铭刻次数（从 0 开始，每次铭刻+1）。用于费用递增计算 |
| `total_materials_spent` | int | 铭刻系统 | 该法宝铭刻累计消耗中级灵材数（单调递增）。用于拆解返还计算。**ADR-0006 需补充此字段** |

> **ADR-0006 需补充**：在 CardInstance 中新增 `total_materials_spent: int = 0` 字段。CardSystem 的 `serialize_instance()`/`deserialize_instance()` 需正确处理此字段的序列化往返。与 ADR-0028 对 `acquired_method = CRAFT` 的补充处理一致。

## 考虑的替代方案

### 替代方案 A：嵌入 AlchemySystem——铭刻作为炼丹炼器的子功能

- **描述**：`inscribe()` 作为 AlchemySystem 的方法。权重表和候选生成纳入 AlchemySystem。理由：铭刻是炼器产出的后续养成步骤——共享灵材消耗路径。
- **优点**：减少 1 个模块。灵材消耗路径单一。新开发者只需知道 `AlchemySystem` 一个入口即可操作炼制和铭刻。
- **缺点**：单文件膨胀至 500+ 行——AlchemySystem 已有 8 个配方表 + 5 条公式 + 2 种炼制编排。铭刻的候选生成算法（6 步权重变换管线）是独立复杂逻辑——与炼丹的简单品质掷骰（3 条 if 分支）完全不同的复杂度。ADR-0028 替代方案 D 已预判此合并并拒绝。炼丹（瞬间创造）和铭刻（反复养成）的玩家体验完全不同——合并使一个模块同时处理两种设计意图。
- **拒绝原因**：ADR-0028 §替代方案 D 已预判分离——"铭刻系统的 Autoload vs RefCounted 决策应独立评估"。合并违反单一职责原则。候选生成的权重变换管线与品质掷骰逻辑分开更利于独立测试和独立调优。

### 替代方案 B：独立 Feature 层 Autoload（#26）——与 CombatSystem 同级

- **描述**：InscriptionSystem 作为独立 Feature 层 Autoload 注册在 #26 位置。持有权重表、候选生成、铭刻编排。所有方法为实例方法（非 static）。
- **优点**：语义清晰——"系统级服务"标识。与 CombatSystem（#9）、DeckEditingSystem（#22）的 Autoload 模式表面一致。
- **缺点**：增加第 26 个 Autoload——Godot 建议 ≤20，当前已超出 30%。铭刻系统无运行时持久状态——所有数据存储在 CardInstance 上（已通过 GSM 持久化）。Autoload 的 `_ready()` 为空，`_process()` 为空——与 ADR-0028 替代方案 A 相同论证链：Autoload 应留给有运行时持久状态的系统。铭刻的"瞬间操作"特性更适合 RefCounted 的按需实例化模式。
- **拒绝原因**：与 ADR-0028 替代方案 A 相同的架构原则——Autoload 不是荣誉徽章，是需论证的工程选择。铭刻不满足 Autoload 论证门槛（无运行时持久状态，无跨场景生命周期需求）。

### 替代方案 C：铭刻属性直接写入 GSM——不通过 CardInstance 间接存储

- **描述**：铭刻属性存储在 GSM `player.inscriptions` 域中（`{card_instance_id: [substat, ...]}`）。铭刻系统直接操作 GSM 域，而非通过 CardInstance。
- **优点**：铭刻数据与卡牌实例解耦——即使 CardInstance 被删除，铭刻记录仍可保留（用于拆解返还追溯）。
- **缺点**：引入"同一法宝的数据分散在两个位置"的反模式（模板+等级在 CardInstance，铭刻在 GSM）——存档/读档时需同时同步两个来源，增大不一致风险。违反 ADR-0006 的数据模型设计——`inscriptions` 已定义为 CardInstance 的实例字段。额外维护一个 GSM 索引域——增加复杂度但无明显收益。
- **拒绝原因**：CardInstance 已提供完整的铭刻数据存储方案（ADR-0006）。拆解返还所需的 `total_materials_spent` 也是实例级数据——随实例存在，随实例销毁。额外 GSM 域违反数据局部性原则。

## 后果

### 积极的

- **不增加 Autoload 数量**：保持 25 个 Autoload——不进一步超出 Godot 软上限。`class_name` 全局注册机制在性能和语义上与 Autoload 无差异
- **纯函数可测试性强**：`generate_candidates()` 为 `static func`——输入参数 → 返回候选数组。GUT 测试无需模拟任何 Autoload 或场景树，注入固定 seed 的 RNG 实例即可验证确定性行为。AC-6（炼气期无 T4）、AC-7a（定向攻击向权重）、AC-8c（三叠归零保护）均为可直接调用的单元测试
- **权重表唯一真理来源**：11 种副属性的权重、梯级、方向归属在 `SUBSTAT_WEIGHTS` 中唯一定义——策划调参修改一处，所有消费方自动生效
- **与 ADR-0028 的 AlchemySystem 模式完全一致**：RefCounted + class_name + const Dictionary + static 纯函数 + 委托 ResourceSystem/CardSystem——开发者学习 AlchemySystem 模式即可理解 InscriptionSystem
- **信号合规**：InscriptionSystem 自身不发射 Cat 2b 信号——灵材扣减通过 GSM `batch_updated`（Cat 1）传播，铭刻数据变更通过 CardInstance 字段写入后在下一存档周期持久化。与 ADR-0007 禁止模式 #11、ADR-0028 信号策略一致
- **候选生成 RNG 隔离**：`generate_candidates()` 接受 `RandomNumberGenerator` 参数——调用方注入独立 RNG 实例。单元测试通过 `rng.seed = 42` 实现确定性复现

### 消极的

- **权重变换管线的计算开销**：`generate_candidates()` 涉及字典复制、多次遍历、加权抽取——单次调用约 0.02ms。非热路径（仅在玩家点击铭刻时调用），可忽略
- **调用方需要同时了解 3 个系统**：铭刻操作需要 InscriptionSystem（候选生成）+ ResourceSystem（灵材查询）+ CardSystem（CardInstance 读写）。HUD/UI 系统需要协调 3 个入口。缓解：`inscribe()` 编排方法内部自动处理灵材扣减和候选生成——UI 只需调用 `inscribe()` → 展示候选 → 回调 `apply_inscription()`
- **`total_materials_spent` 跨模块维护**：该字段定义在 CardInstance（ADR-0006）但由 InscriptionSystem 写入，ResourceSystem（拆解）读取。三个系统共享一个字段——需在三个 ADR 间保持一致性。缓解：本 ADR 明确定义所有权（InscriptionSystem 写入），ADR-0006 补充定义字段，ADR-0019 只读消费

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| `const Dictionary` 权重表被运行时意外修改 | 低 | 候选生成权重错误 | 与 ADR-0019/ADR-0028 相同风险。GUT 冒烟测试验证基准权重值。团队约定：权重表只读 |
| 加权不放回抽取在极端权重分布下产生偏差 | 低 | 候选分布不符合预期 | GUT 测试验证：1000 次抽取的分布频率与权重比偏差 <5%。极端情况（池 <3 种）返回所有可用属性 |
| `total_materials_spent` 字段在 ADR-0006 中未同步补充 | 中 | 拆解返还计算错误 | 本 ADR 明确标记 ADR-0006 需补充字段——在接受前需交叉验证 |
| 铭刻后 CardInstance 未立即序列化导致存档丢失铭刻数据 | 低 | 玩家铭刻后退出未保存，铭刻丢失 | GSM 的保存触发机制（手动保存/自动保存）正常序列化 CardInstance——铭刻数据已写入对象，随 GSM serialize() 一并持久化 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| inscription-system.md | §1 铭刻基本规则——每次 3 候选、最多 3 条、不可逆、确认即扣灵材 | `inscribe()` 编排流程：扣灵材→生成候选→返回候选（等待玩家选择）。`apply_inscription()` 写入后不可撤销 |
| inscription-system.md | §2 副属性池——11 种属性 + 权重 + 品质梯级 + 境界门槛 | `SUBSTAT_WEIGHTS` const Dictionary——所有权重/梯级/方向唯一定义。`generate_candidates()` 内部境界门槛逻辑 |
| inscription-system.md | §3 候选生成规则——6 步权重变换管线 | `generate_candidates()` pure function——定向加权→境界加成→T4移除→已有属性减半→费用-1特殊处理→不放回抽取 |
| inscription-system.md | §4 3条满后替换流程 | `to_replace_idx` 参数——`generate_candidates()` 排除被替换属性。`apply_inscription()` 支持替换模式 |
| inscription-system.md | §1 定向铭刻——攻击/防御/战术方向权重×1.5 | `Direction` 枚举 + `generate_candidates()` Step 2.5 方向加权逻辑 |
| inscription-system.md | §3 铭刻费用——递增 min(N,5) | `inscription_cost()` 纯函数——`min(count+1, 5)` 中级灵材 |
| inscription-system.md | §4 拆解返还——总消耗灵材 50% | `dismantle_inscription_refund()` 纯函数——`max(1, floor(total × 0.5))` |
| inscription-system.md | §边界情况——费用-1 已存在时不出现候选 | `generate_candidates()` Step 3.5——费用-1 完全移除 |
| inscription-system.md | §边界情况——T4 属性筑基期门槛 | `generate_candidates()` Step 3——`realm_L >= 2` 时 bonus 加成，否则移除 T4 |
| inscription-system.md | §边界情况——候选不够 3 个时返回所有可用 | 加权不放回抽取内部 `min(pool_size, 3)` |
| inscription-system.md | §5 铭刻后立即生效——下一场战斗生效 | 铭刻数据写入 CardInstance 后通过 GSM 序列化持久化——战斗系统初始化时读取 |

## 性能影响
- **CPU**：`generate_candidates()` 单次调用约 0.02ms（字典复制 + 5 步遍历 + 加权抽取）。`inscribe()` 编排含 1 次 CardSystem 查询 + 1 次 ResourceSystem 调用 + 候选生成——总计 <0.1ms。非热路径（仅在玩家点击铭刻时调用，非每帧）
- **内存**：const 权重表（11 项 × 约 60B）<1KB。InscriptionSystem 为 RefCounted——按需实例化，无持久内存占用。调用静态方法时零内存分配
- **加载时间**：零——const Dictionary 编译时分配，无文件 I/O
- **网络**：不适用（单机游戏）

## 迁移计划
本 ADR 为新建架构——无现有代码需迁移。实现顺序：
1. 在 ADR-0006 的 CardInstance 中补充 `total_materials_spent: int = 0` 字段，更新 `serialize_instance()`/`deserialize_instance()` 以处理此字段
2. 创建 `res://src/feature/inscription_system.gd`——权重表 + 候选生成 + 铭刻编排 + 费用/返还公式
3. HUD/UI 系统实现铭刻界面时：调用 `InscriptionSystem.inscribe()` → 展示候选 → 玩家选择 → 回调 `InscriptionSystem.apply_inscription()`
4. 战斗系统实现铭刻属性生效逻辑时：读取 `CardInstance.inscriptions[]` 计算属性加成
5. 卡组编辑系统实现法宝详情面板时：展示 `inscriptions` 数据和铭刻历史
6. GUT 测试覆盖：候选生成权重正确性、定向铭刻加权、境界门槛、费用递增、拆解返还、已有属性减半、三叠归零保护、费用-1 完全移除

## 验证标准
- **GIVEN** inscriptions=[], realm_L=1, to_replace=-1, direction=NONE, rng.seed=42, **WHEN** `generate_candidates(...)`，**THEN** 权重字典中不含 T4 键（"cost-1"/"regen+1"/"armor_break"/"mana_extract"），返回 3 个互不相同的候选（均为 T1-T3）
- **GIVEN** inscriptions=[], realm_L=2, to_replace=-1, direction=ATTACK, rng.seed=42, **WHEN** `generate_candidates(...)`，**THEN** weights["atk+1"] = floor(22 × 1.5) = 33, weights["crit+3"] = floor(15 × 1.5) = 22, weights["crit_dmg+5"] = floor(12 × 1.5) = 18
- **GIVEN** inscriptions=[{type:"atk+1"}], realm_L=2, to_replace=-1, **WHEN** `generate_candidates(...)`，**THEN** weights["atk+1"] = floor(22 × 0.5) = 11（已有属性权重减半），weights["def+1"] = 18（未受惩罚）
- **GIVEN** inscriptions=[{type:"weakness"},{type:"weakness"},{type:"weakness"}], realm_L=1, to_replace=-1, **WHEN** `generate_candidates(...)`，**THEN** weights["weakness"] = 1（三叠归零保护——不会从池中消失）
- **GIVEN** inscriptions=[{type:"cost-1"}], realm_L=5, to_replace=-1, **WHEN** `generate_candidates(...)`，**THEN** "cost-1" 不在 weights 中（完全移除，非仅权重减半）
- **GIVEN** inscription_count=0, **WHEN** `inscription_cost(0)`，**THEN** 返回 1
- **GIVEN** inscription_count=5, **WHEN** `inscription_cost(5)`，**THEN** 返回 5（软上限）
- **GIVEN** total_materials_spent=6, **WHEN** `dismantle_inscription_refund(6)`，**THEN** 返回 3（floor(6 × 0.5) = 3）
- **GIVEN** total_materials_spent=1, **WHEN** `dismantle_inscription_refund(1)`，**THEN** 返回 1（至少返1）
- **GIVEN** total_materials_spent=0, **WHEN** `dismantle_inscription_refund(0)`，**THEN** 返回 0（从未铭刻不返还）

## 相关决策
- ADR-0028（炼丹炼器系统——炼器产出法宝卡牌实例是本系统的输入；共享 RefCounted + const Dictionary + 委托消费架构模式）
- ADR-0019（资源系统——`spend_resource("ling_cai", N, MEDIUM)` 灵材消耗、`can_spend()` 余额校验）
- ADR-0006（卡牌数据模型——CardInstance 的 `inscriptions`/`inscription_count` 字段；`total_materials_spent` 字段需补充）
- ADR-0001（游戏状态管理器——`player.resources.ling_cai.*` 灵材数据、`player.realm.level` 境界层级、`batch_updated` Cat 1 信号）
- ADR-0010（境界系统——`GSM.player.realm.level` 查询境界层级 → T4 门槛和 bonus 加值）
- ADR-0007（三分类信号体系——InscriptionSystem 不发射自有 Cat 2b 信号；灵材变更通过 GSM Cat 1 传播）
- ADR-0009（卡牌效果引擎——`RandomNumberGenerator` 独立实例的 PRD 模式先例）
