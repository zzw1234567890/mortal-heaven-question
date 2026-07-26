# ADR-0017：AI 系统 — Feature 层独立 Autoload + 效果引擎统一路径 + Boss 内部阶段状态机

## 状态
Accepted（2026-07-26——Feature 层审查通过。修复：Foundation 计数 7→5。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / AI |
| **知识风险** | LOW（Dictionary 操作、信号系统、Autoload 模式、Resource 加载均为 4.x 成熟 API。不依赖 4.4+ 新特性） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **使用的截止后 API** | None——核心逻辑（决策树、权重计算、状态机）不依赖 4.4+ 新增 API |
| **需要验证** | `EnemyTemplate` Resource 在 `res://assets/enemies/` 目录下的加载策略——若敌人模板超过 50 个，需评估同步 `ResourceLoader.load()` vs `load_threaded_request()`；AI 决策在 Phase 6 的执行时间（最坏场景 6 敌人 × 5 技能 × evaluate_effect() 100μs = 3ms——远在 16.6ms 帧预算内）；Boss 阶段转换动画期间的 `call_deferred()` 延迟与 CombatSystem Phase 6 的交互——需 GUT 集成测试 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——只读查询 `player.realm_level` 用于难度缩放；不写入 GSM）；ADR-0007（三分类信号体系——AI 决策结果通过 Cat 2b 信号 `ai_action_executed` / `boss_phase_transitioned` 广播）；ADR-0008（CombatSystem——Phase 6 `ENEMY_TURN` 阶段通过直接方法调用 `AISystem.execute_turn()` 驱动 AI；AI 返回行动指令列表给 CombatSystem 执行；敌方角色阵亡/上场事件由 CombatSystem 通知 AI 更新内部布阵状态）；ADR-0009（CardEffectEngine——敌方技能效果通过 `CardEffectEngine.resolve()` 统一结算路径；AI 评估接口 `evaluate_effect()` / `simulate_chain()` / `GameStateSnapshot` 由 ADR-0009 定义）；ADR-0010（RealmSystem——`get_realm_property(level, key)` 查询玩家境界属性用于难度缩放公式 `scale = 1.0 + gap × 0.3`） |
| **启用** | ADR-0013（BindingSystem——精英/Boss 预配置绑定在 AI 系统 `battle_start()` 时调用 `BindingManager.register_binding()` 注册——AI 系统持有敌人模板数据，负责将模板中的预配置绑定写入 BindingManager）；前向引用：阵法系统（尚无 ADR——精英/Boss 阵法部署由 AI 系统在阶段6通过阵法系统接口部署/覆盖）；前向引用：上场阵位系统（尚无 ADR——敌方 AI 在阶段6自动补位/调整前排/后排布阵） |
| **阻塞** | AI Epic（敌方所有战斗决策——技能选择、目标选择、阵法部署、绑定注册、阶段性转换、撤退判定）；战斗 Epic（Phase 6 `ENEMY_TURN` 阶段的实现依赖 `AISystem.execute_turn()`）；Boss 战斗 Epic（阶段转换动画/无敌帧/行为切换依赖 `AISystem._check_phase_transition()`） |
| **排序说明** | Feature 层——在 ADR-0008（CombatSystem）、ADR-0009（CardEffectEngine）、ADR-0010（RealmSystem）、ADR-0013（BindingSystem）、ADR-0016（DeploymentSystem——AI 依赖 `is_targetable()`）被接受后编写。AISystem 依赖 DeploymentSystem（#17）提供目标合法性查询 + CombatSystem（#9）的 Phase 6 驱动——初始化顺序需排在两者之后。完整 Autoload 链 18 个：GSM #1 / InputManager #2 / SceneManager #3 / SaveLoad #4 / EventSystem #5 / CardSystem #6 / CostSystem #7 / StatusEffectSystem #8 / CombatSystem #9 / CardEffectEngine #10 / RealmSystem #11 / ProgressionSystem #12 / BindingManager #13 / ExplorationSystem #14 / FactionSystem #15 / ResourceSystem #16 / DeploymentSystem #17 / AISystem #18。AISystem._ready() 执行时 #1-#17 已完全初始化 |

## 上下文

### 问题陈述

`ai-system.md` GDD 定义了三级敌方智能层级（普通/精英/Boss）、预定义技能池（非随机抽卡）、加权优先级决策树、目标选择逻辑、精英/Boss 预配置绑定与阵法部署、Boss 多阶段转换、撤退逻辑、难度缩放等完整设计。但 GDD 关注的是"AI 应该表现出什么行为"，本 ADR 需要解决的是"AI 系统如何在 Godot 4.6 中工程化实现"：

1. **模块归属与生命周期**：AI 系统仅用于战斗，但有独立的 EnemyTemplate 加载需求和评估接口。是作为 CombatSystem 的内部模块还是独立的 Feature 层 Autoload？
2. **敌方技能结算路径**：敌方技能效果走 CardEffectEngine 统一结算路径（复用效果解析代码），还是 AI 系统内部自行处理？
3. **AI 决策的同步性**：决策计算量可控（最多 6 敌人 × 5 技能 = 30 次评估），但 Boss 多阶段多技能场景下是否需要异步？
4. **EnemyTemplate 数据格式**：Resource 文件 vs JSON 配置 vs Dictionary 硬编码——选择影响策划编辑体验和加载性能
5. **Boss 阶段转换的状态管理归属**：转换触发/行为替换/无敌帧/技能加锁——由 AI 系统内部状态机管理还是 CombatSystem 编排？

