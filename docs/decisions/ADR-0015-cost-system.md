# ADR-0015：费用系统 — 独立 CORE Autoload + 内部状态管理 + 直接调用查询 + 回合重置委托

## 状态
Accepted（2026-07-26——Core 层审查通过。修复：Autoload 数量 17→18→25 矛盾统一、ADR-0013 过时引用移除、GSM 契约缺口明确标注。待后续同步：在接受 ADR-0015 后更新 ADR-0001 第二层 API 追加 `_set_battle_cost()`。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Core / Cost System |
| **知识风险** | LOW（费用系统使用基础引擎 API——整数运算、Dictionary 栈管理、Godot 信号系统——均为 4.0+ 稳定 API。不依赖 4.4+ 新特性） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **使用的截止后 API** | None——核心逻辑（整数增减、Dictionary 操作、信号发射）不依赖 4.4+ 新增 API |
| **需要验证** | CostSystem 在战斗每帧（16.6ms 预算）中 `can_afford()` 被调用多次的性能（O(1) 整数比较——预计 <0.001ms）；`_temp_bonus_stack` 在战斗结束时的清理完整性；多丹药叠加时的数组遍历开销（最多 5-6 次 token 操作/回合——可忽略不计） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`battle.current_cost` / `battle.max_cost` 的 GSM 写入权委托；`batch_updated` 信号传播费用变更；`gsm_initialized` 准入信号）；ADR-0007（三分类信号体系——`cost_changed` 分类为 Cat 2b 系统信号；CombatSystem/CardEffectEngine 通过直接调用查询费用状态）；ADR-0008（CombatSystem——Phase 2 PLAY 出牌阶段调用 `CostSystem.spend()` 扣费；Phase 6 END 结束阶段调用 `CostSystem.reset_for_turn()` 重置费用；`battle_start()` 中调用 `CostSystem.init_for_battle()` 初始化；CombatSystem 通过直接方法调用编排 CostSystem）；ADR-0010（RealmSystem——`get_realm_property(level, &quot;cost_per_turn&quot;)` 查询当前境界费用上限；`realm_changed` 信号触发费用上限更新） |
| **启用** | ADR-0009（CardEffectEngine——在效果结算前通过 `CostSystem.can_afford()` 校验费用；丹药效果的临时费用加成通过 `CostSystem.add_temp_bonus()` 注入）；战斗 UI 系统 ADR（CombatUI 费用栏显示——通过 `CostSystem.get_current_cost()` / `CostSystem.get_max_cost()` 读取当前值和上限；监听 `cost_changed` Cat 2b 信号刷新显示） |
| **阻塞** | 战斗 Epic（出牌阶段的费用校验、回合结束费用重置、丹药临时费用加成流程）；卡牌效果 Epic（丹药类卡牌的"临时+费"效果实现、费用不足时的卡牌灰色不可用状态）；战斗 UI Epic（费用栏组件的数据源和刷新订阅） |
| **排序说明** | Core 层第 3 个 ADR（在 ADR-0006 CardSystem 和 ADR-0010 RealmSystem 之后，ADR-0011 StatusEffectSystem 之前）。CostSystem 在 Autoload 链中为 #7（见 `production/session-state/active.md` Autoload 全链）。CostSystem 的 `_ready()` 执行时，GSM（#1）和 CardSystem（#6）已完全初始化——RealmSystem（#11）在 CostSystem 之后初始化，因此 CostSystem._ready() 不能调用 `get_current_property()`（需等待 RealmSystem 就绪）——`init_for_battle()` 由 CombatSystem 在 `battle_start()` 中显式调用，此时所有 Autoload 均已就绪 |
| **GSM 契约说明** | 本 ADR 提出的 `GSM._set_battle_cost()` 方法为新增 API——在接受本 ADR 后需同步更新 ADR-0001 第二层 API 列表，追加此方法（签名：`_set_battle_cost(current_cost: int, max_cost: int) → void`——写入 `battle.current_cost` / `battle.max_cost` 并发射 `batch_updated`） |

## 上下文

### 问题陈述

`cost-system.md` GDD 定义了费用系统的核心规则——费用上限由境界决定、每回合全额恢复不累积、后手首回合额外 +1 费、丹药可临时增加费用并可突破境界上限、费用不足时卡牌灰色不可用。`architecture.md` 将费用系统归入 **CORE 层**——被战斗系统（CombatSystem）、卡牌效果引擎（CardEffectEngine）和 UI 系统（CombatUI）消费。

但 GDD 未解决以下架构问题：

1. **费用状态的管理位置**：费用数据（`current_cost`、`max_cost`、`temp_bonus`）是存储在 GSM 的 `battle.*` 域中由 CombatSystem 直接管理，还是由独立的 CostSystem Autoload 管理？
2. **费用查询接口**：CardEffectEngine 解析丹药效果时需要查询当前可用费用——是同步直接调用还是通过信号？
3. **回合重置的触发方式**：CombatSystem 在 Phase 6 END 阶段触发费用重置——是通过直接方法调用 CostSystem，还是通过信号通知 CostSystem 自行重置？
4. **临时费用（丹药）的生命周期管理**：多丹药叠加产生的临时费用如何追踪？回合结束时如何批量清除？如何区分基础费用和临时加成？
5. **与境界系统的耦合**：费用上限来源于 RealmSystem——CostSystem 是在初始化时缓存 `cost_per_turn` 值，还是每次查询时实时读取？

