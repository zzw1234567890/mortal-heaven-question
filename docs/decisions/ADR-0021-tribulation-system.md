# ADR-0021：渡劫突破系统 — Feature Autoload 编排器 + CombatSystem 配置复用

## 状态
Accepted（2026-07-26——Feature 层审查通过。修复：InputManager ADR-0004（正确编号）。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Progression |
| **知识风险** | LOW（渡劫系统使用基础引擎 API——Node Autoload、信号系统、Dictionary 状态管理——均为 4.0+ 稳定 API） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md` |
| **使用的截止后 API** | None——核心编排逻辑不依赖 4.4+ 新 API |
| **需要验证** | TribulationSystem 初始化顺序（#24）——需确认在 RealmSystem(#11) 和 CombatSystem(#9) 之后注册；渡劫战中 StatusEffectSystem 对雷伤 debuff 的 tick_all() 调用顺序 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`player.tribulation_state` 和 `player.consecutive_tribulation_failures` 状态所有权；`change_realm()` 原子写入）；ADR-0004（InputManager——准备阶段和渡劫战中的 transition/animation 锁 push/pop）；ADR-0007（三分类信号体系——渡劫生命周期信号分类为 Cat 2b）；ADR-0008（CombatSystem——复用 `battle_start(config)` + `battle_end(result)` 生命周期；`is_tribulation` 战斗配置标志）；ADR-0010（RealmSystem——`realm_up()` 编排调用；`get_realm_property()` 查询天劫 Boss 配置） |
| **启用** | 修为养成系统（`check_breakthrough()` → TribulationSystem 触发入口）；探索系统（渡劫台事件格 → 调用 TribulationSystem）；UI 系统（渡劫准备面板、渡劫战 HUD 雷伤显示、突破动画） |
| **阻塞** | 渡劫突破 Epic（MVP 核心循环——境界提升的唯一途径）；修为养成 Epic（渡劫是修为满后的唯一出口） |
| **排序说明** | Feature 层 ADR。在 ADR-0008（CombatSystem）、ADR-0010（RealmSystem）接受后创建。Autoload 初始化顺序 #24：排在 FormationSystem(#23) 之后。本 ADR 属于 7 个并行创建的批次 ADR 之一（18→25 总 Autoload：ADR-0020 修炼 #20 / 0021 渡劫 #24 / 0022 身份 #21 / 0023 卡组 #22 / 0024 阵法 #23 / 0025 流派 #19 / 0026 剧情 #25）

## 上下文

### 问题陈述

渡劫突破系统管理玩家从一个大境界晋升到下一个大境界的完整流程：修为满值 → 触发渡劫 → 特殊 Boss 战 → 成功/失败结算。GDD `tribulation-system.md` 定义了完整的玩家体验流程，但架构层面需解决 5 个关键决策：

1. **Autoload 决策**：渡劫是编排流程——协调 GSM 锁 + 战斗系统 + 境界系统 + 修为系统——是否需要独立的 Feature Autoload？
2. **战斗复用 vs 专用模式**：渡劫战与普通战斗共享 90% 的机制（7 阶段状态机、费用、出牌、攻击结算），但有独立规则覆盖（雷伤 debuff、不可撤退、无战利品、Boss 阵亡即胜利）。是复用 CombatSystem 还是创建专用战斗模式？
3. **突破流程状态机**：触发 → 准备 → 渡劫战 → 成功/失败结算 —— 状态存放在 GSM 还是 TribulationSystem 内部？
4. **失败惩罚接口**：GDD 定义扣除 10% 修为——通过什么接口？直接操作 GSM 还是通过修为养成系统？
5. **雷伤 debuff 实现归属**：每回合叠层 + 回合末结算伤害 + 不可驱散——作为 StatusEffect 还是 CombatSystem 内置规则？

### 约束

- **Feature 层**：渡劫系统属于 Feature 层——编排 Foundation/Core 层系统。不持有 Foundation 层基础设施职责
- **CombatSystem 复用**：ADR-0008 的 `battle_start(config)` 已支持 `CombatConfig` 字典参数（`enemy_deck_id`, `is_tribulation` 等）——渡劫战应作为特殊战斗配置传入，而非创建第二个战斗系统
- **GSM 状态所有权**：渡劫运行时状态轻量（状态枚举 + 连续失败计数器）——可存入 GSM `player.*` 域，遵循 ADR-0001 模式
- **RealmSystem.realm_up() 复用**：ADR-0010 已定义 `realm_up()` 编排器——渡劫成功后调用它，而非重复实现境界升级逻辑
- **初始化顺序**：TribulationSystem 依赖 RealmSystem(#11)、CombatSystem(#9)、InputManager(#2)、GSM(#1)——必须在它们之后初始化（#24）

### 需求

- 渡劫流程状态机：未就绪 → 可渡劫 → 准备中 → 渡劫战中 → 突破成功/渡劫失败
- 渡劫准备阶段：渡劫丹使用（最多 2 枚）+ 上场角色调整
- 渡劫战特殊规则：雷伤 debuff、不可撤退、Boss 阵亡即胜利、无战利品
- 渡劫成功：调用 `RealmSystem.realm_up()` + 金卡奖励 + 行动力回满 + 新地图解锁
- 渡劫失败：扣除 10% 修为 + 连续失败计数 + 回到探索
- 越阶渡劫：挑战高一级天劫 Boss + 境界压制惩罚 + 额外金卡奖励
- 连续失败保护：3 次失败后解锁"天劫试炼（简单）"选项

## 决策

### 采用方案 A：TribulationSystem Feature Autoload 编排器 + CombatSystem 配置复用

**TribulationSystem** 作为 Feature 层 Autoload（`res://src/feature/tribulation_system.gd`），负责：

