# 仙途问道 — 主架构文档 (Master Architecture)

## 文档状态

- **版本 (Version)**：1.4
- **最后更新 (Last Updated)**：2026-07-25
- **引擎 (Engine)**：Godot 4.6
- **覆盖的 GDD (GDDs Covered)**：36 个系统（见 design/gdd/systems-index.md）
- **引用的 ADR (ADRs Referenced)**：29 个（ADR-0001 至 ADR-0029，全部 Proposed）
- **最近架构审查**：2026-07-25 — 裁决 CONCERNS（见 `docs/architecture/architecture-review-2026-07-25.md`）
- **技术总监签署 (TD Sign-Off)**：2026-07-24 — APPROVED WITH CONDITIONS（5 个 CONCERNS 全部已通过对应 ADR 解决 ✅）
- **主程序员可行性 (LP Feasibility)**：FEASIBLE — 所有 5 个 CONCERNS 已解决
  - C1：境界系统层归属 → 已通过 ADR-0010 迁移至 CORE 层 ✅
  - C2：初始化序列与架构原则 #3 矛盾 → ADR-0007 信号委托 + ADR-0004 ADD_CARD 信号解耦 ✅
  - C3：效果栈结算顺序未指定 → ADR-0009 ResolutionStack 5 级优先级 ✅
  - C4：信号粒度未定义 → ADR-0007 三分类信号体系 ✅
  - C5：`Outcome` 类型可能重复 → ADR-0009 扩展 ADR-0004 OutcomeType 枚举（非复制）✅

---

## 引擎知识缺口摘要

| 版本 | 风险等级 | 对本项目有影响的变更 |
|------|---------|-------------------|
| 4.6 | HIGH | 双焦点系统（UI×5 系统 + 输入管理器）、D3D12 默认、Glow 在 tonemapping 之前 |
| 4.5 | HIGH | GDScript 可变参数 + `@abstract`（效果引擎、战斗系统）、FoldableContainer、SDL3 手柄 |
| 4.4 | MEDIUM | `FileAccess.store_*` 返回 `bool`（存档系统）、Shader 纹理类型变更 |

**关键约束**：所有使用 `Control` 节点的 UI 系统必须处理 4.6 双焦点（鼠标 ≠ 键盘焦点）。所有存档写入必须检查 `FileAccess` 返回值。

---

## 系统层映射

```
┌──────────────────────────────────────────────────────────────┐
│  PRESENTATION 层 (6 系统)              ⚠️ UI ×5 HIGH (4.6)   │
│  战斗UI / 探索UI / 卡组编辑UI / HUD / 主菜单 / 音频          │
├──────────────────────────────────────────────────────────────┤
│  FEATURE 层 (18 系统)                                        │
│  战斗 / 卡牌效果引擎 / 上场阵位 / 绑定 / 阵法 /                │
│  AI / 探索 / 修为养成 / 渡劫 / 卡组编辑 /                       │
│  炼丹 / 铭刻 / 开局身份 / 轮回天赋 / 成就 /                     │
│  剧情 / 对话 / 结局分支                                        │
├──────────────────────────────────────────────────────────────┤
│  CORE 层 (8 系统)                                             │
│  卡牌系统 / 费用系统 / 行动力系统 / 状态效果系统 / 境界系统 /  │
│  阵营系统 / 资源系统 / 流派系统                               │
├──────────────────────────────────────────────────────────────┤
│  FOUNDATION 层 (6 系统)                                      │
│  游戏状态管理器 / 存档读档 / 事件系统 /                       │
│  输入管理器 / 场景管理器 / 存档模式版本控制                   │
├──────────────────────────────────────────────────────────────┤
│  PLATFORM 层                                                 │
│  Godot 4.6 / Forward+ / D3D12 (Win) / Godot Physics 2D       │
└──────────────────────────────────────────────────────────────┘
```

---

## 模块归属