`architecture.md` 将 AI 系统归入 Feature 层——消费 CombatSystem、CardEffectEngine、CardSystem。

### 约束

- **Feature 层定位**：AI 系统是 Feature 层 Autoload——依赖 Foundation 层（GSM 只读）、Core 层（RealmSystem 难度缩放查询）和 Feature 层（CombatSystem 阶段驱动、CardEffectEngine 效果结算与评估）
- **三级智能层级**（来自 GDD）：普通（简单优先级）、精英（战术考量 + 绑定 + 阵法）、Boss（多阶段转换 + 独特技能组）
- **敌方卡组为预定义技能池**：非随机抽卡——每回合从 `skill_pool` 中选择 1~2 个可用技能（受冷却和费用限制）
- **CombatSystem 驱动模式**：AI 系统是被动服务——仅在 Phase 6（`ENEMY_TURN`）被 CombatSystem 通过直接方法调用 `execute_turn()` 驱动，不订阅 CombatSystem 信号
- **GSM 不直接写入**：AI 系统不调用任何 GSM 写入方法——敌方行动指令返回给 CombatSystem，由 CombatSystem 通过 CardEffectEngine 结算后写入 GSM
- **EnemyTemplate 模板/实例分离**：EnemyTemplate（Resource，`.tres`）只读——运行时敌人实例状态（当前 HP、技能冷却、阶段索引、绑定/阵法引用）在 `EnemyBattleState`（RefCounted）上管理
- **帧预算**：`execute_turn()` 最坏场景（6 敌人 × 5 技能评估 + Boss 阶段检查 + 阵法决策）< 5ms——AI 仅 Phase 6 执行，非每帧调用

### 需求

- 三级智能层级的决策树实现（普通/精英/Boss 各有独立的 `_decide_action()` 逻辑分支）
- 加权优先级分数 + 战场状态修正系数（治疗/防御/集火/阵法部署修正）
- 目标选择逻辑（集火模式/分散模式/嘲讽强制目标/穿透攻击）
- 精英/Boss 预配置绑定在 `battle_start()` 时通过 BindingManager 注册
- Boss 阶段转换的内部状态机（HP 阈值触发 → 行为配置替换 → 新技能解锁 → 无敌动画帧 → 冷却重置）
- 撤退逻辑（非 Boss 敌人 HP < 阈值 → 50% 概率撤退 → 玩家胜利但奖励减半）
- 难度缩放（玩家境界高于敌人基准 → `scale = 1.0 + gap × 0.3` 提升敌人 HP/ATK/DEF）
- EnemyTemplate Resource 加载——策划在 Godot Inspector 中编辑，运行时由 `EnemyFactory` 创建 `EnemyBattleState` 实例

## 决策

**AI 系统实现为 Feature 层独立 Autoload（AISystem #18），负责敌方所有战斗决策。EnemyTemplate 使用 Godot Resource（`.tres`）格式——策划在 Inspector 中编辑敌人模板数据，运行时由 EnemyFactory 创建轻量级 EnemyBattleState（RefCounted）实例。敌方技能效果统一走 CardEffectEngine.resolve() 结算路径（复用效果解析、触发链管理、PRD 引擎）。AI 决策在主线程同步执行（GDScript 单线程，决策量可控——最坏 6 敌人 × 5 技能 = 30 次 evaluate_effect()，约 3ms）。Boss 阶段转换由 AI 系统内部状态机管理——CombatSystem 仅在 Phase 6 调用 `execute_turn()`，AI 在决策前自主检查并触发阶段转换。**

### 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                    AISystem (Autoload #18)                        │
│                                                                    │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐   │
│  │  EnemyFactory     │  │  决策引擎          │  │  BossPhaseMgr  │   │
│  │  load(template_id)│  │  _decide_action()   │  │  check()       │   │
│  │  → EnemyBattleSt  │  │  _evaluate_skills()  │  │  transition()  │   │
│  │                   │  │  _select_target()    │  │  get_phase()   │   │
│  └──────────────────┘  └──────────────────┘  └──────────────┘   │
│                                                                    │
│  EnemyTemplate (Resource, .tres)  ←─ 策划在 Inspector 中编辑       │
│  EnemyBattleState (RefCounted)    ←─ 运行时可变状态（HP/冷却等）  │
│                                                                    │
│  API:                                                              │
│    load_templates() → void                                         │
│    create_enemy_roster(template_ids) → Array[EnemyBattleState]     │
│    execute_turn(field_state) → Array[AIAction]                     │
│    register_preconfigured_bindings(enemy) → void                   │
└──────────────┬───────────────────────────────────────────────────┘
               │ 依赖（只读查询 + 直接调用）
               ▼
