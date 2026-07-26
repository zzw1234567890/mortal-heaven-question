# ADR-0008：战斗系统 — 7 阶段状态机 + 阶段验证 + 回合编排器

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Combat |
| **知识风险** | LOW（战斗系统使用基础引擎 API——`Node` 场景树编排、信号系统、`_process()` 帧轮询——均为 4.0+ 稳定 API） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——核心编排逻辑不依赖 4.4+ 新 API |
| **需要验证** | 7 阶段 `advance_phase()` 每帧调用开销（预计 <0.01ms）；战斗中 9 个子系统的信号连接总数（预计 <30）；Autoload 初始化顺序——CombatSystem 必须在所有依赖的子系统之后注册；`call_deferred()` 自动阶段推进在连续自动阶段间确实产生恰好 1 帧渲染间隔；Cat 2b 信号通过 `_emit_signal_safe`（ADR-0007）路由后的信号链深度行为 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`battle.*` 域由 CombatSystem 独占运行时写入；`apply_battle_rewards()` + `add_resource()` + `add_cultivation()`；详见 §GSM battle.* 域写入所有权例外）、ADR-0002（CardSystem——卡牌模板查询、`create_instance()`）、ADR-0003（SaveLoad——`create_battle_snapshot()` + `clear_battle_snapshot()` 战斗快照生命周期）、ADR-0004（EventSystem——`TRIGGER_BATTLE` Outcome → CombatSystem.battle_start()）、ADR-0005（InputManager——Phase 2/3/5 的 ANIMATION 锁 push/pop）、ADR-0006（SceneManager——战斗场景加载和退出）、ADR-0007（信号分类——Cat 2b 信号通过 `_emit_signal_safe` 路由；直接方法调用编排 9 个子系统） |
| **启用** | ADR-0009（卡牌效果引擎——效果解析在出牌/攻击阶段被调用）、ADR-0010（上场阵位系统——阵位在备战阶段设置）、ADR-0011（AI 系统——敌方行动阶段的决策输入） |
| **阻塞** | 战斗 Epic（核心游戏循环的实现）、卡牌效果 Epic（效果引擎的结算入口在战斗中）、AI Epic（AI 依赖战斗状态机提供阶段上下文） |
| **排序说明** | Core/Feature 层第一个 ADR。在 Foundation 层所有 7 个 ADR 之后被接受。必须在卡牌效果引擎（ADR-0009）之前被接受——效果引擎的结算入口在战斗系统的出牌和攻击阶段中 |

## 上下文

### 问题陈述

`combat-system.md` GDD 定义了 7 阶段回合流程（准备→抽牌→出牌→攻击声明→攻击结算→敌方行动→结束），描述了 9 个子系统的交互方式（费用、卡牌效果引擎、状态效果、上场/绑定/阵法、AI、境界、GSM、UI）。但 GDD 关注的是"玩家体验到的战斗流程"，而本 ADR 需要解决的是"程序化执行"：

1. **阶段转换的验证条件**：advance_phase() 应该检查什么？阶段不能盲目推进——如出牌阶段必须等待玩家明确结束回合（或超时/空手牌），攻击声明阶段必须等待所有角色目标分配完毕
2. **9 个子系统的编排顺序**：阶段内子系统的调用顺序影响结算一致性——状态效果 tick 和抽牌谁先发生？敌方行动和玩家攻击结算的顺序？
3. **信号 vs 直接调用的边界**：哪些阶段转换发射信号（UI 需要刷新阶段指示器），哪些通过直接调用（内部系统编排）——需与 ADR-0007 决策矩阵对齐
4. **战斗生命周期管理**：`battle_start()` / `battle_end()` 的 GSM 写入契约、战斗快照（ADR-0003 的 `pre_battle.json`）、战斗场景的进入/退出

`architecture.md` 已定义战斗系统为 Feature 层模块，暴露 `start_battle(enemy)` / `end_battle(result)`，消费 9 个子系统。C3（效果栈结算顺序）待解决——本 ADR 规定战斗阶段的结算顺序。

### 约束

- **Feature 层**：战斗系统不属于 Foundation 层——它依赖 Foundation 层的 5 个模块（GSM、CardSystem、SaveLoad、EventSystem、SceneManager）并编排它们
- **7 阶段模型**（来自 GDD）：准备(0)→抽牌(1)→出牌(2)→攻击声明(3)→攻击结算(4)→敌方行动(5)→结束(6)
- **阶段顺序强制执行**：阶段不可跳过（即使某阶段无操作——如敌方行动阶段无存活敌人——也必须经过）
- **advance_phase() 返回 bool**：失败 = 前置条件不满足——记录错误，不推进
- **attack-phase-only 子系统**：上场阵位、绑定、阵法在"备战阶段"（battle_start 前）一次性设置——战斗中不可调整（GDD 设计决策 2026-07-23）
- **GSM battle.* 域**：运行时数据——battle_start() 创建 battle 域，battle_end() 清除。不持久化到存档
- **帧预算**：战斗系统编排逻辑（阶段推进 + 子系统调度）每帧 <0.5ms——非热路径，仅在阶段转换时执行。实际每帧操作：检查阶段条件（O(1)）+ 如果玩家输入触发了阶段推进则 advance_phase()

### 需求

- 7 阶段状态机：advance_phase() 验证前置条件 → 执行当前阶段清理 → 执行下一阶段初始化 → 更新 `battle.current_phase`
- 阶段验证：每阶段定义 `_can_advance_from(phase)` 条件（如在出牌阶段[2]检查 `all_actions_declared or player_confirmed_end`）
- 子系统调度：每阶段的 `_enter_phase(phase)` 和 `_exit_phase(phase)` 方法按定义的顺序调用子系统
- 战斗生命周期：battle_start(config) → 初始化 battle.* 域 + 备战阶段 → 回合循环 → battle_end(result) → 清理 + 发射奖励
- 信号分类（ADR-0007 合规）：阶段转换 → Cat 2b（系统信号——CombatUI 监听）；HP/费用变更 → Cat 1（GSM 信号——通过第二层方法发射）；子系统调用 → 直接方法调用（战斗系统是编排器）

## 决策