### FOUNDATION 层

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **游戏状态管理器** | `GameState` 树、所有运行时属性 | `get_state(path)` / `set_state(path, val)` / 变更信号 | 无（基础设施） | `Node` (Autoload) |
| **存档/读档系统** | `save.json` / `progression.dat` / `meta.json` + `schema_version` + 迁移链 | `save(slot)` / `load(slot)` / `auto_save()` / `load_progression()` | 游戏状态管理器 | `FileAccess` (4.4+ `store_*` → `bool`) ⚠️ MEDIUM |
| **事件系统** | 事件模板 DB、`story_flags` 运行时写入权 | `trigger_event(id)` / `set_flag(key, val)` | 游戏状态管理器、探索系统 | `Resource` (模板序列化) |
| **输入管理器** | `session.input_locks` 栈 | `is_input_allowed(type)` / `push_lock(type)` / `pop_lock(type)` | 游戏状态管理器 | `Input` (4.6 双焦点) ⚠️ HIGH |
| **场景管理器** | 场景转换流程 | `request_scene_change(from, to, type)` | 游戏状态管理器、存档系统、输入管理器 | `SceneTree.change_scene_to_file()` |

### CORE 层

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **卡牌系统** | `CardTemplate`、`CardInstance` 运行时集合 | `get_card(id)` / `get_collection()` | 游戏状态管理器 | `Resource` (模板)、`JSON` |
| **费用系统** | 每回合费用值、临时加成栈 | `get_current_cost()` / `spend(n)` / `can_afford(n)` / `reset_for_turn()` / `add_temp_bonus()` | 境界系统、战斗系统 | — |
| **行动力系统** | `action_points` 值 | `get_ap()` / `spend_ap(n)` / `restore_ap(n)` | 游戏状态管理器、境界系统 | — |
| **境界系统** | `RealmTable` 属性表、压制系数、稀有度权重表 | `get_realm_property(level, key)` / `realm_penalty()` / `get_rarity_weights()` | GSM、战斗/上场/卡牌/卡组/探索/修为/渡劫/AI/UI 共 13+ 系统 | `Dictionary` (const 编译时常量) |
| **状态效果系统** | 所有 `StatusEffect` 实例 | `apply_status()` / `remove_status()` / `get_active(target)` / `tick_all()` | 卡牌效果引擎 | `Object` (实例管理) |
| **阵营系统** | `FACTION_LIBRARY` 标签库（const Dictionary） | `get_tag_info()` / `count_on_field()` / `check_condition()` / `is_hostile_to()` / `belongs_to_alignment()` | 阵法、效果引擎、流派、探索、AI | `Dictionary` (const 编译时常量) |
| **资源系统** | 7 条资源公式 + 类型安全读写 API | `add_resource()` / `spend_resource()` / `can_spend()` / `dismantle_value()` / `delete_card_cost()` / `realm_gap_penalty()` | GSM、商店、卡组编辑、炼丹炼器、法宝铭刻、战斗、探索、事件 | — |
| **流派系统** | `SCHOOL_LIBRARY` 5 流派静态库（const Dictionary） | `detect(state)` / `calculate_match()` / `get_school_effects()` / `get_school_info()` | 战斗、卡组编辑UI、战斗HUD | `Dictionary` (const 编译时常量) |

### FEATURE 层

#### 战斗子系统

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **战斗系统** | `CombatTurn`、7 阶段状态机 | `start_battle(enemy)` / `end_battle(result)` | 9 个子系统 (费用/卡牌/AI/效果引擎/状态/上场/绑定/阵法/境界) | `SceneTree` |
| **卡牌效果引擎** | 效果解析栈、效果类型注册表 | `resolve(card, target)` / `register_effect(type, handler)` | 7 个系统 (卡牌/绑定/状态/阵法/阵营/费用/GSM) | `Object` (动态类型) |
| **上场阵位系统** | `_field` Dictionary（6格阵位）、内部状态机（STANDBY→READY→ACTED）、`_unavailable_characters` 不可用角色列表 | `deploy(card, slot)` / `remove_character(id)` / `is_targetable(id)` / `is_standby(id)` / `get_field()` / `clear_standby_state()` / `mark_unavailable()` / `revive_character()` / `is_game_over()` | 战斗系统、AI系统、绑定系统、阵法系统、商店系统、事件系统 | `Dictionary` (const 编译时常量) |
| **绑定系统** | `BindingRelationship` (RefCounted) | `bind(character, item)` / `unbind(slot)` / `get_bindings(character)` | 战斗系统、卡牌系统、上场阵位系统 | — |
| **阵法系统** | `FormationAura` | `deploy_formation(card, slots)` / `get_aura()` | 战斗系统、上场阵位系统、阵营系统 | — |
| **AI 系统** | `EnemyTemplate` (Resource, .tres)、`EnemyBattleState` (RefCounted)、BossPhaseMgr 内部状态机 | `execute_turn(field_state)` / `create_enemy_roster(template_ids)` / `register_preconfigured_bindings()` | 战斗系统、卡牌效果引擎、绑定系统、阵法系统 | `Resource` (.tres 模板) |