1. **渡劫流程编排**：拥有完整的渡劫生命周期状态机——触发条件检查、准备阶段（渡劫丹+角色调整）、战斗阶段（委托 CombatSystem）、结算阶段（成功/失败分支）
2. **CombatSystem 委托**：渡劫战通过 `CombatSystem.battle_start(tribulation_config)` 启动——传入 `is_tribulation: true` 标志 + 天劫 Boss 配置 + 渡劫丹效果修饰。战斗胜负由 CombatSystem 的 `battle_ended` 信号通知——TribulationSystem 监听并执行渡劫专属结算
3. **GSM 轻量状态**：`player.tribulation_state: int`（状态枚举）+ `player.consecutive_tribulation_failures: int`（连续失败计数，可存档）存入 GSM——TribulationSystem 是唯一写入者
4. **修为扣除委托**：渡劫失败时，TribulationSystem 调用 GSM 原子方法扣除修为——不直接操作修为值字段，遵循 ADR-0001 第二层写入契约

**CombatSystem 扩展**：
- `CombatConfig` 新增 `is_tribulation: bool` 和 `tribulation_data: Dictionary`（境界等级、渡劫丹效果、越阶标志）
- 当 `is_tribulation == true`：CombatSystem 在 `battle_start()` 中注册雷伤 StatusEffect 到所有上场角色、禁用撤退按钮、禁用战利品流程、设定 Boss 阵亡即胜利
- 雷伤机制作为 StatusEffect 实例——标记 `non_dispellable: true`、`tick_behavior: LIGHTNING_STACK`——由 StatusEffectSystem 在 Phase 0（准备阶段）统一 tick

### 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│              TribulationSystem (Feature Autoload #24)             │
│                                                                   │
│  ┌─ 渡劫生命周期 API ───────────────────────────────────┐        │
│  │ check_tribulation_ready() → bool                       │        │
│  │   # 查询 GSM.player.cultivation >= max_cultivation     │        │
│  │ trigger_tribulation(trib_type: int) → void              │        │
│  │   # NORMAL=0 | CROSS_REALM=1                           │        │
│  │ start_tribulation_combat() → void                       │        │
│  │   # 委托 CombatSystem.battle_start(tribulation_config)  │        │
│  │ use_tribulation_pill(pill_id: int) → bool               │        │
│  │   # 准备阶段使用渡劫丹——最多 2 枚                       │        │
│  │ get_tribulation_boss_config(realm: int) → Dictionary     │        │
│  │   # 从 RealmSystem 查询天劫 Boss 配置                   │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 渡劫状态机（GSM 持久化）────────────────────────────┐        │
│  │ GSM.player.tribulation_state: TribulationState          │        │
│  │   NOT_READY(0) → READY(1) → PREPARING(2) →             │        │
│  │   IN_COMBAT(3) → SUCCESS(4) | FAILED(5)                │        │
│  │ GSM.player.consecutive_tribulation_failures: int        │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ Cat 2b 信号 ─────────────────────────────────────────┐       │
│  │ tribulation_triggered(realm_level: int)                  │       │
│  │ tribulation_preparation_started()                        │       │
│  │ tribulation_succeeded(old_realm, new_realm, is_cross)    │       │
│  │ tribulation_failed(penalty: int, realm_level: int)       │       │
│  │ tribulation_protection_unlocked()  # 连续 3 次失败       │       │
│  └────────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────┘
         │                   │                   │
         │ 委托战斗           │ 委托境界升级        │ 查询天劫配置
         ▼                   ▼                   ▼
    ┌──────────┐    ┌──────────────┐    ┌──────────────┐
    │CombatSys │    │ RealmSystem  │    │  GSM /       │
    │(ADR-0008)│    │ (ADR-0010)   │    │ Cultivation  │
    │          │    │              │    │  System      │
    │battle_   │    │ realm_up()   │    │              │
    │start(    │    │ get_realm_   │    │ 修为扣除      │
    │trib_conf│    │ property()   │    │ 状态读写      │
    │)         │    │              │    │              │
    └──────────┘    └──────────────┘    └──────────────┘