**战斗系统实现为 Feature 层 Autoload（CombatSystem），管理 7 阶段回合状态机——advance_phase() 验证→清理→初始化→推进的确定性序列。9 个子系统通过直接方法调用编排（阶段内部），阶段转换通过 Cat 2b 信号通知 CombatUI。战斗生命周期通过 GSM battle.* 域管理——battle_start() 创建，battle_end() 清除 + 通过 GSM 第二层原子方法发射奖励。**

### 7 阶段状态机

```
┌──────────────────────────────────────────────────────────────────┐
│               CombatSystem 7 阶段状态机                          │
│                                                                   │
│  advance_phase() 调用链：                                        │
│    _validate_transition(from, to)  →  bool（前置条件检查）       │
│    _exit_phase(current)            →  void（当前阶段清理）        │
│    _enter_phase(next)              →  void（下一阶段初始化）      │
│    GSM._set_battle_phase(next)     →  void（GSM 第二层——§GSM 写入所有权）│
│    # battle.phase 变更通过 GSM batch_updated 传播（Cat 1）       │
│                                                                   │
│                                                                   │
│  Phase 0 — PREPARATION（准备阶段）                                │
│  ├─ 触发"回合开始"效果（Callable 列表——卡牌效果引擎）             │
│  ├─ 状态效果系统.tick_all()——结算持续伤害/恢复/Buff 倒计时        │
│  ├─ 状态持续时间 -1；duration=0 的效果过期移除                    │
│  └─ → 自动推进到 Phase 1（无条件）                                │
│                                                                   │
│  Phase 1 — DRAW（抽牌阶段）                                       │
│  ├─ 从牌库抽牌（基础 2 张，特殊效果可修正）                       │
│  ├─ 触发"抽牌时"效果（Callable 列表）                             │
│  ├─ 后手第 1 回合：额外 +1 费 + 抽 3 张（非 2 张）               │
│  ├─ 牌库为空 → 弃牌堆随机返还 1 张到牌库底部                      │
│  └─ → 自动推进到 Phase 2（无条件）                                │
│                                                                   │
│  Phase 2 — PLAY（出牌阶段）  ← 玩家主动阶段                       │
│  ├─ 玩家可从手牌打出任意数量的卡牌（费用限制内）                   │
│  ├─ 卡牌效果引擎.resolve(card, target)——每次出牌立即结算          │
│  ├─ 费用系统.spend(card.cost)——每次出牌扣费                       │
│  ├─ 推进条件：player_confirmed_end_turn OR timer_exceeded          │
│  │   OR hand_empty AND cost_insufficient_for_any_card              │
│  └─ ⚠️ 不自动推进——等待玩家输入或超时                             │
│                                                                   │
│  Phase 3 — ATTACK_DECLARATION（攻击声明）  ← 玩家主动阶段         │
│  ├─ 玩家为每个己方角色选择攻击目标（或跳过）                       │
│  ├─ 攻击顺序按速度排序（base_speed(realm) + speed_bonus）         │
│  ├─ 推进条件：all_characters_targeted OR player_confirmed_skip     │
│  └─ ⚠️ 已行动/待命角色不可攻击——UI 灰显                           │
│                                                                   │
│  Phase 4 — ATTACK_RESOLUTION（攻击结算）  ← 自动阶段              │
│  ├─ 按速攻击顺序依次结算每次攻击：                                 │
│  │   ├─ 计算伤害：max(1, ATK - DEF) × realm_penalty               │
│  │   ├─ 目标 HP 减少；检查阵亡（HP ≤ 0）                          │
│  │   ├─ 阵亡触发：死亡效果 → 绑定卡进弃牌堆 → 角色从场上移除     │
│  │   ├─ 攻击目标死亡/消失：重新选择目标（优先同排同列）           │
│  │   └─ 发射 attack_resolved(attacker, target, damage) → Cat 2b   │
│  └─ → 自动推进到 Phase 5（所有攻击结算完毕）                      │
│                                                                   │
│  Phase 5 — ENEMY_TURN（敌方行动）  ← 自动阶段                     │
│  ├─ AI 系统.get_next_action(enemy, field)——决策                   │
│  ├─ 按 AI 决策执行敌方出牌/攻击（卡牌效果引擎结算）               │
│  ├─ 敌方角色阵亡检查——全部阵亡 → 标记 _battle_should_end = true   │
│  │   # ⚠️ 不在此处直接调用 battle_end(VICTORY)——                   │
│  │   # 等待 _exit_phase(5) + _enter_phase(6) 正常执行             │
│  │   # Phase 6 的"回合结束"效果和状态过期移除仍需触发              │
│  │   # 原因：跳过 Phase 6 会遗漏"回合结束"效果（如 buff 过期、     │
│  │   #   回合结束时的资源结算）——如果战斗在该回合获胜              │
│  └─ → 自动推进到 Phase 6（敌方行动完毕）                          │
│                                                                   │
│  Phase 6 — END（结束阶段）                                         │
│  ├─ 触发"回合结束"效果（Callable 列表）                           │
│  ├─ 费用系统.reset_for_turn()——未使用费用不累积                   │
│  ├─ 状态效果系统——"回合结束"触发效果结算                          │
│  ├─ 检查战斗结束条件：                                            │
│  │   ├─ 敌方全灭 → battle_end(VICTORY)                            │
│  │   ├─ 己方全灭 → battle_end(DEFEAT)                             │
│  │   └─ 否则 → 回合数 +1 → advance_phase(PREPARATION)  # 新回合   │
│  └─ 己方角色"已行动"状态重置；"待命"状态清除（上场满 1 回合）    │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 阶段转换验证矩阵

每个阶段的 `_can_advance_from(phase)` 条件：

| 从阶段 | 到阶段 | 推进条件 | 验证失败行为 |
|--------|--------|---------|------------|
| 0 PREP | 1 DRAW | 无条件——自动推进 | — |
| 1 DRAW | 2 PLAY | 无条件——自动推进 | — |
| 2 PLAY | 3 ATK_DEC | player_confirmed_end \|\| timer_exceeded \|\| (hand_empty AND not can_afford_any_card) | advance_phase() 返回 false——UI 显示"请结束回合" |
| 3 ATK_DEC | 4 ATK_RES | all_characters_targeted \|\| player_confirmed_skip \|\| _attack_queue.is_empty() | advance_phase() 返回 false——UI 高亮未分配目标 |

**Phase 3 空攻击队列边界情况**：当所有己方角色均处于"待命"或"已行动"状态时（无可攻击角色），`_attack_queue` 为空。此时 `all_characters_targeted()` 为空真（vacuously true——0 个可攻击角色全部已"分配目标"），系统**自动推进**——无需等待玩家确认跳过。这与 GDD §6 "每个己方角色每回合可攻击 1 次"一致——首回合所有角色待命，Phase 3 自动跳过。
| 4 ATK_RES | 5 ENEMY | 无条件——自动推进（所有攻击结算完毕） | — |
| 5 ENEMY | 6 END | 无条件——自动推进（敌方行动完毕） | — |
| 6 END | 0 PREP | 战斗未结束（双方均有存活角色） | — |

**自动推进 vs 手动推进**：
- 阶段 0→1→2 和 4→5→6→0：自动推进——进入阶段后立即执行完毕然后 `advance_phase()`
- 阶段 2 和阶段 3：手动推进——等待玩家输入或超时。`advance_phase()` 由 UI 事件触发（按下"结束回合"按钮 / 确认攻击目标 / 超时计时器）

### 子系统编排顺序（每阶段）

```
Phase 0 ENTER:  StatusEffectSystem.tick_all() → 触发"回合开始"效果
Phase 1 ENTER:  DeckSystem.draw(n) → 触发"抽牌时"效果
Phase 2 ENTER:  CostSystem.reset_for_turn()（已在 Phase 6 做完——此处仅更新 UI）
Phase 2 DURING: 玩家出牌 → CostSystem.spend() → CardEffectEngine.resolve() → StatusEffectSystem.apply()
Phase 3 ENTER:  枚举可攻击角色（排除待命/已行动）——构建目标选择列表
Phase 4 DURING: 按速度排序 → 依次：伤害计算 → RealmSystem.get_suppression() → HP 变更 → 阵亡检查
Phase 5 DURING: AISystem.get_next_action() → CardEffectEngine.resolve() → 伤害/HP 变更
Phase 6 ENTER:  触发"回合结束"效果 → CostSystem.reset_for_turn() → 状态过期移除 → 战斗结束检查
```

**编排原则**：
- 战斗系统是编排器（orchestrator）——调用子系统，不拥有它们的内部逻辑
- 子系统调用顺序固定——先 tick_all() 再 draw() 保证"回合开始"效果在抽牌前触发
- 卡牌效果引擎是战斗系统在 Phase 2/5 期间的主要结算引擎——每次出牌/攻击即时调用

### 战斗生命周期 + GSM battle.* 域写入所有权例外

**GSM `battle.*` 域写入所有权**：CombatSystem 是 `GSM.battle.*` 域的独占运行时写入者——这是 ADR-0001 承认的架构层面委托例外（与 ADR-0006 的 SceneManager 写入 `GSM.session.current_scene` 类似）。所有 `battle.*` 的变更通过 GSM 第二层方法进行——`GSM._set_battle_phase()`、`GSM._increment_battle_turn()`、`GSM._set_battle_active()`——而非直接属性赋值。这些方法在写入后发射 `batch_updated` 信号（Cat 1）。其他系统通过 GSM 第一层读取 `battle.*` 数据。

**需要新增的 GSM 第二层方法**（纳入 ADR-0001 第二层 API）：
```gdscript
GSM._set_battle_phase(phase: int) → void
  # 写入 battle.phase = phase + 发射 batch_updated({"battle.phase": {old, new}})