#### 探索与经济子系统

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **探索系统** | 地图布局、节点状态 | `generate_map(seed)` / `move_to_node(id)` / `resolve_node(id)` | 事件/行动力/GSM/境界/资源 共 5 系统 | `RandomNumberGenerator` |
| **修为养成系统** | `cultivation` 值、溢出池、统一获取入口 | `gain_cultivation(amount, source)` / `get_progress()` / `get_overflow_pool()` / `settle_overflow()` | GSM、境界系统、渡劫系统、HUD | — |
| **境界系统** | `RealmTable` 属性表、压制系数、稀有度权重表 | `get_realm_property(level, key)` / `realm_penalty()` / `get_rarity_weights()` | GSM、战斗/上场/卡牌/卡组/探索/修为/渡劫/AI/UI 共 13+ 系统 | `Dictionary` (const 编译时常量) |
| **境界压制规则** | 压制系数计算 | `get_suppression(attacker_realm, defender_realm)` | 境界系统、战斗系统 | — |
| **渡劫突破系统** | 渡劫流程编排、TribulationState 状态机 | `trigger_tribulation()` / `check_tribulation_ready()` / `use_tribulation_pill()` | 境界系统、战斗系统、修为养成系统、输入管理器 | — |
| **卡组编辑系统** | `Deck`、卡组验证器、战利品编排 | `add_to_deck(card)` / `remove_from_deck(card)` / `generate_loot_options()` / `execute_delete()` / `initialize_initial_deck()` | 卡牌/GSM/资源系统/探索系统 | — |
| **炼丹炼器系统** | 配方表（const Dictionary, 8 配方）、独立 RNG 实例 | `craft(recipe, materials)` / `get_recipes()` / `get_recipe_by_id()` / `roll_quality()` / `forge_artifact_stat()` | 资源/卡牌/GSM/卡组编辑 | — (RefCounted class_name, 非 Autoload) |
| **法宝铭刻系统** | 铭刻属性、铭刻配方 | `inscribe(item, inscription)` / `get_inscriptions(item)` | 炼丹炼器/资源/境界 | — |
| **开局身份系统** | 身份模板 `const Dictionary`（6 个）、天赋键值注册表 | `get_available_identities()` / `apply_identity(id)` / `is_identity_selected()` | GSM/卡牌/卡组编辑/资源/轮回天赋 | `Dictionary` (const 编译时常量) |

#### 成长与元进度子系统

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **流派系统** | 5 流派静态库（已迁移至 Core 层——ADR-0025） | — | — | — |
| **轮回天赋系统** | `PlayerTalents`、天赋树、轮回结算 | `unlock_talent(id)` / `get_active_talents()` / `settle_run(gsm)` | 存档系统、开局身份 | — |
| **成就系统** | `Achievement` 实例、解锁状态 | `check(criteria)` / `get_achievements()` | 存档系统、GSM | — |