```

### 关键接口

#### TribulationState 枚举 + 状态转换

```gdscript
enum TribulationState {
    NOT_READY = 0,   # 修为未满，不可渡劫
    READY = 1,       # 修为已满，可触发渡劫
    PREPARING = 2,   # 渡劫准备阶段（选择渡劫丹+调整角色）
    IN_COMBAT = 3,   # 渡劫战中（委托 CombatSystem）
    SUCCESS = 4,     # 突破成功（瞬时状态——结算后回到 NOT_READY）
    FAILED = 5,      # 渡劫失败（瞬时状态——结算后回到 NOT_READY 或 READY）
}

enum TribulationType {
    NORMAL = 0,      # 正常渡劫——挑战同境界天劫 Boss
    CROSS_REALM = 1, # 越阶渡劫——挑战高一级天劫 Boss
}
```

#### 渡劫触发流程

```gdscript
## 修为养成系统调用——检查是否可渡劫
func check_tribulation_ready() -> bool:
    if GSM.player.tribulation_state != TribulationState.NOT_READY:
        return false  # 已在渡劫流程中
    var max_cult: int = RealmSystem.get_current_property(&"max_cultivation")
    return GSM.player.cultivation >= max_cult

## 玩家在渡劫台触发渡劫
func trigger_tribulation(trib_type: int = TribulationType.NORMAL) -> void:
    if not check_tribulation_ready():
        push_warning("TribulationSystem: trigger_tribulation() called but not ready")
        return

    # 越阶渡劫验证——不能跳 2 级以上
    if trib_type == TribulationType.CROSS_REALM:
        var next_realm: int = GSM.player.realm_level + 1
        if next_realm > RealmSystem.realm_table.size():
            push_warning("TribulationSystem: cross-realm tribulation exceeds max realm")
            return

    # 进入准备阶段
    GSM._set_tribulation_state(TribulationState.PREPARING)
    InputManager.push_lock(LockType.DIALOGUE, &"tribulation_system")
    tribulation_triggered.emit(GSM.player.realm_level)
    # UI 监听 → 展示渡劫准备面板
```

#### 渡劫准备阶段——渡劫丹使用

```gdscript
## 玩家在准备阶段使用渡劫丹
func use_tribulation_pill(pill_id: int) -> bool:
    if GSM.player.tribulation_state != TribulationState.PREPARING:
        return false

    if _active_pills.size() >= MAX_TRIBULATION_PILLS:  # MAX = 2
        push_warning("TribulationSystem: max pills (2) already used")
        return false

    var pill: Dictionary = _get_pill_data(pill_id)
    if pill.is_empty():
        return false

    # 同种不叠加——取最高稀有度
    for existing in _active_pills:
        if existing["type"] == pill["type"]:
            if existing["rarity_tier"] >= pill["rarity_tier"]:
                push_warning("TribulationSystem: same pill type with higher/equal rarity already active")
                return false
            else:
                _active_pills.erase(existing)  # 替换为更高稀有度
                break

    _active_pills.append(pill)
    return true

# 渡劫丹效果在构建 tribulation_config 时应用
func _build_tribulation_config() -> Dictionary:
    var config := {
        "is_tribulation": true,
        "tribulation_data": {
            "realm_level": GSM.player.realm_level,
            "is_cross_realm": _trib_type == TribulationType.CROSS_REALM,
            "active_pills": _active_pills.duplicate(),
            "boss_config": _get_boss_config(),
        }
    }
    return config
```

#### 渡劫战启动与结算监听

```gdscript
## 玩家确认开始渡劫
func start_tribulation_combat() -> void:
    GSM._set_tribulation_state(TribulationState.IN_COMBAT)
    InputManager.pop_lock(&"tribulation_system")
    InputManager.push_lock(LockType.TRANSITION, &"tribulation_system")

    var config: Dictionary = _build_tribulation_config()
    CombatSystem.battle_start(config)
    # ⚠️ 不在此处 await——战斗生命周期由 CombatSystem 管理
    # TribulationSystem 监听 battle_ended 信号进行渡劫专属结算

## 监听 CombatSystem.battle_ended —— 渡劫专属结算
func _on_battle_ended(result: int, rewards: Dictionary) -> void:
    if GSM.player.tribulation_state != TribulationState.IN_COMBAT:
        return  # 非渡劫战——忽略

    InputManager.pop_lock(&"tribulation_system")

    if result == CombatSystem.CombatResult.VICTORY:
        _handle_tribulation_success()
    else:  # DEFEAT or RETREAT（渡劫战中撤退不可用——此路径仅 DEFEAT）
        _handle_tribulation_failure()