┌──────────┬──────────────────┬──────────────────┬────────────────┐
│ GSM      │  RealmSystem     │  CardEffectEngine │  CombatSystem  │
│ .player  │  .get_realm_     │  .resolve()       │  (Phase 6 驱动)│
│ .realm   │  property()      │  .evaluate_       │  execute_turn()│
│          │                  │  effect()         │                │
└──────────┴──────────────────┴──────────────────┴────────────────┘
┌──────────────────┬──────────────────┐
│ BindingManager   │  CardSystem      │
│ (预配置绑定注册) │  (模板查询)      │
└──────────────────┴──────────────────┘
```

### 关键接口

```gdscript
# === EnemyTemplate Resource ===
# 文件位置：res://assets/enemies/enemy_template.gd
class_name EnemyTemplate
extends Resource

## 策划在 Godot Inspector 中编辑的敌人定义
@export var template_id: StringName           # 唯一标识（如 &"moyuan_boss_stage1"）
@export var display_name: String               # 显示名称（如"墨渊（夺舍）"）
@export var realm: int = 1                     # 境界等级 [1, 5]
@export var is_elite: bool = false
@export var is_boss: bool = false
@export var base_hp: int                       # 基础生命
@export var base_attack: int                   # 基础攻击
@export var base_defense: int                  # 基础防御
@export var faction_tags: Array[StringName]    # 阵营标签
@export var formation_limit: int = 0           # 可用阵法位（普通0/精英1/Boss2）
@export var front_slot: bool = false           # ture=固定前排；false=AI自动分配
@export var behavior_profile: BehaviorProfile  # 行为配置（内嵌 Resource）
@export var skill_pool: Array[SkillEntry]       # 技能池
@export var preconfigured_bindings: Array[StringName]  # 预配置绑定卡牌模板ID
@export var preconfigured_formations: Array[StringName] # 预配置阵法模板ID
@export var phase_transitions: Array[BossPhaseTransition] # Boss专属
@export var reward_config: RewardConfig         # 战斗奖励配置

## BehaviorProfile 内嵌 Resource
#   @export var aggression: float = 0.7       # 攻击性 [0.0, 1.0]
#   @export var focus_fire: float = 0.6        # 集火倾向 [0.0, 1.0]
#   @export var front_priority: float = 0.5    # 前排维护倾向 [0.0, 1.0]
#   @export var retreat_threshold: float = 0.0 # 撤退阈值（0 = 不撤退）

## SkillEntry 内嵌 Resource
#   @export var skill_id: StringName
#   @export var display_name: String
#   @export var skill_type: SkillType          # ATTACK / HEAL / DEFENSE / FORMATION / UTILITY
#   @export var base_weight: int = 50          # 基础权重 [0, 100]
#   @export var cost: int = 1                  # 费用消耗
#   @export var cooldown: int = 0              # 冷却回合数（0 = 无冷却）
#   @export var target_type: TargetType         # SINGLE_ENEMY / ALL_ENEMY / SELF / ALLY / ALL_ALLIES
#   @export var effect_template_ids: Array[StringName]  # 关联的 EffectTemplate ID


# === EnemyBattleState（运行时 RefCounted 实例） ===
class_name EnemyBattleState
extends RefCounted

var template_id: StringName
var current_hp: int
var max_hp: int
var attack: int
var defense: int
var skill_cooldowns: Dictionary    # {skill_id: int} → 剩余冷却回合
var is_alive: bool = true
var field_position: int            # 场上阵位索引（0-based）
var is_front_row: bool
var current_phase_index: int = 0   # Boss 当前阶段索引
var triggered_transitions: Array[int]  # 已触发的阶段索引（防重复触发）


# === AISystem Autoload ===
# 文件位置：res://src/feature/ai_system.gd

## 加载所有 EnemyTemplate Resource 到注册表
## 在 _ready() 中调用——扫描 res://assets/enemies/ 目录
func load_templates() -> void:
    # 加载所有 .tres EnemyTemplate → _template_registry: Dictionary[StringName, EnemyTemplate]

## 创建战斗敌方阵容
## template_ids: 本场战斗的敌人模板ID列表
## player_realm: 玩家当前境界（用于难度缩放）
## 返回运行时 EnemyBattleState 数组（属性已按难度缩放）
func create_enemy_roster(template_ids: Array[StringName], player_realm: int) -> Array[EnemyBattleState]:
    # 1. 通过 EnemyFactory 创建 EnemyBattleState 实例
    # 2. 运行 _apply_difficulty_scaling(enemy, player_realm)
    # 3. 分配前排/后排阵位（防御高→前排，攻击高→后排）
    # 4. 触发 register_preconfigured_bindings() 和 register_preconfigured_formations()

## Phase 6 入口——CombatSystem 在敌方行动阶段调用
## field_state: CombatSystem 提供的当前战场状态快照
func execute_turn(field_state: BattleFieldState) -> Array[AIAction]:
    # 1. 对每个存活敌方角色：
    #    a. Boss: 检查阶段转换 _check_phase_transition()
    #    b. 检查撤退 _check_retreat()
    #    c. 计算技能分数 _evaluate_skills() → 选择 1~2 个技能
    #    d. 目标选择 _select_target()
    #    e. 构建 AIAction 指令
    # 2. 返回所有行动指令列表 → CombatSystem 按顺序执行

## 精英/Boss 预配置绑定注册
## 在 create_enemy_roster() 中自动调用
func register_preconfigured_bindings(enemy: EnemyBattleState) -> void:
    for binding_card_id in enemy.template.preconfigured_bindings:
        BindingManager.register_binding(character_id, binding_card_id, is_enemy=true)