`architecture.md` 已将 CostSystem 列为 CORE 层模块，暴露接口 `get_current_cost()` / `spend(n)` / `reset_for_turn()`，消费境界系统。ADM-C3（效果栈结算顺序）待解决——本 ADR 规定费用系统的内部架构和接口契约。

### 约束

- **Core 层定位**：CostSystem 是 CORE 层 Autoload——消费 Foundation 层（GSM 写入委托）和 Core 层（RealmSystem 查询），被 Feature 层（CombatSystem、CardEffectEngine）和 Presentation 层（CombatUI）消费
- **热路径性能**：`can_afford()` 在出牌阶段的每帧中被多次调用（UI 灰显判定、效果引擎前置校验、AI 决策评估）——必须 O(1) 整数比较，无字典/信号开销
- **费用变更的 GSM 传播**：费用状态变更必须通过 GSM `batch_updated`（Cat 1）传播——CombatUI 和状态栏依赖 GSM 信号刷新（与 ADR-0008 确立的 HP/费用变更→GSM Cat 1 一致）
- **ADR-0008 编排契约**：CombatSystem 是战斗流程的编排器——CostSystem 作为子系统被 CombatSystem 直接调用，不反向依赖 CombatSystem
- **初始化顺序**：CostSystem（#7）在 RealmSystem（#11）之前初始化——CostSystem 在战斗开始前不具备查询 RealmSystem 的能力，必须在 `init_for_battle()` 中完成费用上限的初始化

### 需求

- 费用状态管理：维护 `current_cost`（当前可用费用）、`max_cost`（境界上限）、`temp_bonus`（临时加成总额）
- 费用消耗：`spend(n)` 扣除费用，返回成功/失败——费用不足时拒绝
- 费用校验：`can_afford(n)` 快速查询当前是否可支付——O(1) 整数比较
- 回合重置：`reset_for_turn()` 在 CombatSystem Phase 6 END 阶段调用——全额恢复至 `max_cost + temp_bonus`，清除临时费用加成
- 临时费用：`add_temp_bonus(amount, source_id)` 注入丹药临时加成——叠加多个加成，回合结束时 `reset_for_turn()` 统一清除
- 战斗初始化：`init_for_battle(max_cost)` 由 CombatSystem 在 `battle_start()` 中调用——从 RealmSystem 读取当前境界的 `cost_per_turn`
- 费用变更传播：每次花费/重置后通过 GSM `batch_updated`（Cat 1）传播变更——UI 订阅刷新

## 决策

**CostSystem 作为独立的 CORE 层 Autoload（`res://src/core/cost_system.gd`），内部管理费用状态（`_current_cost`、`_max_cost`、`_temp_bonus`、`_temp_bonus_stack`）。战斗热路径中 CardEffectEngine/CombatUI 通过直接调用查询费用（`can_afford()`、`get_current_cost()`），CombatSystem 通过直接调用驱动费用生命周期（`spend()`、`reset_for_turn()`、`init_for_battle()`）。临时费用通过 `_temp_bonus_stack` 以 source_id 追踪来源，`reset_for_turn()` 时批量清除。费用上限由 CombatSystem 在 `battle_start()` 中从 RealmSystem 查询后传入 `init_for_battle(max_cost)`——此后 CostSystem 内部缓存上限值。CostSystem 被委托写入 GSM `battle.current_cost` / `battle.max_cost`（窄范围 GSM 写委托——CombatSystem 将 battle.* 域下费用相关写入权委托给 CostSystem 作为专业子系统，类比 ADR-0010 的 RealmSystem 调用 `GSM.change_realm()` 模式）。**

### 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│              RealmSystem (ADR-0010) — CORE Autoload               │
│  realm_table[L]["cost_per_turn"] → int                            │
│  get_realm_property(level, &"cost_per_turn") → O(1) 字典查询      │
│  realm_upgraded(old, new) → Cat 2b 信号                           │
└──────────────┬───────────────────────────────────────────────────┘
               │ ① init_for_battle(max_cost)——CombatSystem 在 battle_start() 中查询
               │    然后传入 CostSystem
               ▼