func _handle_tribulation_success() -> void:
    var old_realm: int = GSM.player.realm_level

    # 1. 调用 RealmSystem.realm_up()——编排境界升级全流程
    #    realm_up() 内部：GSM.change_realm() + realm_upgraded 信号
    #    realm_upgraded 信号触发：CultivationSystem 溢出结算 +
    #    ExplorationSystem 新地图解锁 + CardSystem 卡池扩展
    RealmSystem.realm_up(old_realm)

    # 2. 金卡奖励——从新境界卡池随机选取
    var new_realm: int = GSM.player.realm_level
    var gold_card: CardTemplate = CardSystem.get_random_card_from_pool(
        RealmSystem.get_realm_property(new_realm, &"card_pool_tier"),
        CardRarity.GOLD
    )
    GSM.add_card_to_collection(CardSystem.serialize_instance(
        CardSystem.create_instance(gold_card.id)
    ))

    # 3. 越阶渡劫额外金卡
    if _trib_type == TribulationType.CROSS_REALM:
        var extra_gold: CardTemplate = CardSystem.get_random_card_from_pool(
            RealmSystem.get_realm_property(new_realm, &"card_pool_tier"),
            CardRarity.GOLD
        )
        GSM.add_card_to_collection(CardSystem.serialize_instance(
            CardSystem.create_instance(extra_gold.id)
        ))

    # 4. 行动力回满——通过信号委托（RealmSystem.realm_upgraded 已触发）
    #    ActionPoints 系统监听 realm_upgraded → 回满行动力

    # 5. 重置连续失败计数器
    GSM._set_consecutive_tribulation_failures(0)

    # 6. 发射渡劫成功信号
    GSM._set_tribulation_state(TribulationState.SUCCESS)
    tribulation_succeeded.emit(old_realm, new_realm, _trib_type == TribulationType.CROSS_REALM)
    GSM._set_tribulation_state(TribulationState.NOT_READY)

func _handle_tribulation_failure() -> void:
    var max_cult: int = RealmSystem.get_current_property(&"max_cultivation")
    var penalty: int = maxi(floor(max_cult * 0.1), 50)  # 最少损失 50 修为
    var current: int = GSM.player.cultivation
    var new_cult: int = maxi(current - penalty, 0)

    # 通过 GSM 第二层原子方法扣除修为
    GSM.apply_cultivation_change(new_cult - current)
    # ⚠️ 需 GSM 新增方法或复用现有修为变更接口

    # 连续失败计数
    var failures: int = GSM.player.consecutive_tribulation_failures + 1
    GSM._set_consecutive_tribulation_failures(failures)

    GSM._set_tribulation_state(TribulationState.FAILED)
    tribulation_failed.emit(penalty, GSM.player.realm_level)

    if failures >= 3:
        tribulation_protection_unlocked.emit()

    GSM._set_tribulation_state(TribulationState.NOT_READY)
```

#### CombatSystem 渡劫扩展契约

```gdscript
# CombatSystem 在 battle_start() 中检查 is_tribulation 标志
# 当 is_tribulation == true 时，执行渡劫专属初始化：

# 1. 注册雷伤 StatusEffect 到所有上场角色
func _register_lightning_debuff(trib_data: Dictionary) -> void:
    var realm_level: int = trib_data["realm_level"]
    var layers_per_turn: int = _get_lightning_layers_per_turn(realm_level)

    # 查询渡劫丹效果——是否有天劫护体丹
    for pill in trib_data.get("active_pills", []):
        if pill["type"] == "tribulation_protection_pill":
            layers_per_turn = 1  # 固定覆盖——每 2 回合叠 1 层
            break

    for character in battle.player_field:
        var lightning_effect := LightningEffectInstance.new()
        lightning_effect.layers_per_turn = layers_per_turn
        lightning_effect.non_dispellable = true  # 不可驱散
        lightning_effect.source = "tribulation"
        StatusEffectSystem.apply_to_character(character.id, lightning_effect)

