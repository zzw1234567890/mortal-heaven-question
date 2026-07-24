# 仙途问道 — 主架构文档 (Master Architecture)

## 文档状态

- **版本 (Version)**：1.0
- **最后更新 (Last Updated)**：2026-07-24
- **引擎 (Engine)**：Godot 4.6
- **覆盖的 GDD (GDDs Covered)**：36 个系统（见 design/gdd/systems-index.md）
- **引用的 ADR (ADRs Referenced)**：尚无——所有 ADR 待创建（见 §Required ADRs）
- **技术总监签署 (TD Sign-Off)**：2026-07-24 — APPROVED WITH CONDITIONS（5 个 CONCERNS 将在对应 ADR 中处理）
- **主程序员可行性 (LP Feasibility)**：FEASIBLE with 5 CONCERNS（无 BLOCKING 项）
  - C1：境界系统层归属不一致 → ADR-0010 中解决
  - C2：初始化序列与架构原则 #3 矛盾 → ADR Milestone 中解决
  - C3：效果栈结算顺序未指定 → ADR-0009 中规定
  - C4：信号粒度未定义 → ADR-0007 中规定
  - C5：`Outcome` 类型可能重复 → 跨 ADR 统一

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
│  FEATURE 层 (22 系统)                                        │
│  战斗 / 卡牌效果引擎 / 上场阵位 / 绑定 / 阵法 / 阵营 /       │
│  AI / 探索 / 修为养成 / 境界 / 渡劫 / 资源 / 卡组编辑 /      │
│  炼丹 / 铭刻 / 开局身份 / 流派 / 轮回天赋 / 成就 /           │
│  剧情 / 对话 / 结局分支                                      │
├──────────────────────────────────────────────────────────────┤
│  CORE 层 (4 系统)                                            │
│  卡牌系统 / 费用系统 / 行动力系统 / 状态效果系统              │
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
| **费用系统** | 每回合费用值 | `get_current_cost()` / `spend(n)` / `reset_for_turn()` | 境界系统 | — |
| **行动力系统** | `action_points` 值 | `get_ap()` / `spend_ap(n)` / `restore_ap(n)` | 游戏状态管理器、境界系统 | — |
| **状态效果系统** | 所有 `StatusEffect` 实例 | `apply(config)` / `remove(id)` / `get_active(target)` / `tick_all()` | 卡牌效果引擎 | `Object` (实例管理) |

### FEATURE 层

#### 战斗子系统

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **战斗系统** | `CombatTurn`、7 阶段状态机 | `start_battle(enemy)` / `end_battle(result)` | 9 个子系统 (费用/卡牌/AI/效果引擎/状态/上场/绑定/阵法/境界) | `SceneTree` |
| **卡牌效果引擎** | 效果解析栈、效果类型注册表 | `resolve(card, target)` / `register_effect(type, handler)` | 7 个系统 (卡牌/绑定/状态/阵法/阵营/费用/GSM) | `Object` (动态类型) |
| **上场阵位系统** | `CharacterDeployment` | `deploy(card, slot)` / `withdraw(slot)` / `get_field()` | 战斗系统、境界系统、卡牌系统 | — |
| **绑定系统** | `BindingRelationship` | `bind(character, item)` / `unbind(slot)` / `get_bindings(character)` | 战斗系统、卡牌系统、上场阵位系统 | — |
| **阵法系统** | `FormationAura` | `deploy_formation(card, slots)` / `get_aura()` | 战斗系统、上场阵位系统、阵营系统 | — |
| **阵营系统** | 阵营定义表 | `get_faction(card)` / `check_synergy(f1, f2)` | 卡牌系统 | — |
| **AI 系统** | 行为树/状态机 | `get_next_action(enemy, field)` / `evaluate_threat(target)` | 战斗系统、卡牌效果引擎、卡牌系统 | — |

#### 探索与经济子系统

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **探索系统** | 地图布局、节点状态 | `generate_map(seed)` / `move_to_node(id)` / `resolve_node(id)` | 事件/行动力/GSM/境界/资源 共 5 系统 | `RandomNumberGenerator` |
| **修为养成系统** | `cultivation` 值、溢出池 | `add_cultivation(n)` / `get_progress()` / `check_breakthrough()` | GSM、境界系统 | — |
| **境界系统** | `RealmLevel`、属性表 | `get_realm(level)` / `get_property(level, key)` / `get_next_realm()` | 修为养成系统 | — |
| **境界压制规则** | 压制系数计算 | `get_suppression(attacker_realm, defender_realm)` | 境界系统、战斗系统 | — |
| **渡劫突破系统** | 渡劫流程、天劫参数 | `trigger_tribulation()` / `get_tribulation_difficulty(realm)` | 境界系统、战斗系统、修为养成系统 | — |
| **资源系统** | 灵石/灵材/丹药碎片 | `get_resource(type)` / `add(type, n)` / `spend(type, n)` | 卡牌/探索/GSM | — |
| **卡组编辑系统** | `Deck`、卡组验证器 | `add_to_deck(card)` / `remove_from_deck(card)` / `validate_deck()` | 卡牌/GSM/资源 | — |
| **炼丹炼器系统** | 配方表、制造流程 | `craft(recipe, materials)` / `get_recipes()` | 资源/卡牌/GSM | — |
| **法宝铭刻系统** | 铭刻属性、铭刻配方 | `inscribe(item, inscription)` / `get_inscriptions(item)` | 炼丹炼器/资源/境界 | — |
| **开局身份系统** | 身份模板、初始卡组 | `select_identity(id)` / `get_starting_deck(id)` | GSM/卡牌/卡组编辑 | — |