GSM._increment_battle_turn() → void
  # battle.turn += 1 + 发射 batch_updated({"battle.turn": {old, new}})

GSM._set_battle_active(active: bool) → void
  # 写入 battle.is_active = active + 发射 batch_updated({"battle.is_active": {old, new}})
  # active=false 时同时清理 battle.* 域（设为 null）
```

```
┌──────────────────────────────────────────────────────────────────┐
│                     CombatSystem 生命周期                         │
│                                                                   │
│  battle_start(config: CombatConfig) → void                        │
│    ├─ config = {enemy_deck_id, tribulation_level, is_tribulation} │
│    ├─ GSM._set_battle_active(true)  # 创建 battle.* 域             │
│    │   └→ GSM 内部初始化 battle 子域（phase=PREPARATION, turn=1,  │
│    │       player_field=[], enemy_field=[], result=null）          │
│    ├─ 初始化首回合状态：                                           │
│    │   ├─ 所有上场角色标记为"待命"（GDD §4——上场后首回合不可攻击） │
│    │   ├─ 设置 battle.max_cost（从 RealmSystem 读取境界费用上限） │
│    │   ├─ 设置 battle.current_cost = battle.max_cost              │
│    │   └─ 设置 battle.current_hand（开局手牌——先手 4 / 后手 5）   │
│    ├─ 加载敌人卡组 → 初始化 enemy_field                           │
│    ├─ 初始化玩家 field（从 DeploymentSystem 获取上场角色）        │
│    ├─ 创建战斗快照：SaveLoad.create_battle_snapshot(GSM.serialize())│
│    │   # ADR-0003 契约——战斗前自动快照                            │
│    ├─ InputManager.push_lock(ANIMATION, &"combat_system")          │
│    │   # 备战动画/首回合初始化期间锁 gameplay 输入                 │
│    ├─ 发射 battle_started.emit(config) → Cat 2b                    │
│    └─ advance_phase(PREPARATION)  # 开始第一个回合                 │
│                                                                   │
│  battle_end(result: CombatResult) → void                          │
│    ├─ ⚠️ 入口处防御清理（无论从哪个阶段调用）：                     │
│    │   ├─ _attack_queue.clear()  # Phase 4/5 中途调用时的残留清理 │
│    │   ├─ InputManager.clear_locks(&"combat_system")  # 显式清理  │
│    │   │   # 不依赖场景切换的 tree_changed 自动清理——              │
│    │   │   # 可能的 future 场景：battle_end 后保留某些锁            │
│    │   └─ _is_active = false                                      │
│    ├─ IF result == VICTORY:                                       │
│    │   ├─ GSM.apply_battle_rewards(lingshi, cultivation, cards)    │
│    │   │   # ADR-0001 第二层——原子多重写入                        │
│    │   ├─ CardRewardSystem.trigger_loot_selection()                │
│    │   │   # 战利品三选一                                          │
│    │   └─ SaveLoad.clear_battle_snapshot()                        │
│    ├─ IF result == DEFEAT:                                        │
│    │   ├─ GSM.add_resource("ling_shi", retain_50%)                 │
│    │   ├─ GSM.add_cultivation(retain_50%)                          │
│    │   └─ 阵亡角色的绑定卡永久失去（已在阵亡触发时处理）          │
│    ├─ GSM._set_battle_active(false)  # 清理 battle.* 域 → null     │
│    │   # GSM._set_battle_active(false) 内部：                       │
│    │   #   battle = null → 发射 batch_updated({"battle": {old, null}})│
│    ├─ 发射 battle_ended.emit(result) → Cat 2b                     │
│    │   # 消费者：SceneManager（切换场景）、SaveLoad（触发存档）    │
│    └─ SceneManager.request_scene_change(COMBAT, target_scene)      │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 战斗中途撤退