# 2. 禁用撤退——渡劫战中 retreat() 返回 false
# 3. Boss 阵亡即胜利——Phase 5 敌方行动结束后检查：
#    if tribulation_boss_died: battle_end(VICTORY)  # 不清小怪
# 4. 无战利品——Phase 6 battle_end(VICTORY) 跳过 CardRewardSystem
# 5. 渡劫丹效果应用：
#    - 避雷符丹：首回合添加 thunder_immune_stacks
#    - 凝神丹：全队 DEF +2
#    - 破劫丹：Boss HP *= 0.8
```

#### 雷伤 StatusEffect 设计

```gdscript
## 雷伤 debuff——渡劫战专属 StatusEffect 实例
class LightningEffectInstance:
    extends StatusEffectInstance

    var layers_per_turn: int = 1       # 每回合叠层数
    var current_layers: int = 0        # 当前累计层数
    var thunder_immune_stacks: int = 0 # 雷免剩余次数（避雷符丹）

    func tick(target: Character) -> void:
        # 先施加新层（每回合末）
        current_layers += layers_per_turn

        # 结算伤害——雷免优先
        var damage: int = current_layers
        if thunder_immune_stacks > 0:
            damage = 0
            thunder_immune_stacks -= 1

        if damage > 0:
            target.take_damage(damage, DamageType.TRUE)  # 不可减免

    func on_combat_end() -> void:
        # 渡劫战结束后自动清除——不跨战斗保留
        queue_free()
```

### GSM 新增域与方法

渡劫系统需要在 GSM 中新增以下轻量状态（遵循 ADR-0001 第二层写入契约）：

| GSM 域 | 类型 | 写入者 | 持久化 | 说明 |
|--------|------|--------|--------|------|
| `player.tribulation_state` | int (TribulationState 枚举) | TribulationSystem | 否（瞬态） | 渡劫流程状态机当前状态 |
| `player.consecutive_tribulation_failures` | int | TribulationSystem | **是**（跨会话保留） | 连续渡劫失败计数——连续失败保护机制依赖 |

**需新增的 GSM 第二层方法**：

```gdscript
GSM._set_tribulation_state(state: int) → void
  # 写入 player.tribulation_state + 发射 batch_updated

GSM._set_consecutive_tribulation_failures(count: int) → void
  # 写入 player.consecutive_tribulation_failures + 发射 batch_updated
  # ⚠️ 此字段持久化到存档——渡劫失败保护跨会话保留

GSM.apply_cultivation_change(delta: int) → void
  # 正值=增加修为，负值=扣除修为
  # 兜底：结果不会 < 0
  # 替代方案：复用修为养成系统的 add_cultivation()——需确认接口是否支持负值