┌──────────────────────────────────────────────────────────────────┐
│                 CostSystem (ADR-0015) — CORE Autoload             │
│                                                                    │
│  ┌─ 内部状态 ────────────────────────────────────────────┐       │
│  │ _current_cost: int          # 当前可用费用              │       │
│  │ _max_cost: int              # 境界费用上限（缓存）      │       │
│  │ _temp_bonus: int            # 临时费用加成总额          │       │
│  │ _temp_bonus_stack: Array[Dictionary]  # 追踪各加成来源  │       │
│  │   # [{source_id: "low_pill_001", amount: 1}, ...]      │       │
│  │ _is_active: bool = false    # 战斗活跃标志              │       │
│  └────────────────────────────────────────────────────────┘       │
│                                                                    │
│  ┌─ 查询 API（直接调用——O(1) 整数比较）────────────────┐       │
│  │ get_current_cost() → int        # 当前可用费用          │       │
│  │ get_max_cost() → int            # 境界上限              │       │
│  │ get_total_max() → int           # 上限 + 临时加成       │       │
│  │ can_afford(cost: int) → bool    # 是否足够支付          │       │
│  │ get_cost_state() → StringName   # 返回 CostState 枚举   │       │
│  │ is_overlimit() → bool           # 是否超限状态          │       │
│  └────────────────────────────────────────────────────────┘       │
│                                                                    │
│  ┌─ 变异 API（由 CombatSystem 编排器直接调用）──────────┐       │
│  │ init_for_battle(max_cost: int) → void                     │       │
│  │ spend(amount: int) → bool                                 │       │
│  │ reset_for_turn(is_first_player: bool, is_first_turn: bool) → void│
│  │ add_temp_bonus(amount: int, source_id: String) → void     │       │
│  │ clear_for_battle_end() → void                             │       │
│  └────────────────────────────────────────────────────────┘       │
│                                                                    │
│  ┌─ Cat 2b 信号 ──────────────────────────────────────────┐      │
│  │ cost_changed(current: int, max: int, total_max: int)        │      │
│  │   # 费用变更后发射——CombatUI 监听以刷新费用栏               │      │
│  └────────────────────────────────────────────────────────┘       │
│                                                                    │
│  ┌─ GSM 写入委托（窄范围——仅 battle.current_cost / max_cost）─┐  │
│  │ _write_cost_to_gsm() → void                                   │  │
│  │   # GSM._set_battle_cost(current, max)                        │  │
│  │   # → batch_updated({"battle.current_cost": {old, new},       │  │
│  │   #                  "battle.max_cost": {old, new}})          │  │
│  └──────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │ ② 查询（直接调用） │ ③ 编排（直接调用） │ ④ Cat 2b 信号
    ┌────┴─────┐    ┌────────┴────────┐    ┌──────┴──────┐
    │CardEffect│    │  CombatSystem   │    │  CombatUI   │
    │  Engine  │    │  (ADR-0008)      │    │  / HUD      │
    │can_afford│    │  spend()         │    │  费用栏刷新  │
    │(效果校验) │    │  reset_for_turn()│    └─────────────┘
    │          │    │  init_for_battle()│
    └──────────┘    └─────────────────┘
```

### 关键接口

#### CostState 枚举 + CostSystem 核心

```gdscript
# === CostSystem Autoload — res://src/core/cost_system.gd ===

enum CostState {
    FULL = 0,        # 满费：_current_cost == _max_cost
    PARTIAL = 1,     # 部分消耗：0 < _current_cost < _max_cost
    EMPTY = 2,       # 空费：_current_cost == 0
    OVERLIMIT = 3,   # 超限：_current_cost > _max_cost（临时丹药加成）
}

# ── 内部状态 ──
var _current_cost: int = 0
var _max_cost: int = 0
var _temp_bonus: int = 0
var _temp_bonus_stack: Array[Dictionary] = []  # [{source_id: String, amount: int}, ...]
var _is_active: bool = false

# ── 查询 API（热路径——O(1) 整数比较/运算）──

## 返回当前可用费用（含临时加成）
func get_current_cost() -> int:
    return _current_cost

## 返回境界上限（不含临时加成）
func get_max_cost() -> int:
    return _max_cost

## 返回总上限（境界上限 + 临时加成）
func get_total_max() -> int:
    return _max_cost + _temp_bonus

## 检查是否可支付指定费用——O(1) 整数比较
## 热路径：CombatUI 每帧对每张手牌调用、CardEffectEngine 效果校验调用、AI 决策遍历
func can_afford(cost: int) -> bool:
    if cost <= 0:
        return true  # 0 费卡牌始终可用
    return _current_cost >= cost

## 返回当前费用状态——用于 UI 状态机切换显示样式
func get_cost_state() -> CostState:
    if _current_cost > _max_cost:
        return CostState.OVERLIMIT
    if _current_cost == _max_cost:
        return CostState.FULL
    if _current_cost == 0:
        return CostState.EMPTY
    return CostState.PARTIAL

## 是否处于超限状态（临时丹药突破境界上限）
func is_overlimit() -> bool:
    return _current_cost > _max_cost

# ── 变异 API（由 CombatSystem 编排器直接调用）──

## 战斗初始化——由 CombatSystem.battle_start() 调用
## max_cost: 从 RealmSystem.get_realm_property(player_realm, &"cost_per_turn") 查询
## 内部锁定 max_cost——战斗期间境界突破不改变当前战斗的费用上限
## （境界提升在战斗结算后才生效——与 GDD 设计一致）
func init_for_battle(max_cost: int) -> void:
    _max_cost = maxi(max_cost, 1)  # 防御：至少 1 费
    _current_cost = _max_cost
    _temp_bonus = 0
    _temp_bonus_stack.clear()
    _is_active = true
    _write_cost_to_gsm()