#### 叙事子系统

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **剧情系统** | `CHAPTER_TEMPLATES` 5 章静态定义 + GSM `narrative.*` 域 | `get_current_chapter()` / `complete_chapter()` / `can_enter_chapter()` / `get_chapter_context()` | 探索/境界/事件系统 | `Dictionary` (const 编译时常量) |
| **对话系统** | DialoguePlayer + DialogueDatabase + BarkManager（RefCounted，非 Autoload） | `start_dialogue(id)` / `select_option(opt)` / `play_bark(npc, key)` | 剧情/事件/GSM | — (RefCounted 服务类) |
| **结局分支系统** | `EndingEvaluator` 纯函数工具类（嵌入 StorySystem，非 Autoload） | `evaluate_ending()` / `get_ending_by_flag(flags)` / `get_endings_by_flag(flags)` | 剧情系统、GSM (只读) | — (RefCounted 嵌入 StorySystem) |

### PRESENTATION 层 ⚠️ HIGH RISK (4.6 双焦点)

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **战斗UI系统** | 战场布局、手牌显示 | `render_field()` / `show_hand()` / `highlight_targets()` | 战斗/卡牌效果引擎/状态效果 | `Control` (4.6 双焦点) |
| **探索UI系统** | 地图视图、节点渲染 | `render_map()` / `show_event(event)` | 探索系统 | `Control` (4.6 双焦点) |
| **卡组编辑UI** | 卡组编辑界面 | `render_deck()` / `show_collection()` | 卡组编辑系统、卡牌系统 | `Control` (拖拽) |
| **HUD系统** | 顶部/底部信息条 | `update_resources()` / `update_realm()` / `update_ap()` | GSM/境界/资源/卡组编辑/行动力/费用 | `Control` |
| **主菜单与设置** | 菜单层次、设置持久化 | `show_menu()` / `load_save_list()` / `save_settings()` | GSM、存档系统 | `Control` (4.6 双焦点) |
| **音频管理系统** | `AudioBus` 配置、对象池 | `play_sfx(id)` / `play_bgm(id)` / `set_volume(bus, db)` | 事件/GSM/设置 | `AudioStreamPlayer`、`AudioServer` |

---

## 数据流

### 帧更新路径

```
每帧 (16.6ms 预算, 60fps)

_input(event) → 输入管理器.is_input_allowed(type)
  ├─ locked → 吞噬事件
  └─ allowed → _unhandled_input(event) → 当前场景 Control 树
       ⚠️ 4.6 双焦点: 鼠标焦点 ≠ 键盘焦点

_physics_process(delta) → 游戏逻辑 (战斗中为战斗系统编排)
  └→ 读取 GSM (无锁)，写入通过 GSM 原子操作 + 信号广播
```

### 路径 A：战斗结算

```
战斗系统 → 卡牌效果引擎.resolve(card, targets)
  ├→ [读] 卡牌系统 (模板) / 绑定系统 (加成) / 阵法系统 (光环)
  ├→ [写] 状态效果系统.apply(effect_config) ← 信号
  └→ [写] GSM (灵石/修为/灵材) ← 信号

战斗系统.end_battle(result)
  ├→ 资源系统: GSM.add("灵石", n)
  ├→ 修为养成系统: GSM.add("cultivation", n)
  ├→ 卡组编辑系统: 触发战利品三选一
  ├→ 探索系统: 标记节点完成
  ├→ 存档系统: 触发 autosave
  └→ HUD: GSM.player_changed 信号 → UI 刷新
```

### 路径 B：境界突破

```
修为养成.check_breakthrough()
  └→ cultivation >= max_cultivation

  1. GSM 设置 realm_changing_lock = true
     → 输入管理器 push_lock("transition")
  2. 渡劫突破系统.trigger() → 战斗系统 (渡劫战)
     → 成功 ↓  /  失败 → 修为扣除 10%，释放锁，结束
  3. [成功] 境界系统.advance_realm()
     → GSM.change_realm(new_level)  # 原子批量更新 8 个消费者
  4. GSM 设置 realm_changing_lock = false
     → HUD + 战斗UI: realm_changed 信号 → 刷新
     → 输入管理器 pop_lock("transition")
     → 存档系统: autosave
```

### 路径 C：存档/读档