```

### 信号分类（ADR-0007 合规）

| 信号 | 分类 | 发射时机 | 消费者 | 载荷 |
|------|------|---------|--------|------|
| `tribulation_triggered` | Cat 2b | `trigger_tribulation()` 成功后 | UI（展示渡劫准备面板）、探索系统（隐藏地图 UI） | `(realm_level: int)` |
| `tribulation_preparation_started` | Cat 2b | 准备阶段 UI 就绪后 | UI（渡劫丹选择界面）、音频（渡劫准备 BGM） | 无参数 |
| `tribulation_succeeded` | Cat 2b | 渡劫成功结算完毕后（`realm_up()` + 金卡奖励 + 计数器重置之后） | UI（突破动画）、音频（突破音效）、成就系统（越阶成就检测） | `(old_realm: int, new_realm: int, is_cross_realm: bool)` |
| `tribulation_failed` | Cat 2b | 渡劫失败结算完毕后（修为扣除 + 失败计数更新后） | UI（失败面板）、音频（失败音效） | `(penalty: int, realm_level: int)` |
| `tribulation_protection_unlocked` | Cat 2b | 连续失败计数达到 3 时 | UI（天劫庇护提示）、探索系统（渡劫台新增选项） | 无参数 |

非信号——直接方法调用（编排器模式）：
- `CombatSystem.battle_start(config)` — 需要保证（战斗启动）
- `RealmSystem.realm_up(level)` — 需要保证（境界升级原子操作）
- `CardSystem.get_random_card_from_pool(tier, rarity)` — 需要返回值（金卡生成）
- `StatusEffectSystem.apply_to_character(id, effect)` — 需要保证（雷伤注册）

## 考虑的替代方案

### 替代方案 B：渡劫战独立战斗模式——TribulationCombatSystem 独立 Autoload

- **描述**：渡劫战不复用 CombatSystem——创建独立的 `TribulationCombatSystem` 处理渡劫专属战斗逻辑
- **优点**：渡劫战斗逻辑完全隔离——修改不影响普通战斗；雷伤机制、不可撤退、无战利品等规则内聚在一个系统内
- **缺点**：大量重复代码——7 阶段状态机、费用管理、出牌流程、攻击结算、AI 敌方行动全部重复实现；CombatSystem 的 bug 修复和平衡调整需要同步到 TribulationCombatSystem；违反 DRY 原则
- **拒绝原因**：渡劫战与普通战斗共享 90% 机制——唯一差异是雷伤 debuff + 不可撤退 + 无战利品 + Boss 即胜。这些差异完全可以通过 CombatConfig 参数化和 StatusEffect 扩展来表达，无需复制整个战斗系统。

### 替代方案 C：渡劫逻辑全部嵌入 RealmSystem

- **描述**：不创建 TribulationSystem——渡劫流程编排、渡劫丹管理、CombatSystem 委托全部由 RealmSystem 处理
- **优点**：减少 1 个 Autoload（停留在 18 个——本批次扩张至 25）；渡劫与境界升级紧密相关——放在同一系统概念内聚
- **缺点**：RealmSystem 的职责边界被打破——ADR-0010 将其定义为"静态数据持有 + 查询 + realm_up() 编排"，加入渡劫流程状态机和渡劫丹管理会使其膨胀为上帝对象；CombatSystem 委托逻辑与 RealmSystem 的数据查询职责无关；未来如果渡劫机制独立演化（如新增渡劫类型、渡劫事件链），修改 RealmSystem 的风险高于修改独立系统
- **拒绝原因**：RealmSystem 的核心职责是境界数据查询和 `realm_up()` 原子编排——它是被调用者，不是流程编排者。渡劫系统是主动编排者——协调输入锁、战斗系统、境界系统、修为系统的时序——这是一个独立的编排职责。

### 替代方案 D：渡劫状态机完全由 GSM 管理——不创建 Autoload

- **描述**：渡劫状态机和流程逻辑全部写入 GSM——`GSM.trigger_tribulation()`、`GSM.resolve_tribulation()` 直接在 GSM 中实现
- **优点**：零新增 Autoload——所有渡劫状态天然在 GSM 中；状态一致性最强——无跨 Autoload 同步问题
- **缺点**：GSM 成为更重的上帝对象——渡劫流程编排、渡劫丹效果、金卡奖励逻辑全部嵌入 GSM；违反 ADR-0001 的"GSM 不应积累业务逻辑"原则；战斗委托逻辑与状态管理混杂，调试困难
- **拒绝原因**：ADR-0001 明确声明 GSM 应抵制积累业务逻辑——"我应该在发放修为之前检查 curse_flag 吗？——不，那属于行为系统，而非 GSM"。渡劫流程编排恰好是此类业务逻辑——GSM 提供状态读写，TribulationSystem 拥有流程逻辑。

## 后果

### 积极的

- **CombatSystem 复用最大化**：渡劫战仅通过 `CombatConfig.is_tribution = true` + StatusEffect 扩展实现——不重复战斗逻辑，CombatSystem 的 bug 修复和平衡调整自动适用于渡劫战
- **雷伤作为 StatusEffect**：雷伤 debuff 遵循 ADR-0011 的模板-实例模型 + `tick_all()` 结算——与流血、中毒、灼烧等持续伤害效果使用相同的结算通道，Phase 0 统一 tick 保证顺序确定性
- **编排器职责清晰**：TribulationSystem 不拥有战斗逻辑（委托 CombatSystem）、不拥有境界数据（查询 RealmSystem）、不拥有修为扣除（委托 GSM/CultivationSystem）——它是纯粹的流程编排器
- **连续失败保护跨会话持久化**：`consecutive_tribulation_failures` 存入 GSM 并持久化到存档——玩家读档后不会丢失保护状态，防止"死锁在某个境界"的 Roguelike 反模式
- **信号分类合规**：5 个 Cat 2b 信号语义清晰——`tribulation_succeeded` 和 `tribulation_failed` 携带消费者（UI/音频/成就）所需的最小信息。金卡奖励、境界变更、修为变更通过现有 GSM 信号传播——无重复数据信号
- **越阶渡劫自然表达**：通过 `trib_type` 枚举切换 Boss 配置查询——不需要独立代码路径。境界压制由 CombatSystem 在伤害计算中自动应用（已有 `realm_penalty()` 逻辑）

### 消极的

- **增加 1 个 Autoload（#24）**：项目 Autoload 从 18 个增至 25 个（本批次 7 个 ADR 并行创建：ADR-0020 修炼/0021 渡劫/0022 身份/0023 卡组/0024 阵法/0025 流派/0026 剧情）。本批次是 Autoload 数量的重大里程碑（18→25）。TribulationSystem 注册为 #24，排在 FormationSystem（#23）之后。后续 ADR 需持续跟踪 Autoload 扩容趋势
- **CombatSystem 需要渡劫感知**：`battle_start()` 中增加 `is_tribulation` 分支逻辑——CombatSystem 不再是纯通用战斗系统，而是携带渡劫专属规则。缓解措施：渡劫分支仅约 30 行——作为配置驱动的规则覆盖，而非硬编码的独立模式
- **渡劫准备阶段与战斗备战的相似但不同**：准备阶段允许多种渡劫丹选择 + 上场角色调整，与战斗系统的备战阶段类似但有差异——需要独立 UI 面板。UX 系统需额外处理
- **修为扣除接口设计**：渡劫失败扣除修为需要一个明确的接口——如果修为养成系统未定义"扣除修为"方法，需要在 GSM 层新增 `apply_cultivation_change(delta)`。当前设计中已纳入此方法

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Autoload 数量持续增长（25→28+） | 中 | 启动时间增加、初始化顺序复杂度 | 当前 25 个（本批次 7 个 ADR 并行创建）。若达到 28+，需评估合并 Feature 层 Autoload。建议将小型系统（如卡组编辑、开局身份）作为非 Autoload 服务类 |
| 雷伤 StatusEffect 实现与现有 StatusEffect 机制冲突（不可驱散、每回合叠层） | 低 | 雷伤无法正确结算——伤害时机错误或叠层数异常 | StatusEffectSystem 需支持 `non_dispellable` 标志和自定义 `tick_behavior`。已在 ADR-0011 的扩展性设计中预留——本需求恰好验证其扩展能力 |
| CombatSystem 渡劫分支引入回归 | 低 | `is_tribulation=false` 的普通战斗行为被意外修改 | 回归测试：GUT 测试套件验证普通战斗 7 阶段流程 + 撤退 + 战利品在 `is_tribulation=false` 下行为不变 |
| 渡劫准备阶段玩家异常退出（崩溃/强制关闭） | 低 | 渡劫状态卡在 PREPARING——无法再次触发渡劫 | GSM `tribulation_state` 为瞬态（不持久化）——重新加载游戏后自动回到 NOT_READY。渡劫丹消耗在确认开始渡劫时才应用，准备阶段退出不消耗 |
| `realm_upgraded` 信号 + `tribulation_succeeded` 信号顺序导致 UI 闪烁 | 低 | 境界 HUD 在渡劫动画前刷新——视觉不一致 | `tribulation_succeeded` 在 `realm_upgraded` **之后**发射（金卡奖励 + 计数器重置完成后）。UI 通过 `tribulation_succeeded` 触发全屏突破动画——在动画期间隐藏 HUD 刷新 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| tribulation-system.md | §1 渡劫触发条件——修为满后在地图渡劫台触发 | `check_tribulation_ready()` + `trigger_tribulation()`——修为满值检查 + 探索系统渡劫台事件格调用入口 |
| tribulation-system.md | §2 渡劫准备阶段——渡劫丹使用（最多 2 枚）+ 上场角色调整 | `use_tribulation_pill()` 管理渡劫丹（同种不叠加、总上限 2 枚）；准备阶段通过 `InputManager.push_lock(DIALOGUE)` 锁 gameplay |
| tribulation-system.md | §3 渡劫战斗规则——雷伤 debuff + 不可撤退 + 无战利品 + Boss 即胜 | CombatSystem `is_tribulation` 配置驱动——雷伤作为 `LightningEffectInstance`（non_dispellable StatusEffect）；撤退禁用；战利品跳过；Boss 阵亡即判胜利 |
| tribulation-system.md | §4 渡劫成功——realm_up() + 金卡奖励 + 行动力回满 | `_handle_tribulation_success()` 调用 `RealmSystem.realm_up()` → `realm_upgraded` 信号触发连锁结算；`CardSystem.get_random_card_from_pool()` 生成金卡 |
| tribulation-system.md | §5 渡劫失败——修为扣除 10% + 连续失败计数 | `_handle_tribulation_failure()` 通过 GSM 原子方法扣除修为；`consecutive_tribulation_failures` 持久化计数 |
| tribulation-system.md | §6 越阶渡劫——挑战高一级天劫 Boss + 额外金卡 | `TribulationType.CROSS_REALM` 切换 Boss 配置查询（+1 境界）+ 额外金卡奖励 |
| tribulation-system.md | §7 连续失败保护——3 次失败后解锁简单模式 | `consecutive_tribulation_failures >= 3` → `tribulation_protection_unlocked` 信号 + 渡劫台简单选项（Boss HP-30%） |
| tribulation-system.md | §状态与转换——6 状态渡劫生命周期 | `TribulationState` 枚举（NOT_READY → READY → PREPARING → IN_COMBAT → SUCCESS/FAILED）存入 GSM |

## 初始化顺序

Godot Autoload 在 `project.godot` 的 `[autoload]` 部分按列表顺序初始化。TribulationSystem 必须在以下依赖之后注册：

```
推荐初始化位置: #24（在 FormationSystem #23 之后）