## 扣除费用——由 CombatSystem.play_card() 调用
## 返回 true 表示扣费成功，false 表示费用不足（不应发生——调用前应先 can_afford）
func spend(amount: int) -> bool:
    if not _is_active:
        push_warning("CostSystem: spend() called outside active battle")
        return false
    if amount <= 0:
        return true
    if _current_cost < amount:
        push_warning("CostSystem: spend(%d) failed——current_cost=%d" % [amount, _current_cost])
        return false
    _current_cost -= amount
    _write_cost_to_gsm()
    cost_changed.emit(_current_cost, _max_cost, _max_cost + _temp_bonus)
    return true

## 回合重置——由 CombatSystem Phase 6 END 调用
## is_first_player: 是否为先手玩家
## is_first_turn: 是否为第 1 回合
## 后手第 1 回合额外 +1 费（仅第 1 回合有效，运行在后手补偿抽牌后）
func reset_for_turn(is_first_player: bool, is_first_turn: bool) -> void:
    if not _is_active:
        return

    # 清除所有临时费用加成（回合结束自动过期——不累积）
    _temp_bonus = 0
    _temp_bonus_stack.clear()

    # 全额恢复至境界上限
    _current_cost = _max_cost

    # 后手第 1 回合额外 +1 费（GDD §2 费用恢复规则）
    if not is_first_player and is_first_turn:
        _current_cost += 1
        # 注意：此额外 +1 不属于临时加成——回合结束时不清除它，
        # 但下回合重置时会恢复至标准 _max_cost，因此不会累积

    _write_cost_to_gsm()
    cost_changed.emit(_current_cost, _max_cost, _max_cost + _temp_bonus)

## 添加临时费用加成——由 CardEffectEngine 结算丹药效果时调用
## amount: 加成金额（低级+1/中级+2/高级+3）
## source_id: 丹药卡牌实例 ID——用于追踪来源，便于调试和 UI tooltip 显示
## 临时加成可突破境界上限（GDD §3 费用临时调整）
## 多丹药叠加——_temp_bonus 累加，_temp_bonus_stack 压入条目
func add_temp_bonus(amount: int, source_id: String) -> void:
    if not _is_active:
        push_warning("CostSystem: add_temp_bonus() called outside active battle")
        return
    if amount <= 0:
        return

    _temp_bonus += amount
    _current_cost += amount  # 临时加成同时增加可用费用
    _temp_bonus_stack.append({"source_id": source_id, "amount": amount})

    _write_cost_to_gsm()
    cost_changed.emit(_current_cost, _max_cost, _max_cost + _temp_bonus)

## 战斗结束时清理——由 CombatSystem.battle_end() 调用
func clear_for_battle_end() -> void:
    _current_cost = 0
    _max_cost = 0
    _temp_bonus = 0
    _temp_bonus_stack.clear()
    _is_active = false

# ── GSM 写入委托（内部方法）──

## 将当前费用状态写入 GSM battle.* 域
## 这是从 CombatSystem 委托的窄范围 GSM 写入权——
## CostSystem 是 battle.current_cost / battle.max_cost 的专业写入者
func _write_cost_to_gsm() -> void:
    if not is_instance_valid(GSM):
        return
    # GSM._set_battle_cost() 由本 ADR 提议新增——见 §GSM 第二层扩展
    if GSM.has_method(&"_set_battle_cost"):
        GSM._set_battle_cost(_current_cost, _max_cost + _temp_bonus)

# ── Cat 2b 系统信号 ──

## 费用变更后发射——CombatUI 监听以刷新费用栏
## current: 当前可用费用
## max: 境界上限
## total_max: 境界上限 + 临时加成
signal cost_changed(current: int, max: int, total_max: int)
```

### GSM 第二层扩展（需纳入 ADR-0001 第二层 API）

```gdscript
GSM._set_battle_cost(current_cost: int, max_cost: int) → void
  # 写入 battle.current_cost = current_cost + battle.max_cost = max_cost
  # 发射 batch_updated({"battle.current_cost": {old, new}, "battle.max_cost": {old, new}})
  # 窄范围——仅 CostSystem 调用（从 CombatSystem 委托写入权）