```
存档: 场景管理器/战斗系统/主菜单 → 存档系统.save(slot)
  ├→ GSM.serialize() → Dictionary
  ├→ 包装 {version, timestamp, meta, game_state}
  ├→ 模式版本控制: schema_version = CURRENT
  ├→ FileAccess.store_string(JSON.stringify())
  │   ⚠️ 检查返回值 (4.4+ → bool)
  └→ 更新 meta.json

读档: 主菜单 → 存档系统.load(slot)
  ├→ FileAccess.get_file_as_string() → JSON.new().parse()
  ├→ 存档系统内部迁移链._migrate_if_needed(data)
  ├→ GSM.deserialize(data.game_state) → 逐域恢复
  ├→ CardSystem.reconstitute_instances(owned_cards_dicts) → 重构 CardInstance 对象
  └→ 场景管理器.request_scene_change("main_menu", data.current_scene)

跨局元进度: 境界突破/新卡/天赋/成就 → 存档系统.write_progression()
  ├→ 读取现有 → 合并 → 写入 progression.dat
  ├→ 写入前备份 → progression.dat.bak
  └→ 损坏 → 从零开始，提示用户
```

### 路径 D：初始化顺序

```
T+0: Autoload 注册: GSM → InputManager → SceneManager → SaveLoad → EventSystem
T+1: GSM._ready() → 空 GameState → 广播 gsm_initialized
T+2: SaveLoad._ready() → 检查 saves/ → 读 meta.json + progression.dat
T+3: 境界系统._ready() → 加载 realm_table
T+4: 卡牌系统._ready() → 加载 CardTemplate Resource → 筛选已解锁
T+5: 场景管理器 → 加载主菜单
```

---

## API 边界

### GSM 三层接口

| 层级 | 访问方式 | 适用场景 | 示例 |
|------|---------|---------|------|
| 1 | 直接属性读取 | 热路径（每帧读取） | `GSM.player.realm` |
| 2 | 原子写入操作 | 状态变更 | `GSM.apply_battle_rewards(...)` |
| 3 | 信号订阅 | UI 刷新、日志、成就检测 | `GSM.player_changed` |

**关键原子操作**：
- `GSM.apply_battle_rewards(lingshi, cultivation, cards)` → void
- `GSM.change_realm(new_level)` → void（8 个消费者批量更新 + lock 围栏）
- `GSM.add_resource(type, amount)` → bool

### 战斗系统阶段机

```
enum CombatPhase { PREPARATION=0, DRAW=1, PLAY=2, ATTACK_DEC=3, ATTACK_RES=4, ENEMY_TURN=5, END=6 }
advance_phase() → bool  # 每阶段结束检查前置条件，失败则报告错误
```

### 卡牌效果引擎

> **完整 API 规范见 `docs/decisions/ADR-0009-card-effect-engine-resource-refcounted-model.md`**
> 以下为架构摘要——签名可能已细化。以 ADR-0009 为准。

- 双层对象模型：EffectTemplate (Resource, `.tres`) + EffectInstance (RefCounted, 运行时) — 4 种子类：InstantEffect / PersistentEffect / TriggeredEffect / ReplacementEffect
- 栈式结算引擎：ResolutionStack — LIFO 出栈 + 中分辨率插入队列 + 5 级优先级排序
- 效果触发链硬限制：深度 10 层 + `Dictionary[int, bool]` 循环检测（GDScript 4.x 无 `Set` 类型）
- PRD 伪随机：5% 步进 + 怜悯保护 + `RandomNumberGenerator` 独立实例
- AI 评估接口：`evaluate_effect()` / `simulate_chain()` — `GameStateSnapshot` 不可变快照
- 信号路由（ADR-0007 Cat 2b）：`effect_registered` / `effect_removed` / `effect_suspended` / `effect_restored` / `stack_overflow_warning`
- OutcomeType 枚举：扩展 ADR-0003（EventSystem）—— +5 种效果专属类型（APPLY_STATUS, MODIFY_STAT, TRIGGER_CHAIN, ACTIVATE_FORMATION, MODIFY_COST）
- Feature 层 Autoload #10：`GSM(1) → InputManager(2) → SceneManager(3) → SaveLoad(4) → EventSystem(5) → CardSystem(6) → CostSystem(7) → StatusEffectSystem(8) → CombatSystem(9) → CardEffectEngine(10)`