完整 Autoload 链（1-25）:
#1 GSM → #2 InputManager → #3 SceneManager → #4 SaveLoadSystem →
#5 EventSystem → #6 CardSystem → #7 CostSystem → #8 StatusEffectSystem →
#9 CombatSystem → #10 CardEffectEngine → #11 RealmSystem →
#12 ProgressionSystem → #13 BindingManager → #14 ExplorationSystem →
#15 FactionSystem → #16 ResourceSystem → #17 DeploymentSystem → #18 AISystem →
#19 SchoolSystem → #20 CultivationSystem →
#21 IdentitySelectionSystem → #22 DeckEditingSystem →
#23 FormationSystem → #24 TribulationSystem → #25 StorySystem
```

`TribulationSystem._ready()` 检查所有依赖就绪：
- `GSM._initialized` — 状态读写
- `CombatSystem` — 战斗委托
- `RealmSystem` — 境界数据查询
- `InputManager` — 锁管理

## 性能影响

- **CPU**：渡劫流程编排（触发→准备→结算）仅事件驱动——非每帧执行。`check_tribulation_ready()` 在修为变更时调用（O(1) 字典查询，<0.001ms）。渡劫战中的雷伤 StatusEffect tick 走 StatusEffectSystem 现有通道——每次 tick <0.01ms
- **内存**：TribulationSystem Autoload 实例 <5KB（状态枚举 + 渡劫丹缓存）。GSM 新增字段 <10B
- **加载时间**：`_ready()` 为空——仅验证依赖就绪，无异步初始化。不影响启动时间

## 迁移计划

本 ADR 创建新系统，非修改现有代码。实现顺序：

1. 在 GSM 中新增 `tribulation_state` 和 `consecutive_tribulation_failures` 域——ADR-0001 补充
2. 创建 `res://src/feature/tribulation_system.gd` —— TribulationSystem Autoload（状态机 + 编排 API）
3. 在 `project.godot` 中注册 Autoload #24——排在 FormationSystem（#23）之后（总 25 个）
4. 在 CombatSystem 中新增 `is_tribulation` 配置分支——雷伤注册 + 撤退禁用 + 战利品跳过
5. 在 StatusEffectSystem 中新增 `LightningEffectInstance` 类型——`non_dispellable` + `tick_behavior`
6. 修为养成系统实现时：`check_breakthrough()` → 调用 `TribulationSystem.check_tribulation_ready()`
7. 探索系统实现时：渡劫台事件格 → 调用 `TribulationSystem.trigger_tribulation()`