#### 成长与元进度子系统

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **流派系统** | 流派定义、流派等级 | `get_school(card)` / `get_bonus(school, level)` | 阵营/卡牌/阵法 | — |
| **轮回天赋系统** | `PlayerTalents`、天赋树、轮回结算 | `unlock_talent(id)` / `get_active_talents()` / `settle_run(gsm)` | 存档系统、开局身份 | — |
| **成就系统** | `Achievement` 实例、解锁状态 | `check(criteria)` / `get_achievements()` | 存档系统、GSM | — |

#### 叙事子系统

| 模块 | 拥有 | 暴露 | 消费 | 引擎 API |
|------|------|------|------|---------|
| **剧情系统** | `ChapterState`、章节序列 | `get_current_chapter()` / `advance_chapter()` | 探索/境界/事件系统 | — |
| **对话系统** | 对话树、角色对话资源 | `start_dialogue(id)` / `select_option(opt)` | 剧情/事件/GSM | — |
| **结局分支系统** | 结局条件映射 | `evaluate_ending()` / `get_endings_by_flag(flags)` | 剧情系统、GSM (只读) | — |

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

- 效果类型注册：`register_effect(type, handler: Callable, config = {})` (4.5 可变参数)
- 效果栈：串行出栈，最大递归深度 16
- PRD 伪随机：每次失败提高下次成功概率，短序列内接近标示概率

### 输入管理器 ⚠️ 4.6 HIGH

```
四级锁栈 (严格度递增):
  dialogue  = 0    # 阻拦 GAMEPLAY，允许 DIALOGUE + UI_NAV
  animation = 1    # 阻拦 GAMEPLAY + DIALOGUE，允许 UI_NAV
  modal     = 2    # 阻拦非该弹窗的所有输入
  transition = 3   # 阻拦所有输入

is_input_allowed(action_type: ANY|UI_NAV|GAMEPLAY|DIALOGUE) → bool
push_lock(type) / pop_lock(type)
信号: input_lock_changed(lock_type, is_locked)
```

### 事件系统 — story_flags 所有权

- **事件系统** = 唯一运行时写入者（`set_flag` 方法）
- **剧情系统** = 通过 `advance_chapter()` 委托事件系统写入
- **对话系统** = `DialogueOutcome.set_flag → EventSystem.set_flag()` 委托
- **结局分支系统** = 只读（聚合标记，不写入）

### 存档模式版本控制

- `CURRENT_SCHEMA_VERSION: int = 1`
- 迁移链: `migrate(data, from_ver, to_ver)` → 纯函数链式调用
- 失败: 备份为 `.bak`，记录到 `user://logs/migration.log`，通知用户
- 损坏 `progression.dat`: 从零开始，覆盖前提示

---

## ADR 审计

**现有 ADR**：无。所有 50 个技术需求 (TR) 无 ADR 覆盖——0 覆盖，50 缺口。

---

## 必需的 ADR

### 编码前必须创建 (Foundation — BLOCKING)

| # | ADR | 覆盖 TR | 引擎风险 |
|---|-----|---------|---------|
| 1 | 游戏状态管理器: Autoload 单例 + 三层 API | TR-gsm-001→003 | — |
| 2 | 存档/读档: JSON 格式 + schema_version + 迁移链 | TR-save-001→003, TR-migrate-001,002 | MEDIUM (FileAccess) |
| 3 | 事件系统: story_flags 唯一运行时写入者 | TR-event-001→003 | — |
| 4 | 输入管理器: 四级锁栈 + 双焦点 | TR-input-001,002 | HIGH (4.6) |
| 5 | 场景管理器: 唯一场景转换仲裁者 | TR-scene-001,002 | — |
| 6 | 卡牌数据模型: Template/Instance 分离 | TR-card-001,002 | — |
| 7 | 信号驱动通信: GSM 信号 vs 直接调用 | TR-gsm-002, TR-hud-001 (横切) | — |

### 在相关系统构建前应拥有

| # | ADR | 覆盖 TR | 引擎风险 |
|---|-----|---------|---------|
| 8 | 战斗系统: 7 阶段状态机 + 阶段验证 | TR-combat-001→003 | — |
| 9 | 卡牌效果引擎: 效果栈 + 递归上限 + PRD | TR-effect-001→003 | HIGH (4.5 GDScript) |
| 10 | 境界系统: 属性表 + 原子变更 | TR-realm-001→003 | — |
| 11 | 状态效果生命周期: 叠加 + 免疫 + 倒计时 | TR-status-001,002 | — |

### 可推迟到实现阶段

| # | ADR | 覆盖 TR |
|---|-----|---------|
| 12 | 跨局元进度: progression.dat 独立存储 | TR-save-003, TR-reincarnate-002 |
| 13 | 绑定系统: 角色阵亡=绑卡永久失去 | TR-bind-001 |
| 14 | 探索系统: 随机种子地图生成 | TR-explore-001 |

---

## 架构原则

1. **GSM 是真理的单一来源**——所有游戏状态通过 GSM API 访问。没有系统持有一份拷贝。没有系统绕过 GSM 直接修改另一个系统的数据。

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