```

### 接口契约

| 接口 | 签名 | 调用方 | 被调用方 | 分类 (ADR-0007) |
|------|------|--------|---------|-----------------|
| 战斗初始化 | `CostSystem.init_for_battle(max_cost)` | CombatSystem | CostSystem | 直接调用（编排器→子系统） |
| 费用扣除 | `CostSystem.spend(amount) → bool` | CombatSystem | CostSystem | 直接调用（需要返回值和保证） |
| 回合重置 | `CostSystem.reset_for_turn(is_first, is_turn1)` | CombatSystem | CostSystem | 直接调用（编排器→子系统） |
| 临时加成 | `CostSystem.add_temp_bonus(amount, source_id)` | CardEffectEngine | CostSystem | 直接调用（效果引擎→Core 服务） |
| 战斗清理 | `CostSystem.clear_for_battle_end()` | CombatSystem | CostSystem | 直接调用（编排器→子系统） |
| 费用校验 | `CostSystem.can_afford(cost) → bool` | CardEffectEngine, CombatUI, AI | CostSystem | 直接调用（纯查询——热路径，O(1)） |
| 费用查询 | `CostSystem.get_current_cost() → int` | CombatUI, CardEffectEngine | CostSystem | 直接调用（纯查询） |
| 上限查询 | `CostSystem.get_max_cost() / get_total_max()` | CombatUI, AI | CostSystem | 直接调用（纯查询） |
| 状态查询 | `CostSystem.get_cost_state() → CostState` | CombatUI | CostSystem | 直接调用（纯查询） |
| 费用变更信号 | `CostSystem.cost_changed(current, max, total_max)` | CostSystem | CombatUI, HUD | Cat 2b（ADR-0007——单一事件通知） |
| GSM 写入 | `GSM._set_battle_cost(current, max)` | CostSystem | GSM | 直接调用（窄范围委托——GSM 第二层原子写入） |
| GSM 信号 | `GSM.batch_updated({"battle.current_cost": ...})` | GSM | 所有订阅者 | Cat 1（ADR-0007——GSM 状态变更广播） |

### 费用生命周期

```
┌──────────────────────────────────────────────────────────────────┐
│                    费用系统生命周期                               │
│                                                                   │
│  CombatSystem.battle_start()                                      │
│    ├─ max_cost = RealmSystem.get_realm_property(level, "cost_per_turn")│
│    ├─ CostSystem.init_for_battle(max_cost)                         │
│    │   ├─ _max_cost = max_cost                                     │
│    │   ├─ _current_cost = max_cost  # 初始满费                     │
│    │   ├─ _temp_bonus = 0                                          │
│    │   ├─ _is_active = true                                        │
│    │   └─ _write_cost_to_gsm()                                     │
│    └─ ...                                                          │
│                                                                   │
│  每回合循环：                                                     │
│    Phase 2 PLAY:                                                  │
│      CombatSystem.play_card(card)                                  │
│        ├─ CostSystem.can_afford(card.cost)  → 费用不足则拒绝       │
│        ├─ CostSystem.spend(card.cost)       → 扣费 + 写入 GSM     │
│        └─ CardEffectEngine.resolve(card, targets)                   │
│            ├─ [丹药效果] CostSystem.add_temp_bonus(1~3, source_id) │
│            │     # _temp_bonus += amount + _current_cost += amount │
│            │     # 可突破境界上限                                  │
│            └─ ...                                                  │
│                                                                   │
│    Phase 6 END:                                                   │
│      CostSystem.reset_for_turn(is_first_player, is_first_turn)     │
│        ├─ _temp_bonus = 0  # 清除所有临时加成                      │
│        ├─ _temp_bonus_stack.clear()                                │
│        ├─ _current_cost = _max_cost  # 全额恢复                    │
│        ├─ IF 后手 AND 第1回合: _current_cost += 1                  │
│        └─ _write_cost_to_gsm()                                     │
│                                                                   │
│  CombatSystem.battle_end()                                        │
│    └─ CostSystem.clear_for_battle_end()                            │
│        ├─ _current_cost = 0, _max_cost = 0                         │
│        ├─ _temp_bonus = 0, _temp_bonus_stack.clear()               │
│        └─ _is_active = false                                       │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 后手第 1 回合额外 +1 费的设计决策

后手首回合额外 +1 费由 `reset_for_turn()` 直接增加 `_current_cost`（不通过 `_temp_bonus`），原因如下：

- **语义差异**：后手补偿是回合级别的调整，不是丹药类的临时加成——它不应在回合结束时被"清除"，而是在下回合重置时自然回归标准上限
- **无 source_id 需求**：它不是来自丹药效果，不需要在 UI 中显示"来源"
- **简化实现**：`reset_for_turn()` 同时处理"全额恢复"和"后手第 1 回合补偿"两个逻辑——调用方只需传入 `is_first_player` 和 `is_first_turn` 两个布尔参数

## 考虑的替代方案

### 替代方案 B：费用数据完全存储在 GSM —— 无独立 CostSystem Autoload

- **描述**：费用状态（`current_cost`、`max_cost`、`temp_bonus`）存储在 GSM 的 `battle.*` 域中。CombatSystem 通过 GSM 第二层方法直接读写费用——不创建 CostSystem Autoload。`can_afford()` 由 CombatSystem 或 CardEffectEngine 原地计算。
- **优点**：
  - 项目 Autoload 总数保持稳定——不新增不必要的基础设施节点
  - 费用状态与 battle 域其他数据同处一处——GSM 序列化/反序列化不需要额外处理
  - 无需跨 Autoload 初始化顺序依赖
- **缺点**：
  - `can_afford()` 逻辑散落在 CombatSystem、CardEffectEngine、AI——3 处各自实现整数比较（"费用 >= 卡牌费用"），不一致风险高
  - 临时费用加成（`_temp_bonus_stack`）的追踪和清除需要在 GSM 中增加专门的数据结构——GSM 的 battle 域膨胀
  - `add_temp_bonus()` 逻辑复杂（修正 `_current_cost` + `_temp_bonus` + 压栈）——放在 GSM 中不符合其"状态管理而非业务逻辑"的职责
  - CostState 枚举（FULL/PARTIAL/EMPTY/OVERLIMIT）的判断逻辑在 3 个消费者处重复——UI 状态机、出牌校验、AI 评估各写一遍
  - `architecture.md` 已明确将费用系统列为独立 CORE 层模块——嵌入 GSM 违背已接受的架构分层