```
retreat() → void
  ├─ IF battle.is_active == false: 返回（无活跃战斗）
  ├─ 确认弹窗："撤退将视为战败——已获得的非绑定物品保留，绑定卡损失永久生效"
  ├─ 玩家确认 → battle_end(RETREAT)
  │   # RETREAT = DEFEAT 语义——50% 保留规则相同
  └─ 玩家取消 → 恢复正常游戏
```

### 信号分类（ADR-0007 合规）

| 信号 | 分类 | 发射时机 | 消费者 | 载荷 | 信号链预估深度 |
|------|------|---------|--------|------|---------------|
| `phase_changed` | Cat 2b | `advance_phase()` 成功后（通过 `_emit_signal_safe`——ADR-0007） | CombatUI（更新阶段指示器）、AudioSystem（阶段音效） | `(old_phase: int, new_phase: int, turn: int)` | 1 层——CombatUI/AudioSystem 直接消费，不触发下游信号 |
| `battle_started` | Cat 2b | `battle_start()` 完成后（通过 `_emit_signal_safe`） | CombatUI（初始化 UI）、AudioSystem（战斗 BGM）、SceneManager（确认战斗场景加载完成） | `(config: Dictionary)` | 1 层——消费者均为初始化操作，不发射下游信号 |
| `battle_ended` | Cat 2b | `battle_end()` 完成后（通过 `_emit_signal_safe`），清理 battle 域之前 | SceneManager（切换场景）、SaveLoad（自动存档判定）、ExplorationSystem（恢复探索） | `(result: CombatResult, rewards: Dictionary)` | 2 层——SaveLoad 的 auto_save() → save_completed(Cat 2b→2 层)。不超过 4 层硬限制 |
| `attack_resolved` | Cat 2b | 每次攻击结算完毕（通过 `_emit_signal_safe`） | CombatUI（播放攻击动画 + 伤害数字）、AudioSystem（命中音效） | `{attacker_id, target_id, damage, is_kill}` # 具名字典——4 参数使用 ADR-0007 具名字典格式 | 1 层——CombatUI/AudioSystem 视觉效果+音效回调，不发射下游信号 |
| `character_died` | Cat 2b | 角色 HP ≤ 0（通过 `_emit_signal_safe`） | CombatUI（阵亡动画）、BindingSystem（解绑检查→发射 GSM 数据变更 Cat 1）、DeploymentSystem（更新可用角色列表） | `(character_id: int, side: Side, binding_card_ids: Array[int])` | 2 层——BindingSystem 解绑 → GSM batch_updated(Cat 1)。不超过 4 层硬限制 |

**信号链深度分析**（ADR-0007 §信号链深度硬限制=4 层）：CombatSystem 最深的信号链路径为 `character_died` → BindingSystem 解绑 → GSM `batch_updated` → HUD 刷新 = 3 层（用户输入[0]→出牌结算[0]→character_died 发射[1]→BindingSystem 处理器解绑[1]→GSM batch_updated[2]→HUD 处理器[2]）——安全位于 4 层硬限制内。所有 CombatSystem 的 Cat 2b 信号通过 ADR-0007 的 `_emit_signal_safe` 包装函数发射——信号链深度在此路径中得到追踪和截断保护。信号处理器必须捕获异常（ADR-0007 禁止模式 #8）——异常逃逸导致的深度计数器泄漏通过 GSM 的帧级重置恢复（ADR-0007 §异常安全性）。

**非信号——直接方法调用**（战斗系统内部编排）：
- `CostSystem.spend(n)` — 需要返回值（bool——费用是否足够）
- `CardEffectEngine.resolve(card, target)` — 需要结果（效果结算结果列表）
- `AISystem.get_next_action(enemy, field)` — 需要返回值（AI 决策）
- `StatusEffectSystem.tick_all()` — 需要保证（所有 tick 在当前阶段前完成）
- `RealmSystem.get_suppression(attacker, defender)` — 需要返回值（float 系数）
- `GSM.apply_battle_rewards(...)` — 需要保证（原子多重写入）

**战斗数据变更 → GSM Cat 1 信号**（非战斗系统自有信号）：
- HP 变更 → `GSM.batch_updated({"battle.player_field[2].hp": {old, new}})` 
- 费用变更 → `GSM.batch_updated({"battle.current_cost": {old, new}})`
- 状态效果变更 → `GSM.batch_updated({"battle.player_field[1].statuses": {old, new}})`

战斗数据变更通过 GSM 第二层方法写入——由 CombatSystem 编排，GSM 负责发射 `batch_updated`——与 ADR-0005 的 InputManager→GSM 锁传播模式一致（无自有信号，复用 Cat 1）。