## 难度缩放
func _apply_difficulty_scaling(template: EnemyTemplate, player_realm: int) -> Dictionary:
    if player_realm <= template.realm:
        return {"max_hp": template.base_hp, "attack": template.base_attack, "defense": template.base_defense}
    var scale: float = 1.0 + (player_realm - template.realm) * 0.3
    return {
        "max_hp": round(template.base_hp * scale),
        "attack": round(template.base_attack * scale),
        "defense": round(template.base_defense * scale),
    }

## Cat 2b 信号
signal ai_action_executed(enemy_id: int, action: AIAction)
signal boss_phase_transitioned(enemy_id: int, from_phase: int, to_phase: int)
signal enemy_retreated(enemy_ids: Array[int])
```

### 决策引擎设计

```
execute_turn() 单敌人决策流程:

① _check_retreat() → 若触发撤退 → 跳过后续步骤

② _check_phase_transition()（仅 Boss）
   if should_transition(boss, turn, hp_pct):
     1. 标记 triggered_transitions 防重复
     2. 替换 behavior_profile = new_phase.behavior_override
     3. 解锁/锁定技能（skill_unlock / skill_remove）
     4. if reset_cooldowns: skill_cooldowns.clear()
     5. if heal_percent > 0: current_hp += round(max_hp * heal_percent)
     6. 发射 boss_phase_transitioned 信号 → CombatSystem 播放转换动画
     7. return（阶段转换回合不进行其他行动——GDD 设计决策）

③ _evaluate_skills(enemy, field_state) → Array[SkillScore]
   for each skill in enemy.template.skill_pool:
     if skill on cooldown → skip
     if skill.cost > 剩余费用 → skip（若所有技能都超出则使用普通攻击）
     base = skill.base_weight
     modifier = _calculate_modifier(skill, field_state)
     score = base * modifier
   按 score 降序排序
   选择 top 1~2 个技能（费用预算内）

④ _calculate_modifier(skill, field_state):
   modifier = 1.0
   if skill.is_heal and ally_low_hp_count > 0: modifier += 0.5
   if skill.is_defense and ally_front_dead: modifier += 0.3
   if skill.is_attack and player_high_threat: modifier += 0.4
   if skill.is_formation and formation_slot_available: score += 20  # 加法修正
   return modifier

⑤ _select_target(attacker, skill, field_state):
   if skill.target_type == SELF → return attacker
   if skill.target_type == ALL_ALLIES / ALL_ENEMIES → return 全体
   可用目标 = 玩家前排存活角色（若存在）else 玩家后排存活角色
   if attacker.behavior_profile.focus_fire > 0.5:
     return 可用目标中 HP% 最低的角色
   else:
     return 加权随机选择（残血权重×2）
   特殊覆盖：
   - 嘲讽 → 强制攻击嘲讽角色
   - 穿透攻击 → 可选后排高威胁目标

⑥ 构建 AIAction {enemy_id, skill_id, target_id, is_retreat}
```

### 三智能层级分支

```gdscript
func _decide_action(enemy: EnemyBattleState, field: BattleFieldState) -> AIAction:
    if enemy.template.is_boss:
        return _decide_boss_action(enemy, field)
    elif enemy.template.is_elite:
        return _decide_elite_action(enemy, field)
    else:
        return _decide_normal_action(enemy, field)

# 普通敌人：简单优先级——攻击最残血、随机使用技能
func _decide_normal_action(enemy, field) -> AIAction:
    # 仅 evaluete_skills() + select_target()
    # 无阵法部署、无绑定管理、无阶段转换

# 精英敌人：战术考量——集火/保持前排/预配置绑定/阵法部署
func _decide_elite_action(enemy, field) -> AIAction:
    # evaluete_skills() + select_target()
    # + _check_formation_deploy(enemy, field)  # 有空法阵位且存在可用法阵卡→部署

# Boss：多阶段转换 + 独特技能组 + 自适应策略
func _decide_boss_action(enemy, field) -> AIAction:
    # _check_phase_transition()  # 最先检查
    # _check_formation_deploy(enemy, field)
    # evaluete_skills() + select_target()
```

### 敌方技能效果结算路径

敌人技能效果**统一走 CardEffectEngine 结算路径**——不重复实现效果解析逻辑：

```
AISystem.execute_turn() → 返回 AIAction[]
  → CombatSystem 对每个 AIAction:
    1. if AIAction.is_retreat → 处理撤退流程
    2. if AIAction.skill_id == "basic_attack" → 直接结算基础伤害
    3. else:
       a. CardEffectEngine.resolve(
            card_id=AIction.skill_id,
            target_ids=AIction.target_ids,
            source=EnemyCharacter,
            context=CardEffectContext.EnEMY_ACTION
          )
       b. CardEffectEngine 内部：
          - 查询 SkillEntry → 获取 effect_template_ids
          - EffectFactory.create_instance() → EffectInstance
          - ResolutionStack 结算（优先级排序 + LIFO出栈 + 触发链管理）
          - 效果结果通过 CombatSystem 写入 GSM