### 输入管理器 ⚠️ 4.6 HIGH

> **完整 API 规范见 `docs/decisions/ADR-0004-input-manager-four-tier-lock-stack-dual-focus.md`**
> 以下为架构摘要——签名可能已细化。以 ADR-0005 为准。

```
四级锁栈 (严格度递增):
  dialogue  = 0    # 阻拦 GAMEPLAY，允许 DIALOGUE + UI_NAV
  animation = 1    # 阻拦 GAMEPLAY + DIALOGUE，允许 UI_NAV
  modal     = 2    # 阻拦非该弹窗的所有输入
  transition = 3   # 阻拦所有输入

is_input_allowed(action_type: ActionType, device: DeviceType) → bool
  # ActionType: ANY | UI_NAV | DIALOGUE | GAMEPLAY
  # DeviceType: MOUSE | KEYBOARD | GAMEPAD（位掩码可组合）
  # ⚠️ 4.6 双焦点独立判定——鼠标和键盘分别检查

push_lock(type: LockType, source: StringName, device_mask: int = DEVICE_ALL)
pop_lock(source: StringName)
  # 锁变更通过 GSM.set_input_locks() → batch_updated 信号传播
  # 取代原来的 input_lock_changed 专用信号

输入分发路径（Godot 4.6 事件派发顺序）:
  GAMEPLAY 键盘 → Input Map 动作轮询 (_process 中 is_action_just_pressed)
  UI_NAV 快捷键 → _input()（GUI 派发前拦截）
  鼠标交互      → _gui_input() / _input_event()
```

### 事件系统 — story_flags 所有权

- **EventSystem** = 唯一运行时写入者（通过 `GSM.set_narrative_flag()` —— ADR-0001 第二层新增方法）
- **剧情系统** = 通过 `EventSystem.set_flag()` 委托写入
- **对话系统** = `DialogueOutcome.set_flag → EventSystem.set_flag()` 委托
- **卡牌效果引擎** = `SET_FLAG 效果类型 → EventSystem.set_flag()` 委托
- **结局分支系统** = 只读（`EventSystem.get_flag()`）

### ADD_CARD 结果执行 — Foundation 层信号委托

- **EventSystem**（Foundation #5）→ 发射 `card_reward_requested(template_id)` 信号（fire-and-forget）
- **CardSystem**（Core 层）→ 监听信号 → `create_instance()` + `serialize_instance()` + `GSM.add_card_to_collection()`
- 此信号委托保持 Foundation 层原则 #3 合规——EventSystem 不直接依赖 Core 层系统

### 存档模式版本控制

- `CURRENT_SCHEMA_VERSION: int = 1`
- 迁移链: `migrate(data, from_ver, to_ver)` → 纯函数链式调用
- 失败: 备份为 `.bak`，记录到 `user://logs/migration.log`，通知用户
- 损坏 `progression.dat`: 从零开始，覆盖前提示

---

## ADR 审计

**现有 ADR**：30 个（ADR-0001 至 ADR-0030）。Foundation 层 5 个（GSM、存档、事件、输入、场景）为 **Accepted** ✅；Core 层 9 个（卡牌、信号通信、境界、状态效果、费用、阵营、资源、卡牌效果引擎、流派）、Feature 层 12 个（战斗、绑定、探索、上场阵位、AI、修为养成、渡劫、卡组编辑、开局身份、阵法、剧情、炼丹炼器）、叙事层 2 个（对话、结局分支——均非 Autoload）、Meta 层 1 个（跨局元进度）、经济层 1 个（法宝铭刻——非 Autoload）全部处于 **Proposed** 状态。

**Autoload 链**：25 个（超出 Godot 20 软上限 ⚠️）。ADR-0027（对话）、ADR-0028（炼丹炼器）、ADR-0029（结局分支）均采用 RefCounted 轻量模式——零 Autoload 扩容。