### 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                    CombatSystem (Feature Autoload)                 │
│                                                                   │
│  ┌─ 战斗生命周期 API ───────────────────────────────────┐        │
│  │ battle_start(config) → void                            │        │
│  │   # 初始化 battle.* 域 + 备战阶段 + 快照 + 开始回合    │        │
│  │ battle_end(result) → void                              │        │
│  │   # 发射奖励 + 清理 battle 域 + 场景切换               │        │
│  │ retreat() → void                                       │        │
│  │   # 撤退 = 确认 DEFEAT 语义                            │        │
│  │ get_current_phase() → CombatPhase                      │        │
│  │ get_turn_number() → int                                │        │
│  │ is_battle_active() → bool                              │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 阶段管理 ───────────────────────────────────────────┐        │
│  │ advance_phase() → bool                                  │        │
│  │ _validate_transition(from, to) → bool                   │        │
│  │ _exit_phase(phase) → void                               │        │
│  │ _enter_phase(phase) → void                              │        │
│  │ confirm_end_turn() → void  # 玩家结束出牌阶段           │        │
│  │ confirm_attack_targets() → void  # 玩家确认攻击目标     │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 信号 (Cat 2b) ──────────────────────────────────────┐        │
│  │ phase_changed(old, new, turn)                          │        │
│  │ battle_started(config)                                 │        │
│  │ battle_ended(result, rewards)                          │        │
│  │ attack_resolved(attacker, target, damage, is_kill)     │        │
│  │ character_died(char_id, side, binding_card_ids)        │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 内部状态 ───────────────────────────────────────────┐        │
│  │ _phase: CombatPhase = PREPARATION                      │        │
│  │ _turn: int = 1                                         │        │
│  │ _attack_queue: Array[AttackEntry]  # Phase 3→4 排序   │        │
│  │ _is_active: bool = false                               │        │
│  │ _phase_timer: float = 0.0  # Phase 2 超时计时器       │        │
│  └────────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────┘
         │                │                │                │
         ▼                ▼                ▼                ▼
    ┌─────────┐    ┌────────────┐   ┌────────────┐   ┌──────────┐
    │   GSM   │    │CardEffect  │   │CostSystem  │   │StatusEff │
    │ battle.*│    │  Engine    │   │            │   │  System  │
    │(Cat 1)  │    │(直接调用)   │   │(直接调用)   │   │(直接调用) │
    └─────────┘    └────────────┘   └────────────┘   └──────────┘
         │                │                │                │
         ▼                ▼                ▼                ▼
    ┌─────────┐    ┌────────────┐   ┌────────────┐   ┌──────────┐
    │CombatUI │    │AISystem    │   │Deployment  │   │BindingSys│
    │(Cat 2b  │    │(直接调用)   │   │  System    │   │(直接调用) │
    │ 消费者) │    │            │   │(备战)       │   │          │
    └─────────┘    └────────────┘   └────────────┘   └──────────┘
```

### 关键接口

#### CombatPhase 枚举 + 阶段状态机

```gdscript
enum CombatPhase {
    PREPARATION = 0,     # 准备阶段——tick 效果 + "回合开始"触发
    DRAW = 1,            # 抽牌阶段——抽 2 张 + "抽牌时"触发
    PLAY = 2,            # 出牌阶段——玩家主动出牌
    ATTACK_DECLARATION = 3,  # 攻击声明——玩家分配攻击目标
    ATTACK_RESOLUTION = 4,   # 攻击结算——按速度依次结算
    ENEMY_TURN = 5,      # 敌方行动——AI 决策 + 结算
    END = 6,             # 结束阶段——"回合结束"触发 + 战斗结束检查
}

enum CombatResult {
    NONE = 0,
    VICTORY = 1,         # 敌方全灭
    DEFEAT = 2,          # 己方全灭
    RETREAT = 3,         # 玩家撤退（DEFEAT 语义）
}
```

#### advance_phase() 核心算法

```gdscript
func advance_phase() -> bool:
    if not battle.is_active:
        push_error("CombatSystem: advance_phase() called with no active battle")
        return false

    var current: CombatPhase = battle.phase
    var next: CombatPhase = current + 1 if current < CombatPhase.END else CombatPhase.PREPARATION

    # 阶段转换验证
    if not _validate_transition(current, next):
        push_warning("CombatSystem: phase transition %d→%d rejected——preconditions not met"
                    % [current, next])
        return false

    # 退出当前阶段
    _exit_phase(current)

    # 进入下一阶段
    _enter_phase(next)

    # 更新状态——通过 GSM 第二层方法（非直接赋值——ADR-0001 §写入者契约）
    var old_phase: int = battle.phase
    GSM._set_battle_phase(next)  # GSM 第二层——发射 batch_updated({"battle.phase": {old, new}})
    if next == CombatPhase.PREPARATION:
        GSM._increment_battle_turn()  # GSM 第二层——发射 batch_updated({"battle.turn": {old, new}})

    # Cat 2b 信号——CombatUI 监听以更新阶段指示器
    # ⚠️ 通过 _emit_signal_safe（ADR-0007）路由——信号链深度追踪
    _emit_signal_safe(self, &"phase_changed", [old_phase, next, battle.turn])

    # 自动推进：如果下一阶段也是自动阶段，递归调用
    # ⚠️ 不使用 while 循环——每个阶段在 _enter_phase 中通过 _process() 完成后
    #    再调用 advance_phase()，避免单帧内阻塞主线程
    # 自动阶段的 _enter_phase 在完成其工作后调度下一帧的 advance_phase()

    return true

func _validate_transition(from: CombatPhase, to: CombatPhase) -> bool:
    match from:
        CombatPhase.PLAY:
            # 出牌→攻击声明：玩家已确认结束或自动条件满足
            return (_player_confirmed_end
                    or _phase_timer_exceeded
                    or (_hand_empty and not _can_afford_any_card()))
        CombatPhase.ATTACK_DECLARATION:
            # 攻击声明→结算：所有角色已分配目标或玩家跳过
            return (_all_characters_targeted() or _player_confirmed_attack_skip)
        _:
            return true  # 其他阶段无条件推进