- **拒绝原因**：费用系统虽然数据结构简单（4 个整数 + 1 个数组），但涉及的业务逻辑（临时加成追踪与清除、费用状态判定、后手补偿规则）超出 GSM 的职责范围——GSM 是运行时状态仲裁者，不是业务逻辑承载者。将费用逻辑嵌入 GSM 会导致同一段 `can_afford()` 逻辑在 3 个位置重复实现（CombatSystem、CardEffectEngine、AI），增加维护成本和 bug 风险。

### 替代方案 C：费用系统嵌入 CombatSystem —— 非独立 Autoload

- **描述**：CostSystem 不作为独立 Autoload，而是 CombatSystem 的内部子模块（如 `CombatSystem.cost`）。所有费用管理通过 `CombatSystem.cost.can_afford()` / `CombatSystem.cost.spend()` 访问。
- **优点**：
  - 费用状态与战斗状态天然同生命周期——`battle_start()` 初始化，`battle_end()` 清理——无需跨系统委托
  - 减少 1 个 Autoload 注册——降低初始化顺序复杂性
  - CombatSystem 直接拥有费用数据——不涉及 GSM 写委托
- **缺点**：
  - CardEffectEngine 需要校验费用时，需要持有 CombatSystem 的引用——增加 CombatSystem 与 CardEffectEngine 的耦合（效果引擎目前是独立系统，不应依赖 Feature 层的 CombatSystem）
  - AI 系统决策遍历卡牌时需要费用查询——同样引入 AI→CombatSystem 耦合
  - CombatSystem 已经编排 9 个子系统——再内嵌 CostSystem 会增加其类的规模（violation of SRP）
  - 不符合 `architecture.md` 的层分类——CostSystem 被归类为 CORE 层（被 Feature 层消费），嵌入 Feature 层的 CombatSystem 颠倒了依赖方向
- **拒绝原因**：CostSystem 的消费者跨越 Core/Feature/Presentation 三层——CardEffectEngine（Core）、AI（Feature）、CombatUI（Presentation）都需要费用查询。将 CostSystem 嵌入 CombatSystem 会使这些系统被迫依赖 CombatSystem——破坏层隔离。独立 Autoload 保持在 CORE 层，符合 `architecture.md` 的层分类。

## 后果

### 积极的

- **单一费用逻辑源**：`can_afford()`、`spend()`、`reset_for_turn()`、`add_temp_bonus()` 在 CostSystem 中集中定义——CombatSystem、CardEffectEngine、AI、CombatUI 不重复实现费用逻辑
- **热路径零开销查询**：`can_afford()` 是 O(1) 整数比较（无字典查找、无信号发射、无方法调用链）——出牌阶段每帧多次调用不影响帧预算
- **临时费用生命周期清晰**：`_temp_bonus_stack` 以 source_id 追踪来源——回合结束 `reset_for_turn()` 批量清除——不会遗漏任何临时加成
- **CombatSystem 编排一致性**：CostSystem 作为子系统被 CombatSystem 直接调用——与 StatusEffectSystem、DeckSystem 等子系统编排模式一致（ADR-0008 的编排器模式）
- **状态查询语义明确**：CostState 枚举（FULL/PARTIAL/EMPTY/OVERLIMIT）提供统一的费用状态判定——UI 可根据状态切换显示样式（金色满费/蓝色部分/红色空费/紫色超限）
- **境界解耦**：`init_for_battle(max_cost)` 在战斗开始时缓存上限——战斗期间境界不改变上限（符合 GDD 设计——境界提升在战斗结算后生效）

### 消极的

- **增加 1 个 Autoload**：CostSystem 为 Autoload #7——已在 `active.md` Autoload 全链中记录（25 个 Autoload）。费用系统仅管理 4 个整数 + 1 个数组——不显著增加初始化开销
- **GSM 写委托的额外契约**：CostSystem 通过 `GSM._set_battle_cost()` 写入 battle 域——需要 CombatSystem 显式授予此窄范围写入权（由本 ADR 记录委托关系）。若委托未正确执行，费用变更可能无法传播到 GSM Cat 1 信号链
- **初始化顺序约束**：CostSystem（#7）在 RealmSystem（#11）之前初始化——`init_for_battle()` 必须在 RealmSystem 就绪后由 CombatSystem 显式调用。若初始化顺序在未来被调整，需要同步更新 CostSystem 的初始化契约
- **双重信号路径**：费用变更同时通过 `CostSystem.cost_changed`（Cat 2b）和 `GSM.batch_updated`（Cat 1）传播——CombatUI 可选择监听任一信号。潜在风险：两条信号路径的发射时序不一致（CostSystem 先发射 Cat 2b，再写入 GSM → Cat 1 发射）。缓解措施：CombatUI 统一监听 `GSM.batch_updated`（Cat 1）作为刷新源——`cost_changed`（Cat 2b）仅作为高效直达路径（载荷结构化更好）