```

**为什么不用 AI 内部处理**：
- 敌方技能效果（伤害/治疗/buff/deuff/阵法激活等）与玩家卡牌效果在结算逻辑上完全一致——复用效果引擎避免两套效果解析代码
- 触发链管理（深度限制 + 循环检测）、PRD 伪随机、5 级优先级排序——均为 CardEffectEngine 核心功能，AI 系统不应重复实现
- ADR-0009 已预留 AI 评估接口（`evaluate_effect()` / `simulate_chain()`）——AI 使用这些接口进行决策评估，使用 `resolve()` 进行实际结算

### 信号路由（ADR-0007 合规）

| 信号 | 分类 | 发射者 | 载荷 | 订阅者 |
|------|------|--------|------|--------|
| `ai_action_executed` | Cat 2b | AISystem | `{enemy_id, AIAction}` | CombatUI（播放敌方出牌动画+战斗日志更新）、CombatSystem（执行下一个行动） |
| `boss_phase_transitioned` | Cat 2b | AISystem | `{enemy_id, from_phase, to_phase}` | CombatUI（阶段转换动画+全屏提示+阶段指示器更新）、CombatSystem（Boss 无敌帧锁） |
| `enemy_retreated` | Cat 2b | AISystem | `{retreated_enemy_ids: Array[int]}` | CombatSystem（战斗结束判定——玩家胜利但奖励减半）、CombatUI（撤退动画） |

**不通过信号传播的内容**：
- AI 系统与 CombatSystem 之间：Phase 6 驱动通过直接方法调用（`execute_turn()` 返回 `Array[AIAction]`）。AI 系统是被动服务——不订阅 CombatSystem 阶段信号
- AI 系统与 CardEffectEngine 之间：效果结算通过 CombatSystem 间接调用 `CardEffectEngine.resolve()`——AI 系统仅调用 `evaluate_effect()` 进行决策评估（纯计算，不结算）
- AI 系统与 BindingManager 之间：预配置绑定注册通过直接方法调用（`register_binding()`）

### Autoload 初始化

```gdscript
# AISystem._ready() 执行时，Autoload #1~#13 已完全初始化

func _ready() -> void:
    # 1. 验证依赖系统可用性
    assert(is_instance_valid(CombatSystem), "AISystem: CombatSystem unavailable")
    assert(is_instance_valid(CardEffectEngine), "AISystem: CardEffectEngine unavailable")
    assert(is_instance_valid(RealmSystem), "AISystem: RealmSystem unavailable")

    # 2. 加载 EnemyTemplate 注册表
    load_templates()
    # 扫描 res://assets/enemies/ 目录
    # 加载所有 .tres EnemyTemplate Resource → _template_registry: Dictionary[StringName, EnemyTemplate]
    # 发射 enemy_templates_loaded 信号（Cat 2b——可选的加载完成通知）

    # 3. 初始化 RNG（撤退概率判定等）
    _rng = RandomNumberGenerator.new()
    _rng.seed = GSM.meta.seed  # 确定性种子——支持回归测试