```

#### 子系统编排器模式

```gdscript
## 阶段入口——按固定顺序调用子系统
func _enter_phase(phase: CombatPhase) -> void:
    match phase:
        CombatPhase.PREPARATION:
            # 1. 状态效果 tick（持续伤害/恢复/倒计时）
            StatusEffectSystem.tick_all(battle.player_field)
            StatusEffectSystem.tick_all(battle.enemy_field)
            # 2. 触发"回合开始"效果（卡牌效果引擎）
            _trigger_turn_start_effects()
            # 3. 自动推进到抽牌
            _schedule_auto_advance.call_deferred()

        CombatPhase.DRAW:
            # 1. 计算抽牌数量（基础 2 + 修正）
            var draw_count := _calculate_draw_count()
            # 2. 从牌库抽牌
            DeckSystem.draw(draw_count)
            # 3. 触发"抽牌时"效果
            _trigger_draw_effects()
            # 4. 自动推进到出牌
            _schedule_auto_advance.call_deferred()

        CombatPhase.PLAY:
            # 1. 启用玩家输入——InputManager 解锁 gameplay
            InputManager.pop_lock(&"combat_system")
            # 2. 启动超时计时器（可选——仅 PvE 中作为防卡死措施）
            _phase_timer = 0.0
            # 3. 等待玩家操作——不自动推进
            #    confirm_end_turn() 由 UI 按钮触发

        CombatPhase.ATTACK_DECLARATION:
            # 玩家主动阶段——需要选择攻击目标（GAMEPLAY 输入）
            InputManager.pop_lock(&"combat_system")
            # ⚠️ 必须显式 pop ANIMATION 锁——Phase 2 PLAY 的 _exit_phase 推入了 ANIMATION 锁
            # 攻击声明是玩家交互阶段，需要解锁 GAMEPLAY 以支持目标选择
            _attack_declaration_timeout = 0.0

        # ... (其他阶段类似)

## 阶段出口——清理当前阶段状态
func _exit_phase(phase: CombatPhase) -> void:
    match phase:
        CombatPhase.PLAY:
            # 锁定 gameplay 输入（防止玩家在结算期间操作）
            InputManager.push_lock(LockType.ANIMATION, &"combat_system")
            _player_confirmed_end = false
        CombatPhase.ATTACK_DECLARATION:
            _attack_target_queue.clear()
            # 重新推入 ANIMATION 锁——攻击声明结束后进入自动结算阶段
            InputManager.push_lock(LockType.ANIMATION, &"combat_system")
            _player_attack_confirmed = false
        CombatPhase.ATTACK_RESOLUTION:
            _attack_queue.clear()
        CombatPhase.END:
            # 清除"已行动"和"待命"标记
            _reset_character_action_states()
```

#### 出牌结算流程（Phase 2 核心交互）

```gdscript
## 玩家打出卡牌——由 CombatUI 触发
func play_card(card_instance_id: int, target_indices: Array[int]) -> bool:
    if battle.phase != CombatPhase.PLAY:
        push_warning("CombatSystem: play_card() called outside PLAY phase")
        return false

    var card: CardInstance = CardSystem.get_instance(card_instance_id)
    if card == null:
        return false

    # 费用验证
    if not CostSystem.can_afford(card.template.cost):
        return false

    # 目标验证（由卡牌效果引擎验证目标合法性）
    var targets: Array = _resolve_targets(card.template, target_indices)
    if not CardEffectEngine.validate_targets(card.template, targets):
        return false

    # 扣费（直接调用——需要保证）
    CostSystem.spend(card.template.cost)

    # 结算效果（直接调用——需要结果列表）
    var results: Array[Dictionary] = CardEffectEngine.resolve(card, targets)

    # 费用变更通过 GSM 传播（Cat 1）
    # GSM.set_battle_cost() → batch_updated({"battle.current_cost": {old, new}})

    # 检查阵亡（效果结算可能导致角色死亡）
    _check_and_process_deaths()

    # 检查自动推进条件
    if _hand_empty and not _can_afford_any_card():
        advance_phase()  # 空手牌 + 无费可出 → 自动结束出牌

    return true
```

### 准备阶段调度模式

非玩家主动阶段（0, 1, 4, 5, 6）使用 `call_deferred()` 在下一帧自动推进，确保每阶段至少 1 帧——CombatUI 在此期间渲染阶段指示器更新和过渡动画：

```gdscript
## 自动阶段——完成后延迟到下一帧推进
func _schedule_auto_advance() -> void:
    advance_phase.call_deferred()
    # ⚠️ 仅在自动阶段使用 call_deferred()——
    #    这不是打破信号链（ADR-0007 §信号链深度）——
    #    这是编排调度，而非信号→处理器→再发射信号的递归