### 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| GSM `_set_battle_cost()` 方法未被纳入 ADR-0001 第二层 API | 中 | 费用变更无法写入 GSM——CombatUI 不刷新费用显示 | 本 ADR §GSM 第二层扩展明确定义了 `_set_battle_cost()` 的签名和行为。接受本 ADR 后同步更新 ADR-0001 第二层 API 列表 |
| 临时费用加成来源追踪缺失导致回合结束残留 | 低 | 丹药加成跨回合保留——玩家获得永久费用加成（游戏平衡破坏） | `reset_for_turn()` 无条件清零 `_temp_bonus` 和 `_temp_bonus_stack`——不依赖栈内容校验。GUT 测试覆盖"回合结束后 temp_bonus == 0"断言 |
| 战斗中途境界突破的时机问题 | 低 | 若境界在战斗中途提升（如丹药触发突破），费用上限是否实时变化？ | 当前设计：`_max_cost` 在 `init_for_battle()` 时锁定——战斗期间不变。GDD 未定义"战斗中突破"场景——若未来新增此功能，通过监听 `realm_changed` 信号更新 `_max_cost` |
| 后手补偿的"第 1 回合"判定依赖 CombatSystem 传递正确的 `turn` 值 | 低 | CombatSystem 传递错误的 is_first_turn → 后手第 1 回合补偿要么未触发，要么多回合触发 | CombatSystem 的 `battle.turn` 计数器在 ADR-0008 中定义为从 1 开始、每 Phase 0→6 完整一圈后 +1——确定性。GUT 集成测试覆盖"后手第 1 回合 get_current_cost() == max_cost + 1" |
| `can_afford()` 返回 true 后、`spend()` 执行前费用被其他操作消耗 | 极低 | 并发费用消耗——单线程 GDScript 中可能？ | GDScript 单线程：在同一帧内、同一调用链中，费用不会被其他操作消耗。时序路径：`can_afford()` → `spend()` 在同一次 `play_card()` 调用中顺序执行——无中断窗口 |

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| cost-system.md | §1「每回合费用上限」——由境界固定决定（2/5/8/11/14） | `init_for_battle(max_cost)` 从 RealmSystem 查询并缓存。const `REALM_COST_FORMULA = 2 + (L-1) × 3` 在 RealmSystem 的 `realm_table` 中定义（ADR-0010）——CostSystem 引用，不重复定义 |
| cost-system.md | §2「费用恢复规则」——每回合全额恢复，不累积 | `reset_for_turn()` 全额恢复至 `_max_cost`，清除 `_temp_bonus`——不保留未使用费用 |
| cost-system.md | §2「后手第 1 回合额外 +1 费」 | `reset_for_turn(is_first_player=false, is_first_turn=true)` 中 `_current_cost += 1` |
| cost-system.md | §3「费用临时调整」——丹药 +1/+2/+3 费，可突破上限 | `add_temp_bonus(amount, source_id)` 同时修正 `_temp_bonus` 和 `_current_cost`——`_current_cost` 可超过 `_max_cost`（OVERLIMIT 状态） |
| cost-system.md | §3「临时费用仅本回合有效」 | `reset_for_turn()` 无条件清零 `_temp_bonus` 和 `_temp_bonus_stack`——回合结束自动过期 |
| cost-system.md | §4「费用不足时卡牌灰色不可用」 | `can_afford(card.cost)` → `false` → CombatUI 将卡牌渲染为灰色不可拖拽状态 |
| cost-system.md | §状态与转换——满费/部分消耗/空费/超限 | CostState 枚举（FULL/PARTIAL/EMPTY/OVERLIMIT）+ `get_cost_state()` 提供统一状态判定 |
| cost-system.md | §与其他系统的交互——战斗系统/卡牌效果引擎/丹药系统 | 接口契约表明确列出所有调用方、被调用方和信号分类——战斗系统编排、效果引擎查询、丹药加法 |
| architecture.md §CORE 层 | 费用系统暴露 `get_current_cost()` / `spend(n)` / `reset_for_turn()` | 完全对应——额外增加 `can_afford()`、`add_temp_bonus()`、`init_for_battle()`、`clear_for_battle_end()` 完善接口 |
| architecture.md OQ-01 | 卡牌效果引擎中每个效果类型的具体读写契约 | 确立 CardEffectEngine→CostSystem 的读写契约：`add_temp_bonus()`（丹药效果）+ `can_afford()`（费用校验） |

## 性能影响

- **CPU**：`can_afford()` < 0.001ms（单次整数比较——`return _current_cost >= cost`）。出牌阶段每帧最多被调用 N 次（N = 手牌数 ≤ 10）——总计 < 0.01ms。`spend()` < 0.001ms（整数减法）+ `_write_cost_to_gsm()` < 0.01ms（字典构建 + 信号发射）。`reset_for_turn()` < 0.01ms（重置 4 个变量 + 清除数组 + GSM 写入）
- **内存**：CostSystem Autoload 实例 < 1KB（4 个 int + 1 个 Array + 枚举 + 信号声明）。`_temp_bonus_stack` 最多 5-6 个丹药条目/回合——< 200B
- **加载时间**：CostSystem `_ready()` 为空（战斗准备在 `init_for_battle()` 中执行）——零额外启动时间
- **网络**：不适用（纯单机游戏）