完整覆盖矩阵见 `docs/architecture/architecture-review-2026-07-25.md`。

---

## 必需的 ADR

### 编码前必须创建 (Foundation — BLOCKING)

| # | ADR | 覆盖 TR | 引擎风险 | 状态 |
|---|-----|---------|---------|------|
| 1 | 游戏状态管理器: Autoload 单例 + 三层 API | TR-gsm-001→003 | — | ✅ Proposed |
| 2 | 存档/读档: JSON 格式 + schema_version + 迁移链 | TR-save-001→003 | MEDIUM (FileAccess) | ✅ Proposed |
| 3 | 事件系统: story_flags 唯一运行时写入者 | TR-event-001→003 | — | ✅ Proposed |
| 4 | 输入管理器: 四级锁栈 + 双焦点 | TR-input-001,002 | HIGH (4.6) | ✅ Proposed |
| 5 | 场景管理器: 唯一场景转换仲裁者 | TR-scene-001,002 | — | ✅ Proposed |
| 6 | 卡牌数据模型: Template/Instance 分离 | TR-card-001,002 | HIGH (load_threaded) | ✅ Proposed |
| 7 | 信号驱动通信: GSM 信号 vs 直接调用 | TR-signal-001,002 (横切) | — | ✅ Proposed |

### 在相关系统构建前应拥有

| # | ADR | 覆盖 TR | 引擎风险 | 状态 |
|---|-----|---------|---------|------|
| 8 | 战斗系统: 7 阶段状态机 + 阶段验证 | TR-combat-001→003 | — | ✅ Proposed |
| 9 | 卡牌效果引擎: 效果栈 + 递归上限 + PRD | TR-effect-001→003 | HIGH (4.5 GDScript) | ✅ Proposed |
| 10 | 境界系统: 属性表 + 原子变更 | TR-realm-001→003 | LOW | ✅ Proposed |
| 11 | 状态效果生命周期: 叠加 + 免疫 + 倒计时 | TR-status-001,002 | LOW | ✅ Proposed |
| 15 | 费用系统: 内部状态管理 + 回合重置委托 | TR-cost-001 | LOW | ✅ Proposed |
| 19 | 资源系统: 公式服务 + GSM 数据存储分离 | TR-resource-001 | LOW | ✅ Proposed |
| 18 | 阵营系统: 标签库 + 实时遍历统计（Core 层） | TR-faction-001 | LOW | ✅ Proposed |
| 25 | 流派系统: 静态流派库 + 纯计算检测引擎（Core 层） | TR-school-001 | LOW | ✅ Proposed |

### 可推迟到实现阶段

| # | ADR | 覆盖 TR | 状态 |
|---|-----|---------|------|
| 12 | 跨局元进度: progression.dat 独立存储 | TR-progression-001,002 | ✅ Proposed |
| 13 | 绑定系统: 角色阵亡=绑卡洗回牌库 | TR-binding-001,002 | ✅ Proposed |
| 14 | 探索系统: 随机种子地图生成 + DAG | TR-explore-001→003 | ✅ Proposed |
| 16 | 上场阵位系统: 内部状态机 + GSM 快照 | TR-deploy-001,002 | ✅ Proposed |
| 17 | AI 系统: EnemyTemplate Resource + 效果引擎统一路径 | TR-ai-001,002 | ✅ Proposed |
| 20 | 修为养成系统: 统一 gain_cultivation() + 溢出池管理 | TR-cultivation-001 | ✅ Proposed |
| 21 | 渡劫突破系统: 编排器 + CombatSystem 配置复用 | TR-tribulation-001 | ✅ Proposed |
| 22 | 开局身份系统: const 模板 + 服务编排写入 | TR-identity-001 | ✅ Proposed |
| 23 | 卡组编辑系统: GSM deck 域 + 公式委托 | TR-deck-edit-001 | ✅ Proposed |
| 24 | 阵法系统: 4 级光环作用域 + AuraScope 枚举 | TR-formation-001 | ✅ Proposed |
| 26 | 剧情系统: GSM-primary + EventSystem 委托写入 | TR-story-001 | ✅ Proposed |
| 27 | 对话系统: RefCounted 服务类 + JSON 按需加载（零 Autoload） | TR-dialogue-001 | ✅ Proposed |
| 28 | 炼丹炼器系统: RefCounted 工具类 + PRD 独立 RNG（零 Autoload） | TR-alchemy-001 | ✅ Proposed |
| 29 | 结局分支系统: EndingEvaluator 嵌入 StorySystem（零 Autoload） | TR-ending-001 | ✅ Proposed |