## 验证标准

- **GIVEN** 修为已满，**WHEN** 调用 `check_tribulation_ready()`，**THEN** 返回 true
- **GIVEN** 修为未满，**WHEN** 调用 `trigger_tribulation()`，**THEN** push_warning + 不进入准备阶段
- **GIVEN** 渡劫准备阶段，**WHEN** 使用第 3 枚渡劫丹，**THEN** 返回 false + push_warning
- **GIVEN** 渡劫准备阶段使用 2 枚同种渡劫丹，**WHEN** 检查激活效果，**THEN** 仅保留高稀有度版本
- **GIVEN** 渡劫战配置 `is_tribulation = true`，**WHEN** CombatSystem 初始化战斗，**THEN** 雷伤 StatusEffect 注册到所有上场角色 + 撤退按钮不可交互
- **GIVEN** 渡劫战胜利，**WHEN** `battle_ended(VICTORY)` 触发，**THEN** `RealmSystem.realm_up()` 被调用 + 金卡已发放 + 连续失败计数器重置为 0
- **GIVEN** 渡劫战失败，**WHEN** `battle_ended(DEFEAT)` 触发，**THEN** 修为扣除 max_cult × 0.1 + 连续失败计数 +1
- **GIVEN** 连续失败 3 次，**WHEN** 第 4 次触发渡劫，**THEN** 渡劫台出现"天劫试炼（简单）"选项
- **GIVEN** 越阶渡劫，**WHEN** 检查 Boss 配置，**THEN** Boss 境界 = 玩家境界 +1
- **GIVEN** 渡劫战后回到探索，**WHEN** 检查雷伤 debuff，**THEN** 不存在（已随战斗结束清除）

## 相关决策

- ADR-0001（游戏状态管理器——`tribulation_state` 和 `consecutive_tribulation_failures` 状态所有权）
- ADR-0004（输入管理器——渡劫准备阶段和渡劫战中的锁 push/pop）
- ADR-0007（信号分类——5 个 Cat 2b 渡劫生命周期信号）
- ADR-0008（战斗系统——`is_tribulation` 配置驱动渡劫战特殊规则；`battle_start()` / `battle_ended()` 生命周期委托）
- ADR-0010（境界系统——`realm_up()` 突破编排调用；`get_realm_property()` 天劫 Boss 配置查询）
- ADR-0011（状态效果系统——雷伤作为 `non_dispellable` StatusEffect 实例）