## 迁移计划

本 ADR 创建新系统，非修改现有代码。实施顺序：

1. 创建 `res://src/core/cost_system.gd` —— CostSystem Autoload（内部状态 + 查询/变异 API + Cat 2b 信号 + GSM 写委托）
2. 在 `project.godot` 中注册 Autoload —— 排在 CardSystem（#6）之后、StatusEffectSystem（#8）之前
3. 更新 ADR-0001——新增 `GSM._set_battle_cost(current_cost, max_cost)` 第二层方法（在 ADR-0001 §第二层 API 中追加）
4. 更新 ADR-0008 §子系统编排顺序——在 Phase 2 DURING 和 Phase 6 ENTER 中明确 CostSystem 调用
5. 战斗系统实现时——在 `battle_start()` 中集成 `CostSystem.init_for_battle()`，在 `play_card()` 中集成 `CostSystem.can_afford()` + `spend()`
6. UI 实现时——CombatUI 费用栏监听 GSM `batch_updated`（Cat 1）刷新，或直接监听 `CostSystem.cost_changed`（Cat 2b）作为高效路径

## 验证标准

- **GIVEN** 玩家炼气期进入战斗，**WHEN** 查询 `CostSystem.get_max_cost()`，**THEN** 返回 2
- **GIVEN** `_current_cost=5`，**WHEN** 调用 `can_afford(3)`，**THEN** 返回 true
- **GIVEN** `_current_cost=1`，**WHEN** 调用 `can_afford(3)`，**THEN** 返回 false
- **GIVEN** `_current_cost=5`，**WHEN** 调用 `can_afford(0)`，**THEN** 返回 true（0 费卡始终可用）
- **GIVEN** `_current_cost=5`，**WHEN** 调用 `spend(3)`，**THEN** `_current_cost=2` + 返回 true + `cost_changed` 信号已发射
- **GIVEN** `_current_cost=1`，**WHEN** 调用 `spend(3)`，**THEN** `_current_cost` 不变 + 返回 false + push_warning
- **GIVEN** `_max_cost=5, _temp_bonus=0`，**WHEN** 调用 `get_cost_state()`，**THEN** 返回 `FULL`（假设 `_current_cost==5`）
- **GIVEN** `_max_cost=5, _current_cost=3`，**WHEN** 调用 `get_cost_state()`，**THEN** 返回 `PARTIAL`
- **GIVEN** `_max_cost=5, _current_cost=0`，**WHEN** 调用 `get_cost_state()`，**THEN** 返回 `EMPTY`
- **GIVEN** `_max_cost=5, _current_cost=7`（超限），**WHEN** 调用 `get_cost_state()`，**THEN** 返回 `OVERLIMIT` + `is_overlimit()` 返回 true
- **GIVEN** `_max_cost=5`，**WHEN** 调用 `add_temp_bonus(2, "mid_pill_001")`，**THEN** `_temp_bonus=2` + `_current_cost=7` + `_temp_bonus_stack` 含 1 条目
- **GIVEN** 两次 `add_temp_bonus`（+1 + +2），**WHEN** 查询，**THEN** `_temp_bonus=3` + `_temp_bonus_stack.size()==2`
- **GIVEN** `_current_cost=8, _max_cost=5, _temp_bonus=3`，**WHEN** 调用 `reset_for_turn(true, false)`（先手），**THEN** `_current_cost=5` + `_temp_bonus=0` + `_temp_bonus_stack` 为空
- **GIVEN** 后手第 1 回合，**WHEN** 调用 `reset_for_turn(false, true)`，**THEN** `_current_cost = _max_cost + 1`
- **GIVEN** 后手第 2 回合，**WHEN** 调用 `reset_for_turn(false, false)`，**THEN** `_current_cost = _max_cost`（无额外 +1）
- **GIVEN** 非活跃战斗，**WHEN** 调用 `spend(1)`，**THEN** 返回 false + push_warning
- **GIVEN** `init_for_battle(5)` 完成，**WHEN** 检查 GSM，**THEN** `GSM.battle.current_cost == 5` + `GSM.batch_updated` 信号已发射

## 相关决策

- ADR-0001（游戏状态管理器——`_set_battle_cost()` 第二层原子写入方法；`batch_updated` 信号传播费用状态变更）
- ADR-0007（三分类信号体系——`cost_changed` 分类为 Cat 2b 系统信号；CombatSystem/CardEffectEngine 通过直接调用查询费用状态——非信号）
- ADR-0008（战斗系统 7 阶段状态机——Phase 2 PLAY 出牌阶段调用 `CostSystem.spend()`；Phase 6 END 结束阶段调用 `CostSystem.reset_for_turn()`；`battle_start()` 调用 `CostSystem.init_for_battle()`；`battle_end()` 调用 `CostSystem.clear_for_battle_end()`）
- ADR-0010（境界系统——`get_realm_property(level, &quot;cost_per_turn&quot;)` 查询费用上限；`realm_changed` 信号在未来可能用于战斗中更新 `_max_cost`）