### 所有系统已覆盖 ✅

36 个 GDD 系统中已有 29 个通过 ADR 决策。剩余 7 个为 Presentation 层 UI 系统（战斗UI/探索UI/卡组编辑UI/HUD/主菜单/音频/成就）和法宝铭刻系统——这些属于 UI 实现层或小型功能，可在编码阶段直接决策，不阻塞开发。

---

## 架构原则

1. **GSM 是真理的单一来源**——所有游戏状态通过 GSM API 访问。没有系统持有一份拷贝。没有系统绕过 GSM 直接修改另一个系统的数据。

   > **例外（ADR-0011、ADR-0013、ADR-0016、ADR-0024）**：战斗中活跃状态实例由 StatusEffectSystem Autoload 内部管理（`_instances` / `_by_target` 注册表）——不通过 GSM 实时存储。战斗中绑定数据由 BindingManager Autoload 内部管理（`_bindings` / `_by_character` / `_card_to_character` 注册表）——不通过 GSM 实时存储。战斗中阵位数据和角色在场状态由 DeploymentSystem 内部管理（`_field` Dictionary）——不通过 GSM 实时存储。原因：状态叠加/倒计时/免疫检查、绑定槽位查找和前后排保护查询（`is_targetable()`）是战斗热路径（每帧 O(1) 查询需求 + RefCounted/Dictionary 对象引用而非序列化 Dictionary）。战斗结束时通过 `serialize_all() → Array[Dictionary]` 导出状态快照、绑定快照和阵位快照至 GSM 用于存档。

2. **信号用于通知，不是用于逻辑**——信号是只读的 UI 刷新钩子。游戏逻辑通过原子 GSM 操作完成，在信号发出前数据已一致。

3. **Foundation 层不依赖任何游戏系统**——Foundation 系统（GSM、存档、事件、输入、场景、迁移）的初始化不假设任何 Feature 系统存在。

4. **境界是横切上下文，不是依赖图中的一个节点**——它被 10 个系统读取但仅被一个系统写入。它是配置数据 + 一个原子变更操作，不是运行时编排器。

5. **效果引擎是契约执行者，不是游戏设计师**——它不判断效果是否"平衡"。它解析定义好的效果类型，在栈中串行结算，达到递归上限时截断并报告。仅此而已。

---

## 待解决问题

| ID | 摘要 | 优先级 | 解决路径 |
|----|------|--------|---------|
| OQ-01 | 卡牌效果引擎中每个效果类型的具体读写契约（以 10 张代表性卡牌为例） | Medium | 在编码前于 `contracts.md` 中定义 |
| OQ-02 | Godot 4.6 双焦点系统在自定义 Control 组件上的实际行为——需要在目标硬件上测试 | High | ADR-0004 (输入管理器) 中标记，实现时验证 |
| OQ-03 | `progression.dat` 和 Steam Cloud Save 之间的同步策略 | Low | 发布前处理——单人游戏，不阻塞开发 |
| OQ-04 | 卡牌模板异步加载策略（222 个 Resource 文件，需防止启动卡顿）| Medium | ADR-0006 中建议使用 `ResourceLoader.load_threaded_request()` |
| OQ-05 | 卡牌效果引擎与事件系统的 `Outcome` 类型是否应统一为共享词汇表 | Low | ADR-0003 + ADR-0009 中协调 |
| OQ-06 | 语义门控的命名应避免误导——"锁"应改为 "guard" 或 "barrier"（GDScript 是单线程，无真正竟态条件）| Low | ADR-0007 中统一术语 |