```

## 考虑的替代方案

### 替代方案 A：AI 系统作为 CombatSystem 内部模块（非独立 Autoload）

- **描述**：AI 决策逻辑作为 CombatSystem 的内部类或子节点实现——不创建独立的 AISystem Autoload。
- **优点**：减少 1 个 Autoload（项目已有 17 个）；AI 与战斗系统的耦合天然紧密——不需要跨 Autoload 信号通信；初始化顺序简化——AI 随 CombatSystem 一起初始化
- **缺点**：EnemyTemplate 加载绑定到 CombatSystem 生命周期——若未来需要在战斗外预览敌人信息（如探索系统中显示敌人预览），需加载 CombatSystem；AI 评估接口（evaluate_effect / simulate_chain）被绑定到 CombatSystem 实例——其他系统（如调试工具、模拟器）无法在不启动战斗的情况下测试 AI 决策；违反单一职责原则——CombatSystem 已有 9 个子系统编排职责（ADR-0008），增加 AI 决策逻辑使其过于庞大；EnemyTemplate Resource 注册表与 CombatSystem 的职责（战斗流程编排）无关——应独立管理
- **拒绝原因**：EnemyTemplate 独立加载需求是决定性的——敌人模板是游戏内容数据（类似 CardTemplate），不应绑定到 CombatSystem 生命周期。独立 Autoload 允许在不启动完整战斗的情况下进行 AI 决策的单元测试和回归测试。+1 Autoload 的成本 < 将 AI 逻辑硬耦合到 CombatSystem 的维护复杂度。

### 替代方案 B：敌方技能效果在 AI 系统内部自行处理

- **描述**：敌方技能效果不通过 CardEffectEngine，而是在 AI 系统内部实现一套简化的效果结算逻辑——AI 系统直接计算伤害/治疗/buff/debuff 并写入 GSM。
- **优点**：减少跨系统调用开销——AI 系统 → CombatSystem → CardEffectEngine 的调用链变为 AI 系统内部单步结算；敌方效果比玩家卡牌效果简单（无需考虑阵法/绑定/阵营等复杂交互）——简化实现；CardEffectEngine 的 ResolutionStack / 触发链等复杂机制可能对敌方技能来说是过度设计
- **缺点**：两套效果解析代码——敌方技能与玩家卡牌共享相同的效果类型（伤害/治疗/buff/debuff/状态施加等），分开实现导致代码重复和维护发散；触发链场景被忽略——敌方技能触发玩家效果（如反伤/死亡触发）、阵法光环与敌方技能的交互等需要完整的效果引擎支持；GDD §潜在问题 #1 明确推荐走统一引擎路径——"复用效果解析代码，降低维护成本"；ADR-0009 已为 AI 预留评估接口（evaluate_effect / simulate_chain）——若 AI 自行结算，这些接口成为死代码
- **拒绝原因**：统一结算路径的维护成本优势是决定性的。敌方技能的简单性是 MVP 阶段的表现——未来扩展（敌方装备法宝/部署阵法/阵营交互）会使敌方效果复杂度趋近玩家卡牌。现在选择统一路径避免未来的两大套代码的迁移成本。

### 替代方案 C：EnemyTemplate 使用 JSON/Dictionary 格式

- **描述**：敌人模板使用 JSON 文件（`assets/data/enemies/*.json`）或 GDScript `const Dictionary` 定义，而非 Godot Resource（`.tres`）格式。
- **优点**：JSON 文件更轻量——无需 Godot Resource 序列化/引用计数开销；git diff 友好（纯文本）；跨工具兼容——可用 Python/Excel 批量生成敌人数据；加载更快（JSON.parse() vs ResourceLoader.load()）
- **缺点**：策划无法在 Godot Inspector 中可视化编辑——需要外部工具或手动编写 JSON；无编译时类型检查——字段名拼写错误只能在运行时发现；与项目中已建立的 Resource 模式不一致（CardTemplate ADR-0006、EffectTemplate ADR-0009、StatusTemplate ADR-0011 均使用 `.tres` Resource）；无法使用 Godot 的 `@export` 内嵌 Resource 引用——如 BehaviorProfile / SkillEntry 作为内嵌 Resource 子对象无法在 JSON 中表达；敌人模板数量预计 50-80 个——JSON 手工维护此规模的数据容易出错
- **拒绝原因**：项目中已建立 Resource 作为游戏内容数据的标准格式（CardTemplate、EffectTemplate、StatusTemplate 均为 `.tres`）。EnemyTemplate 使用 Resource 保持一致性的价值大于 JSON 的轻量级优势。`@export` 内嵌 Resource（BehaviorProfile、SkillEntry、BossPhaseTransition）在 Inspector 中的可视化编辑体验是策划的核心需求。

### 替代方案 D：Boss 阶段转换由 CombatSystem 编排

- **描述**：Boss 阶段转换的检测和触发由 CombatSystem 在 Phase 6 之前执行——CombatSystem 检查 Boss 血量和回合数，触发转换动画，然后调用 AI 系统更新行为配置。
- **优点**：CombatSystem 作为战斗的中央编排器——所有战斗流程状态变更集中在一个位置，更易于理解和调试；阶段转换动画和无敌帧是战斗表现层的关注点——由 CombatSystem 管理更合理（CombatSystem 已管理回合和阶段）
- **缺点**：CombatSystem 需要了解 Boss 特定的转换条件（HP 阈值、回合数、新技能列表、行为配置替换）——将 AI 内部数据暴露给 CombatSystem；每个 Boss 的转换条件不同——CombatSystem 需要根据 Boss 模板数据分支处理，增加 CombatSystem 的复杂度；违反信息隐藏原则——Boss 的阶段转换逻辑是 AI 系统的内部行为，不应由编排器掌握细节；CombatSystem 已有 7 阶段状态机 + 9 子系统编排——增加 Boss 转换逻辑使其进一步膨胀
- **拒绝原因**：Boss 阶段转换的核心是"AI 行为模式的切换"——技能池变更、行为配置替换——这是 AI 系统内部关注点。CombatSystem 只需在 Phase 6 调用 `execute_turn()`，AI 系统内部自主决定是否需要转换。转换动画和无敌帧由 CombatSystem 通过 `boss_phase_transitioned` 信号响应——AI 系统通知转换事件，CombatSystem 处理表现层。职责边界清晰。

## 后果

### 积极的

- **效果结算一致性**：敌方技能与玩家卡牌通过同一个 `CardEffectEngine.resolve()` 路径结算——效果解析、触发链管理、PRD 逻辑集中管理，无分散在两套系统中的隐藏行为差异
- **AI 评估精确性**：使用 ADR-0009 的 `evaluate_effect()` / `simulate_chain()` / `GameStateSnapshot` 接口——AI 在不触碰游戏状态的前提下精确预测候选技能的效果差异，做出最优决策
- **敌人数据编辑体验**：EnemyTemplate Resource（`.tres`）在 Godot Inspector 中可视化编辑——策划可通过 `@export` 字段按钮配置技能池、行为配置、阶段转换，无需编写代码或 JSON
- **模板/实例分离正确性**：EnemyTemplate（Resource 只读）+ EnemyBattleState（RefCounted 运行时）——与 ADR-0006 CardTemplate/CardInstance 和 ADR-0009 EffectTemplate/EffectInstance 模式一致，从根本上防止模板污染
- **关注点分离**：CombatSystem 负责战斗流程编排（阶段推进、回合管理），AISystem 负责敌方行为决策——两者通过明确的 `execute_turn() → Array[AIAction]` 直接调用契约通信，职责边界清晰
- **可测试性**：独立 Autoload 允许不启动完整战斗流程的 AI 决策单元测试——`_evaluate_skills()` 的权重修正、`_select_target()` 的集火/分散逻辑、`_check_phase_transition()` 的触发条件均可单独验证

### 消极的

- **Autoload 数量增加到 18 个**：项目从 17 个 Autoload 增加到 18 个（+AISystem）——初始化顺序链更长，故障排查时需检查更多模块。18 个仍在 Godot 安全范围内（< 20）
- **初始化顺序依赖**：AISystem 依赖 #1 GSM、#9 CombatSystem、#10 CardEffectEngine、#11 RealmSystem、#13 BindingManager——初始化顺序的脆弱性增加。缓解措施：`_ready()` 中 `assert(is_instance_valid())` 守卫 + CI 自动化初始化顺序验证测试
- **EnemyTemplate 创作工作量**：50-80 个敌人模板 `.tres` 文件需要策划手动创建——每个模板包含 5-10 个 SkillEntry 内嵌 Resource。缓解措施：MVP 阶段先创建 10-15 个代表性模板，其余通过脚本批量生成
- **同步决策的帧预算风险**：最坏场景（6 敌人 × 5 技能 + 3 阵法评估）< 5ms——在 Phase 6 单帧内完成（16.6ms 预算内有充足余量）。但若未来敌人数量扩展到 10+ 或技能池扩大到 8+，需考虑跨帧分摊。当前规模下同步执行是最简方案

### 中性的

- AI 系统不直接写入 GSM——敌方行动效果通过 CombatSystem → CardEffectEngine → [StatusSystem/BindingSystem] → GSM 路径间接写入。这是设计选择（遵循现有架构的分层写入路径），而非约束

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Autoload 数量持续增长（18 → 22+） | 中 | 启动时间增加、初始化顺序脆弱 | 18 个在安全范围（< 20）。若未来新增 FormationSystem 等 Autoload，在每个新 ADR 中评估 Autoload 合并可行性 |
| EnemyTemplate `.tres` 文件创作瓶颈 | 中 | 敌人数据不足导致战斗测试延迟 | MVP 阶段脚本批量生成——CSV/JSON → `.tres` 导出工具。策划手动调优少量代表性模板 |
| AI 决策在 Phase 6 执行时间超标 | 低 | Phase 6 卡顿——玩家感知到延迟 | 当前最坏 5ms（< 帧预算 30%）。GUT 集成测试中增加性能断言：`assert(execute_turn_time < 10.0, ...)` |
| CardEffectEngine 的 evaluate_effect() 接口在 ADR-0009 中为 proposed contract——若 ADR-0009 接受后接口签名变更 | 低 | AI 评估接口调用失败 | ADR-0009 §AI 评估接口定义已稳定（evaluate_effect / simulate_chain / GameStateSnapshot）——接受前交叉验证接口一致性 |
| Boss 阶段转换动画与 Phase 6 推进的时序冲突 | 中 | 玩家在转换动画期间看到异常行为 | 转换触发时 AI 系统发射 `boss_phase_transitioned` 信号 → CombatSystem 设置 `is_phase_transition_animating = true` → Phase 6 暂停后续行动队列 → 动画完成后恢复。GUT 集成测试覆盖此场景 |
| 精英/Boss 预配置绑定依赖 BindingManager（ADR-0013）——若绑定系统 API 变更 | 低 | 预配置绑定注册失败 | ADR-0013 §接口契约已稳定——AISystem 通过 `register_binding(character_id, card_id, is_enemy=true)` 调用——单一路径 |

## 性能影响

| 指标 | 预期 | 预算 |
|--------|--------|--------|
| CPU — `execute_turn()` 总耗时 | < 5ms（6 敌人 × 5 技能评估 + 阶段检查） | 16.6ms 帧预算中 Phase 6 独占 ≈10ms 容限 |
| CPU — 单次 `evaluate_effect()` | < 100μs（ADR-0009 预算） | ADR-0009 定义 |
| CPU — `_select_target()` | < 200μs（6 角色加权随机） | 可忽略 |
| 内存 — EnemyTemplate Resource 注册表 | ~50-80 模板 × 5KB ≈ 250-400KB | < 1MB |
| 内存 — 战斗中 EnemyBattleState 实例 | 6 实例 × 200 bytes ≈ 1.2KB | 可忽略 |
| 加载时间 — EnemyTemplate 同步加载 | ~50-80 个 Resource < 300ms | 共享战斗场景加载时间窗口 |

## 迁移计划
不适用——这是新系统的初始架构决策。无现有 AI 系统需要迁移。

若未来需要从 prototype 阶段的手写 Dictionary/JSON 敌人数据迁移到 Resource 模型：
1. 创建 `EnemyTemplate` Resource 类，定义所有 `@export` 字段及内嵌 Resource（BehaviorProfile、SkillEntry、BossPhaseTransition、RewardConfig）
2. 编写脚本将 prototype 中的 JSON/Dictionary 敌人数据批量导出为 `.tres` 文件
3. 更新 `AISystem._template_registry` 加载逻辑——从 Dictionary 硬编码切换为 ResourceLoader
4. 废弃运行时的 Dictionary-based 技能池——切换为 EnemyTemplate.skill_pool 查询

## 验证标准
- **GIVEN** 战斗 Phase 6 开始，**WHEN** AISystem.execute_turn() 调用，**THEN** 每个存活敌方角色执行至少一个可用技能或攻击
- **GIVEN** 敌方技能池中有治疗技能且友方残血（HP < 30%），**WHEN** AI 决策，**THEN** 治疗技能 score >= 攻击技能 score（修正系数 ×1.5 生效）
- **GIVEN** 敌方前排阵亡而后排有角色，**WHEN** AI 在 Phase 6 决策，**THEN** 后排高防御角色自动补位到前排
- **GIVEN** 普通敌人，**WHEN** create_enemy_roster() 创建，**THEN** 无预配置绑定、formation_limit = 0
- **GIVEN** 精英敌人，**WHEN** create_enemy_roster() 创建，**THEN** 预配置绑定已注册到 BindingManager、formation_limit = 1
- **GIVEN** Boss 敌人，**WHEN** create_enemy_roster() 创建，**THEN** 有预配置绑定、formation_limit = 2、有至少一个 phase_transition 定义
- **GIVEN** Boss HP 降到 50% 以下，**WHEN** _check_phase_transition() 检查，**THEN** 触发转换、behavior_profile 替换、新技能解锁、boss_phase_transitioned 信号发射
- **GIVEN** Boss 在阶段转换动画期间受到致命伤害，**WHEN** 结算，**THEN** Boss 阵亡，转换不触发（击杀优先）
- **GIVEN** 敌方总血量低于 retreat_threshold（如 0.2），**WHEN** AI 决策，**THEN** 约 50% 概率撤退、enemy_retreated 信号发射
- **GIVEN** 玩家境界（3）高于敌人基准（1），**WHEN** create_enemy_roster() 创建，**THEN** 敌人 HP/ATK/DEF = 基础值 × 1.6
- **GIVEN** 玩家角色激活嘲讽，**WHEN** 敌方选择攻击目标，**THEN** 所有可攻击敌方强制攻击嘲讽目标
- **GIVEN** 敌方所有技能都在冷却，**WHEN** AI 决策，**THEN** 使用普通攻击（基础攻击，无技能效果）
- **GIVEN** Boss 所有阶段已触发完毕，**WHEN** 继续战斗，**THEN** Boss 保持最终阶段行为模式

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| ai-system.md | §1 三级智能层级——普通/精英/Boss | `_decide_action()` 三分支——`_decide_normal_action()` / `_decide_elite_action()` / `_decide_boss_action()`，每级独立的决策逻辑和特性集 |
| ai-system.md | §2 敌方卡组——预定义技能池（非随机抽卡）| `EnemyTemplate.skill_pool: Array[SkillEntry]`——策划在 Inspector 中配置技能池。每回合 AI 从可用技能中按加权分数选择 1~2 个 |
| ai-system.md | §3 敌方上阵与阵位分配 | `create_enemy_roster()` 中自动分配：防御高→前排、攻击高→后排。精英/Boss 可手动配置阵位 |
| ai-system.md | §4 每回合 AI 决策流程 | `execute_turn()` → `_evaluate_skills()`（优先级分数 + 修正系数）+ `_select_target()`（集火/分散/嘲讽） |
| ai-system.md | §5 目标选择逻辑 | `_select_target()`——集火模式（优先残血）、分散模式（加权随机）、嘲讽强制目标、穿透攻击 |
| ai-system.md | §6 敌方绑定与阵法 | `register_preconfigured_bindings()` 战前注册；`_check_formation_deploy()` 阶段6部署阵法 |
| ai-system.md | §7 Boss 阶段转换 | `BossPhaseTransition` Resource + `_check_phase_transition()` + 内部阶段索引——HP/回合触发→行为替换→技能解锁→动画通知→无敌帧 |
| ai-system.md | §8 敌方撤退逻辑 | `_check_retreat()`——非 Boss 敌人 HP < retreat_threshold → 50% 概率撤退 → 玩家胜利但奖励减半 |
| ai-system.md | §9 难度缩放 | `_apply_difficulty_scaling()`——`scale = 1.0 + (player_realm - enemy_realm) × 0.3`，通过 RealmSystem 获取玩家境界 |
| ai-system.md | §10 AI 决策的可视化 | Cat 2b 信号 `ai_action_executed` / `boss_phase_transitioned` / `enemy_retreated`——CombatUI 订阅并渲染 |
| ai-system.md | §边缘情况——所有技能在冷却 | 回退到普通攻击（基础攻击，不消耗费用）——在 `_evaluate_skills()` 中处理 |
| ai-system.md | §边缘情况——Boss 转换瞬间被击杀 | 击杀优先——`_check_phase_transition()` 仅在敌人 is_alive 时执行转换检查 |

## 相关决策
- ADR-0001（GSM——AI 系统只读查询 `player.realm_level`，不写入）
- ADR-0007（信号分类——`ai_action_executed` / `boss_phase_transitioned` / `enemy_retreated` 为 Cat 2b 信号）
- ADR-0008（CombatSystem——Phase 6 驱动 AI + 执行返回的 AIAction 指令列表）
- ADR-0009（CardEffectEngine——敌方技能效果统一结算路径；AI 评估接口 evaluate_effect / simulate_chain / GameStateSnapshot）
- ADR-0010（RealmSystem——`get_realm_property()` 提供境界属性用于难度缩放）
- ADR-0013（BindingManager——精英/Boss 预配置绑定通过 `register_binding()` 注册）