```

**区别于 ADR-0007 的 `call_deferred()` 禁令**：ADR-0007 禁止用 `call_deferred()` 打破信号链——因为那会引入时序不确定性。战斗系统的 `call_deferred()` 用于**编排调度**（确保每阶段至少 1 帧渲染），而非用于信号处理器内部。此处用法合法。

## 考虑的替代方案

### 替代方案 A：6 阶段模型——合并攻击声明+结算

- **描述**：Phase 3 和 Phase 4 合并为一个"攻击阶段"——玩家声明目标后立即结算，无需单独的声明阶段
- **优点**：减少 1 个阶段——流程更快；UI 不需要单独的"确认攻击目标"步骤；不会出现"目标在声明后结算前死亡"的边缘情况
- **缺点**：玩家失去了"先看完所有声明再统一结算"的战术视角——无法调整攻击顺序；"攻击声明后目标被其他攻击先手击杀→重新选择目标"的博弈层消失
- **拒绝原因**：GDD 已明确 7 阶段模型（combat-system.md §1 完整回合流程）。分离声明与结算创造了速度排序和"先手击杀"的策略深度——这是"修士弈局"框架的核心机制。合并将削平此深度

### 替代方案 B：自由阶段模型（如 Slay the Spire —— 玩家主导顺序）

- **描述**：不强制阶段顺序——玩家可在任何时间出牌、攻击、使用道具。回合制但阶段由玩家自行管理
- **优点**：最大灵活性——玩家操作顺序完全自主；现代卡牌 Roguelike 的主流模式（Slay the Spire、Monster Train）
- **缺点**：与"攻击必定命中、按速度排序"的机制冲突——需要隐式管理攻击顺序（先声明后结算的设计需要显式阶段）；与"待命"（上场后不可攻击）的机制冲突——需要状态追踪而非阶段约束
- **拒绝原因**：本游戏的战斗设计根植于"境界压制"和"速度排序"的修仙世界观——这些机制需要一个确定的结算顺序，自由阶段无法提供。"攻击声明→速度排序→依次结算"是"修士弈局"的情感载体——玩家预判"我的快攻角色先手秒掉敌方脆皮"并看到它按预期发生

### 替代方案 C：每阶段独立 Autoload —— 分散式阶段管理

- **描述**：每个阶段作为独立系统（`PreparationPhase`、`PlayPhase`、`AttackPhase`...）——通过信号链串联
- **优点**：每个阶段独立可测试——单元测试不入 CombatSystem 即可覆盖阶段逻辑；阶段可被其他系统复用（如渡劫战复用准备阶段）
- **缺点**：分散在 7 个系统中——阶段间的数据传递（攻击队列、目标列表、回合计数器）需要共享状态或信号载荷；测试"完整 7 阶段流程"需要 7 个系统的集成测试；违反了编排器模式
- **拒绝原因**：CombatSystem 是编排器——阶段是它的内部状态，不是独立系统。7 个阶段共享同一个 battle 上下文（attack_queue、field 状态、回合计数器）——分散到 7 个系统中会创建紧耦合的接口边界。当前设计：1 个系统，7 个 match 分支——调试时在同一个文件中追踪完整回合流程

## 后果

### 积极的

- **确定性结算**：7 阶段顺序强制执行——每回合的 tick→draw→play→declare→resolve→enemy→end 序列保证一致，测试可精确重播
- **编排器关注点分离**：CombatSystem 不拥有卡牌效果、费用计算、AI 决策或状态效果的内部逻辑——它调度它们。子系统可独立开发和测试
- **ADR-0007 信号合规**：5 个 Cat 2b 信号（phase_changed、battle_started、battle_ended、attack_resolved、character_died）——语义清晰，消费者明确。HP/费用变更通过 GSM Cat 1 传播——无自有数据信号重复
- **手动推进保护**：advance_phase() 在手动阶段返回 false——防止 UI bug 提前推进回合。自动阶段在 `_enter_phase()` 完成后才调度下一帧推进
- **撤退即 DEFEAT 语义**：retreat() = 确认 battle_end(DEFEAT)——无重复逻辑路径

### 消极的

- **3 个手动阶段需要计时器防卡死**：Phase 2 和 Phase 3 依赖玩家输入——需超时计时器防止无限等待（PvE 中 AI 等待玩家、PvP 中对手掉线）
- **Autoload 初始化顺序依赖 9 个子系统**：Godot 的 Autoload `_ready()` 顺序完全由 Project Settings 中的列表顺序决定——非类名或依赖树。CombatSystem 必须在 GSM、CardSystem、CostSystem、StatusEffectSystem、CardEffectEngine、AISystem、DeploymentSystem、BindingSystem、RealmSystem 之后注册。如果在依赖子系统就绪前访问，将读取到未初始化的状态。缓解措施：`CombatSystem._ready()` 检查 `GSM._initialized` 标志——未就绪时 `push_error` 并延迟初始化。建议为所有 Feature 层 Autoload 采用统一的"初始化就绪信号"模式（监听 `gsm_initialized`）
- **所有 Cat 2b 信号通过 `_emit_signal_safe` 路由**：CombatSystem 的 5 个 Cat 2b 信号必须通过 ADR-0007 的 `_emit_signal_safe` 包装发射——信号链深度在发射路径中得到追踪。信号处理器必须包裹异常处理（ADR-0007 禁止模式 #8）——未捕获异常逃逸导致的深度计数器泄漏通过 GSM 帧级重置恢复
- **`call_deferred()` 调度增加 1 帧延迟**：自动阶段之间增加 1 帧间隔——虽然战斗节奏不受影响（1/60s = 16.6ms），但阶段过渡动画的可能最长 6 × 16.6ms = 100ms 回合内"停滞"

### 风险

- **多 hit/连锁效果栈溢出**：卡牌效果引擎的递归深度上限 16（ADR-0009 待定）——战斗中一次出牌触发 3 个连锁效果（每个需要栈推入）→ 可能超过上限。缓解措施：效果引擎拒绝超过 16 层的栈推入——记录错误但战斗继续；严重破坏性效果（可导致状态不一致）在 13 层时提前警告
- **敌方行动阶段过长的 AI 决策阻塞**：AI 行为树搜索在大型 field（6v6 = 12 角色 + 3 阵法）可能超过帧预算。缓解措施：AI 决策使用迭代加深——先返回快速估算，随后 refine。或在敌方行动阶段使用 `_physics_process` 分步结算（1 个敌方角色/帧）
- **Phase 5→6 跳过 Phase 0 后回合计数不准确**：如果 END 阶段检查到战斗结束（battle_end），则不进入 PREPARATION——下一个回合的 turn 计数器将被 battle_end 清除。不影响存档或其他系统——`battle.turn` 仅在战斗活跃时有效
- **Phase 2 超时可能导致不公平的回合跳过**：计时器在玩家思考时到期——特别是在 PvP 或连续战斗场景中。缓解措施：默认无超时（PvE）——仅作为可配置选项提供给 PvP 模式

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| combat-system.md | §1 完整回合流程——7 阶段顺序执行 | 确立 7 阶段 CombatPhase 枚举 + advance_phase() 确定性序列——每阶段有 `_enter_phase()` / `_exit_phase()` / `_validate_transition()` |
| combat-system.md | §2 抽牌规则——基础 2 张 + 后手补偿 3 张 | Phase 1 DRAW——`_calculate_draw_count()` 根据 turn=1 + is_first_player 计算；后手额外 +1 费在 Phase 1 ENTER 中处理 |
| combat-system.md | §3 费用规则——每回合全额恢复，不累积 | Phase 6 END——`CostSystem.reset_for_turn()` 重置费用；境界上限由 RealmSystem 在 battle_start 时读取并传递给 CostSystem |
| combat-system.md | §4 出牌规则——6 种卡牌类型的出牌和效果时机 | Phase 2 PLAY——`play_card()` 通过 CostSystem.spend() + CardEffectEngine.resolve() 编排；效果立即结算 |
| combat-system.md | §6 攻击规则——速度排序 + 每角色 1 次攻击 | Phase 3 ATK_DEC + Phase 4 ATK_RES——attack_queue 按速度排序；分离声明与结算支持"先手击杀后重选目标" |
| combat-system.md | §7 角色阵亡规则——永久失去绑定卡 + 空载复活 | Phase 4/5 的 `character_died` 信号——BindingSystem 监听以解绑；涅槃丹通过 CardEffectEngine.resolve() 处理——复活但 flag 标记为空载 |
| combat-system.md | §8 境界压制规则——高 1 级 -20%/高 2 级 -50% | Phase 4 伤害计算——`RealmSystem.get_suppression(attacker_realm, defender_realm)` 返回系数；在 `_calculate_damage()` 中应用 |
| combat-system.md | §9 战斗结束规则——胜利/失败/撤退 | Phase 6 检查条件 → `battle_end(VICTORY/DEFEAT)`；`retreat()` 独立 API——确认后调用 `battle_end(RETREAT)`；跨战斗死亡持久性由 DeploymentSystem 管理 |
| combat-system.md | §状态与转换——备战→战斗中→胜利/战败 | 战斗生命周期——`battle_start()` 初始化 battle.* 域 + 快照；`battle_end()` 清理 + 奖励/损失结算；`is_active` 标志防止无效操作 |
| combat-system.md | §与其他系统的交互——9 个子系统数据流 | 子系统编排——直接方法调用（非信号）编排子系统；编排顺序在每阶段的 `_enter_phase()` 中固定 |
| architecture.md §架构原则 #2 | 信号用于通知，不是用于逻辑 | 5 个 Cat 2b 信号通知 UI/Audio/SaveLoad——战斗逻辑通过直接方法调用编排；HP/费用数据变更通过 GSM Cat 1 传播 |
| architecture.md OQ-01 | 卡牌效果引擎中每个效果类型的具体读写契约 | Phase 2/5 的 `CardEffectEngine.resolve(card, targets)` 确立调用契约——输入（card + targets）→ 输出（results: Array[Dict]）——为 ADR-0009 提供框架 |
| architecture.md C3 | 效果栈结算顺序未指定 | 本 ADR 规定——Phase 0 "回合开始"效果 → Phase 1 "抽牌时"效果 → Phase 2/5 即时卡牌效果 → Phase 6 "回合结束"效果。同阶段内按注册顺序出栈 |

## 性能影响

- **CPU**：`advance_phase()` 含验证 + 进入/退出匹配——每阶段 <0.05ms。战斗系统的 `_process()` 每帧检查：phase == PLAY && timer_active → 递增（<0.001ms）。9 个子系统的直接方法调用开销取决于子系统实现——战斗系统自身的编排开销 <0.1ms/帧
- **内存**：CombatSystem Autoload 实例 <10KB（6 个状态字段 + 信号连接）。GSM battle.* 域——player_field（最多 6 角色 × ~512B）= 3KB + enemy_field（类似）= 3KB + 元数据（phase/turn/result）= <200B。总计 <20KB 的运行时战斗状态
- **加载时间**：`battle_start()` 需加载敌人卡组（CardSystem 模板查询——O(1) 字典，<1ms）。战斗快照写入 <50ms（ADR-0003——FileAccess 原子写入）
- **网络**：不适用（纯单机游戏）

## 迁移计划

无现有代码需迁移——这是 Core/Feature 层初始决策。以下为实现顺序约束：

1. **ADR-0009（卡牌效果引擎）** 必须在本 ADR 之后被接受——效果引擎的结算入口在 combat-system 的 Phase 2/5 中
2. **上场阵位系统 ADR** 的备战阶段在 `battle_start()` 中编排——上场阵位系统必须在 `battle_start()` 调用前返回 `player_field` 定义
3. **ConstSystem / StatusEffectSystem / RealmSystem** 作为战斗系统的子系统——在 CombatSystem Autoload 初始化后注册

## 验证标准

- 通过 GUT：`CombatSystem` 测试套件覆盖：
  - `advance_phase()` 在 Phase 0→1→2 自动推进成功
  - `advance_phase()` 在 Phase 2 未确认结束时返回 false
  - `advance_phase()` 在非活跃战斗时返回 false + push_error
  - `battle_start(config)` 初始化 battle.* 域——phase=PREPARATION, turn=1, is_active=true
  - `battle_end(VICTORY)` 调用 `GSM.apply_battle_rewards()` ——参数正确
  - `battle_end(DEFEAT)` 保留 50% 资源——`GSM.add_resource()` 和 `GSM.add_cultivation()` 被调用且参数正确
  - `battle_end(RETREAT)` 语义与 DEFEAT 相同——50% 保留
  - `retreat()` 在 `is_active == false` 时返回而不修改状态
  - `retreat()` 在 `is_active == true` 时发射确认提示信号（Cat 2b）——UI 展示确认弹窗
  - `character_died` 信号携带正确的 `binding_card_ids`——绑定系统可据此解绑
  - 回合循环：Phase 0→1→2（手动确认）→3（手动确认）→4→5→6→0——完整 1 回合流程通过
  - Phase 2 超时——timer_exceeded → advance_phase() 成功
  - 攻击目标在声明后死亡——Phase 4 重选目标逻辑正确（优先同排同列）
  - 境界压制——`RealmSystem.get_suppression()` 在伤害计算中被调用，返回值正确应用于 `final_damage`
- 通过集成测试：
  - 完整战斗流程：battle_start → 2 回合 → battle_end(VICTORY) → GSM 收到奖励 + battle 域被清除
  - CombatUI 监听 `phase_changed` → 阶段指示器随 advance_phase() 更新
  - SaveLoad 在 `battle_ended` 信号后触发自动存档
- 通过手动测试：
  - 7 阶段完整回合流程在目标硬件上 <100ms 阶段过渡（含动画）
  - 战斗中撤退确认弹窗正确展示——确认后战斗结束 + 50% 保留

## 相关决策

- ADR-0001（游戏状态管理器——battle.* 域 + `apply_battle_rewards()` + `add_resource()` + `add_cultivation()`）
- ADR-0002（卡牌数据模型——卡牌模板查询用于 battle_start 加载敌人卡组；CardInstance 用于 player_field）
- ADR-0003（存档/读档——战斗快照 `pre_battle.json`；`battle_ended` 触发自动存档）
- ADR-0004（事件系统——EventSystem 的 TRIGGER_BATTLE Outcome → 调用 CombatSystem.battle_start()）
- ADR-0005（输入管理器——Phase 2 推入/弹出 ANIMATION 锁；Phase 3 推入/弹出 gameplay 锁）
- ADR-0006（场景管理器——`battle_started` → 加载战斗场景；`battle_ended` → 切换到探索/结算场景）
- ADR-0007（信号分类——5 个 Cat 2b 信号 + 直接方法调用编排 9 个子系统）