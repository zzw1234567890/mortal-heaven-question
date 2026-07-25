# ADR-0013：绑定系统 — BindingManager Autoload + RefCounted BindingRecord 实例模型 + 效果引擎集成

## 状态
Proposed

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Binding |
| **知识风险** | LOW（Dictionary 操作、信号系统、Autoload 模式、RefCounted 实例管理均为 4.x 成熟 API。不依赖 4.4+ 新特性） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | None——核心逻辑不依赖 4.4+ 新增 API。`Dictionary` 键查找、`signal` 发射、`RefCounted` 子类均为 4.0+ 稳定 API |
| **需要验证** | `RefCounted` 子类在 200+ BindingRecord 实例/战斗下的引用计数开销（化神期上限 36 绑定位 + 多角色叠加——峰值约 36×5=180 实例）；`get_accumulated_bonus()` 每帧调用（CombatUI 更新 ATK/DEF 显示）需 <0.01ms；`get_bindings_by_character()` 每次调用分配新 Array[BindingRecord]（CombatUI 不应每帧调用此方法——改用 `get_binding_ids_by_character()` 返回 int 数组避免分配）；`serialize_all()` 在 battle_end 时的性能（序列化全部 BindingRecord → Dictionary）；同名叠加 `stack_slots` 数组在覆盖操作时的正确性（GUT 测试覆盖全部叠加/覆盖/阵亡路径） |
| **已验证的引擎风险** | **H1（已处理）**：`get_bindings_by_character()` 返回 `Array[BindingRecord]` 每帧分配新数组——CombatUI 热路径内存波动。**缓解**：新增 `get_binding_ids_by_character() → Array[int]` 零分配查询（CombatUI 按需逐条获取 BindingRecord）。**H2（已处理）**：Autoload `_ready()` 信号时序——遵循 ADR-0012 模式，BindingManager._ready() 通过直接方法调用查询上游系统（GSM/RealmSystem），不 await 已发射的信号。**H3（已处理）**：`_bindings` Dictionary 值 → `Array[BindingRecord]` 附加运行时 `is BindingRecord` assert 守卫。详见 §引擎专家审查追踪 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`player.realm_level` 只读查询获取当前境界以确定绑定位上限；`battle.*` 域在战斗结束时接收绑定快照）；ADR-0002（CardSystem——功法/法宝卡牌模板查询 `get_template(id)`；`create_instance()` 创建卡牌实例）；ADR-0007（三分类信号体系——绑定生命周期事件归类为 Cat 2b 系统信号）；ADR-0008（CombatSystem——Phase 2 PLAY 阶段触发绑定流程；角色阵亡/离场/上场事件驱动绑定生命周期）；ADR-0009（CardEffectEngine——`register_persistent_effect()` / `remove_effects_by_source()` / `suspend_effects_by_source()` / `restore_effects_by_source()` 效果生命周期接口）；ADR-0010（RealmSystem——`get_realm_property(level, "gongfa_slots"/"fabao_slots"/"deploy_count")` 查询绑定位上限随境界成长）；ADR-0011（StatusEffectSystem——Template/Instance 分离模式先例；战斗热路径 O(1) 查询先例；GSM 例外模式先例——战斗期间数据在子系统内部管理） |
| **启用** | 前向引用：CombatUI（尚无独立 ADR——订阅绑定生命周期 Cat 2b 信号更新角色绑定状态图标、本命标记、叠加层数徽章、hover tooltip）；前向引用：AI 系统（尚无独立 ADR——查询敌方绑定状态 `get_bindings_by_character()` 评估威胁值）；前向引用：阵法系统（尚无独立 ADR——绑定状态变更通知重查阵法激活条件） |
| **阻塞** | 绑定 Epic（功法/法宝卡牌的绑定、覆盖、叠加、阵亡洗回全部流程）；战斗 Epic（Phase 2 出牌阶段的功法/法宝绑定交互——角色选择面板、覆盖确认 UI、叠加动画）；卡牌效果 Epic（效果引擎的 register_persistent_effect / remove / suspend / restore 接口依赖 BindingManager 提供绑定上下文） |
| **排序说明** | Feature 层——在 Foundation 层全部 7 个 ADR + Feature 层 ADR-0008（CombatSystem）、ADR-0009（CardEffectEngine）、ADR-0010（RealmSystem）、ADR-0011（StatusEffectSystem）被接受后编写。Autoload 初始化顺序：BindingManager 为 Autoload #13（完整链 13 个：GSM #1 / InputManager #2 / SceneManager #3 / SaveLoad #4 / EventSystem #5 / CardSystem #6 / CostSystem #7 / StatusEffectSystem #8 / CombatSystem #9 / CardEffectEngine #10 / RealmSystem #11 / ProgressionSystem #12 / BindingManager #13）。BindingManager._ready() 执行时 #1-#11 已完全初始化。遵循 ADR-0012 模式——BindingManager._ready() 通过直接方法调用查询上游系统（GSM.player.realm_level、RealmSystem.get_realm_property()），不 await 可能已发射的信号（Godot 信号同步发射不重放——Autoload #13 连接 #1 在 `_ready()` 中发射的信号时，信号早已发射完毕） |

## 上下文

### 问题陈述

`binding-system.md` GDD 定义了完整的功法/法宝绑定系统——BindingRecord 数据结构、绑定位随境界成长、5 种绑定位状态转换、同名卡叠加乘法公式、本命绑定自动判定规则、覆盖流程（含 0.8s 反悔窗口）、角色离场暂挂/重新上场恢复、角色阵亡洗回牌库、涅槃丹复活空载等完整生命周期。但 GDD 关注的是"绑定应该表现出什么行为"，本 ADR 需要解决的是"绑定系统如何在 Godot 4.6 中工程化实现"：

1. **数据模型选择**（GDD 开放问题 #1）：BindingRecord 使用 Godot Resource vs 纯 RefCounted vs 纯 Dictionary。GDD 明确倾向 BindingManager Autoload + Dictionary 注册表，需在架构层面确认具体对象模型
2. **运行时存储位置**：活跃绑定实例存储在 BindingManager Autoload 内部 vs GSM `battle.bindings` 域。GDD 已定义 BindingManager 持有全局绑定注册表（`card_instance_id → character_id` 映射 + 角色持有 BindingSlots），但架构层面需确认与 GSM 的边界——与 ADR-0011 StatusEffectSystem 相同的设计问题
3. **效果引擎集成**：绑定卡的效果注册/移除/暂挂/恢复通过 CardEffectEngine 的哪个接口？GDD §与其他系统的交互 列出了 `register_persistent_effect` / `remove_effects_by_source` / `suspend` / `restore`，与 ADR-0009 定义的接口一致——需确认调用方向和责任边界
4. **信号 vs 直接调用**：绑定生命周期事件（绑定成功、覆盖、解绑、叠加、本命激活、暂挂、恢复）使用什么信号策略？GDD 未明确指定——需与 ADR-0007 三分类体系对齐
5. **同名叠加的架构实现**：多张同名卡共享一个绑定位、乘法叠加公式、stack_count 递增——这些逻辑在 BindingManager 内部实现 vs 部分委托给 CardEffectEngine

`architecture.md` 将 BindingSystem 归入 Feature 层——依赖 CardSystem、CombatSystem、CardEffectEngine、RealmSystem。

### 约束

- **Feature 层定位**：BindingManager 是 Feature 层 Autoload——依赖 Foundation 层（GSM、CardSystem）和 Feature 层（CombatSystem、CardEffectEngine、RealmSystem），被 Presentation 层（CombatUI、HUD）消费
- **RefCounted 实例模型**：BindingRecord 使用 RefCounted（非 Resource、非纯 Dictionary）——对齐 ADR-0002 CardInstance / ADR-0009 EffectInstance / ADR-0011 StatusInstance 的 Template/Instance 分离模式。BindingRecord 为运行时实例，卡牌模板数据（native_owner、stack_limit）来自 CardSystem 查询
- **绑定位随境界成长**：绑定位数量由 RealmSystem 提供——`RealmSystem.get_realm_property(level, "gongfa_slots")` / `"fabao_slots"`。绑定系统不自行维护境界→槽位映射
- **战斗热路径 O(1) 查询**：`get_binding_ids_by_character(character_id)` (零分配 Array[int]) 和 `get_character_by_card(card_instance_id)` 必须 O(1)——Dictionary 键查找。`get_bindings_by_character()` 每次调用分配新 Array[BindingRecord]——CombatUI 不应每帧调用此方法，改用 `get_binding_ids_by_character()` + `get_binding()` 按需获取
- **同名叠加共享槽位**：多张同名功法/法宝绑定到同一角色时，共享一个绑定位（`slot_index` 不变，`stack_count` 递增）——不额外消耗槽位
- **本命绑定不可逆**：本命绑定由卡牌 `native_owner` 自动判定，在该角色的本次生命周期内不可变更（除非覆盖——旧本命卡进弃牌堆，新卡可重新占用本命位）
- **覆盖保留积累数值**：被覆盖的旧卡已积累的数值加成（`Character.accumulated_bonuses`）保留在角色上——仅持续触发效果停止
- **角色阵亡→绑定卡洗回牌库**：所有绑定卡（含所有叠加实例）洗回牌库（非弃牌堆、非永久失去）——符合 card-system.md §D.4"角色与绑定卡的生死契约"
- **暂挂/恢复**：角色离场→绑定效果暂挂（is_suspended=true）；角色重新上场→验证 card_instance_id 仍存在于收藏池→恢复效果。绑定来源的状态由 BindingManager 独立处理（与 ADR-0011 StatusEffectSystem 的 suspend/restore 并行——两者操作不同来源的效果）
- **帧预算**：`bind_card()` 单次调用（含本命判定+槽位分配+效果注册）<0.5ms；`get_bindings_by_character()` O(1) Dictionary 查询 <0.001ms；`get_accumulated_bonus()` 遍历角色所有绑定卡 <0.01ms（最多 6 张/角色）
- **Autoload 计数**：BindingManager 为 Autoload #13——项目 Autoload 总数 13 个（GSM #1 → InputManager #2 → SceneManager #3 → SaveLoad #4 → EventSystem #5 → CardSystem #6 → CostSystem #7 → StatusEffectSystem #8 → CombatSystem #9 → CardEffectEngine #10 → RealmSystem #11 → ProgressionSystem #12 → BindingManager #13）

### 需求

- RefCounted BindingRecord 数据结构：包含 binding_id、card_instance_id、card_template_id、slot_type、slot_index、bound_character_id、is_native、native_multiplier、activated_turn、is_suspended、stack_slots、stack_count——与 GDD §详细设计 §1 完全对齐
- BindingManager Autoload 内部运行时注册表：`_bindings: Dictionary[int, BindingRecord]`（key=binding_id）+ `_by_character: Dictionary[int, Array[int]]`（key=character_id → binding_id 列表，快速查询某角色的所有绑定）+ `_card_to_character: Dictionary[int, int]`（key=card_instance_id → character_id，O(1) 反向查询）。三个索引结构必须在添加/移除绑定时保持同步——`bind_card()` / `remove_binding()` 中原子更新；Dictionary[int, BindingRecord] 键类型提示在 GDScript 中非编译器强制——在 `_bindings[id]` 访问处附加 `assert(_bindings[id] is BindingRecord)` 守卫
- 公共 API：`bind_card()` / `overwrite_binding()` / `stack_card()` / `remove_binding()` / `remove_all_bindings()` / `suspend_bindings()` / `restore_bindings()` / `get_bindings_by_character()` / `get_binding_ids_by_character()` / `get_character_by_card()` / `get_accumulated_bonus()` / `serialize_all()` / `deserialize_all()`
- 本命判定逻辑：卡牌 `native_owner` 前缀匹配目标角色 card_id → 检查该角色同类型本命位是否未被占用 → 自动设置 is_native + native_multiplier
- 同名叠加判定：目标角色已绑定同名卡 + stack_count < cardTemplate.stack_limit → 叠加（stack_count += 1，共享槽位，乘法叠加）
- 绑定位上限查询：`RealmSystem.get_realm_property(level, "gongfa_slots")` / `"fabao_slots"` —— 战斗开始时缓存到 BindingManager 本地
- 卡牌效果引擎集成：绑定成功时调用 `CardEffectEngine.register_persistent_effect()`；覆盖/阵亡时调用 `remove_effects_by_source()`；离场/上场时调用 `suspend_effects_by_source()` / `restore_effects_by_source()`
- Cat 2b 信号：`binding_applied` / `binding_removed` / `binding_overwritten` / `binding_stacked` / `binding_suspended` / `binding_restored` / `native_activated`（由 BindingManager Autoload 直接发射，通过 ADR-0007 `_emit_signal_safe` 包装器路由以追踪信号链深度）
- 角色阵亡处理：全部绑定卡洗回牌库（通过 CardSystem 接口）→ 清除 BindingManager 中该角色所有条目 → 通知效果引擎 remove_effects_by_source

## 决策

**BindingManager 实现为 Feature 层 Autoload（BindingManager），采用 RefCounted 实例模型——BindingRecord 管理运行时绑定状态。运行时实例存储在 BindingManager 内部 Dictionary 注册表中（`_bindings` + `_by_character` + `_card_to_character`），而非 GSM。战斗热路径 O(1) 查询。战斗结束时 `serialize_all()` 导出快照至 `GSM.battle.bindings`。绑定生命周期事件通过专用 Cat 2b 信号总线（binding_applied/removed/overwritten/stacked/suspended/restored/native_activated）通知 CombatUI。CombatSystem 通过直接方法调用编排绑定操作。CardEffectEngine 的 persistent effect 接口（register/remove/suspend/restore）由 BindingManager 在绑定生命周期各节点调用。**

### 对象模型

```
┌──────────────────────────────────────────────────────────────────┐
│                    BindingManager 对象模型                        │
│                                                                   │
│  ┌─────────────────────┐          ┌──────────────────────────┐  │
│  │  CardTemplate       │  查询    │  BindingRecord (运行时)    │  │
│  │  (Resource, .tres)  │────────→ │  (RefCounted, 轻量级)    │  │
│  │  (ADR-0002)         │  native  │                          │  │
│  │                     │  _owner  │  binding_id: int          │  │
│  │  native_owner       │  stack   │  card_instance_id: int    │  │
│  │  stack_limit        │  _limit  │  card_template_id: String │  │
│  │  rarity             │          │  slot_type: BindingSlot   │  │
│  └─────────────────────┘          │  slot_index: int          │  │
│                                    │  bound_character_id: int  │  │
│  ┌─────────────────────┐          │  is_native: bool          │  │
│  │  RealmSystem        │  查询    │  native_multiplier: float │  │
│  │  (ADR-0010)         │────────→ │  activated_turn: int      │  │
│  │                     │  槽位    │  is_suspended: bool       │  │
│  │  gongfa_slots       │  上限    │  stack_slots: Array[int]  │  │
│  │  fabao_slots        │          │  stack_count: int         │  │
│  └─────────────────────┘          └──────────────────────────┘  │
│                                                                   │
│  内部注册表（战斗期间——不通过 GSM 存储）：                        │
│    _bindings: Dictionary[int, BindingRecord]                     │
│    _by_character: Dictionary[int, Array[int]]                    │
│    _card_to_character: Dictionary[int, int]                      │
│                                                                   │
│  战斗结束：serialize_all() → GSM.battle.bindings（快照）          │
└──────────────────────────────────────────────────────────────────┘
```

### 绑定生命周期状态机

```
                    ┌──────────┐
                    │  手牌    │
                    └────┬─────┘
                         │ 打出功法/法宝卡 + 选择目标角色
                         ▼
              ┌──────────────────────┐
              │  绑定判定             │
              │  ├─ 同名已绑定且未达  │
              │  │  上限 → 叠加分支   │
              │  ├─ 有空位 → 新绑分支 │
              │  └─ 无空位 → 覆盖分支 │
              └──┬───────┬───────────┘
                 │       │             
        ┌────────┘       └────────┐    
        ▼                         ▼    
  ┌──────────┐            ┌──────────────┐
  │ 叠加绑定 │            │ 新绑/覆盖绑定 │
  │ stack++  │            │ 分配/复用槽位 │
  │ 共享槽位 │            │ 本命判定      │
  └────┬─────┘            └──────┬───────┘
       │                         │
       └────────┬────────────────┘
                ▼
     ┌─────────────────────┐
     │  已绑定（场上）      │ ◄── BindingRecord 注册到 BindingManager
     │  - 效果注册到引擎    │     CardEffectEngine.register_persistent_effect()
     │  - Cat 2b 信号发射   │
     └──┬──────┬──────┬────┘
        │      │      │
        ▼      ▼      ▼
   ┌────────┐ ┌──────┐ ┌──────────┐
   │ 角色   │ │ 角色 │ │ 被覆盖    │
   │ 离场   │ │ 阵亡 │ │ (单层)    │
   └───┬────┘ └──┬───┘ └────┬─────┘
       │         │          │
       ▼         ▼          ▼
   ┌──────┐ ┌──────┐  ┌──────────┐
   │ 暂挂 │ │洗回  │  │ 弃牌堆    │
   │suspend│ │牌库  │  │(stack--) │
   └──┬───┘ └──────┘  └──────────┘
      │
      ▼
   ┌──────────┐
   │ 重新上场 │
   │ 验证 card │
   │ _instance │
   │ _id 存在  │
   └────┬─────┘
        │ 存在 → 恢复效果
        │ 不存在 → 删除 BindingRecord
        ▼
   ┌─────────────┐
   │ 已绑定（场上）│
   └─────────────┘
```

### 关键接口

#### BindingManager 公共 API

| 方法 | 签名 | 说明 |
|------|------|------|
| `bind_card` | `bind_card(card_instance_id: int, template_id: StringName, character_id: int, slot_type: BindingSlot) → BindResult` | 新绑定到空位。BindResult = {success: bool, binding_id: int, reason: String}。reason: 'bound' / 'slot_full' / 'invalid_character' / 'card_already_bound' |
| `stack_card` | `stack_card(card_instance_id: int, template_id: StringName, character_id: int) → StackResult` | 同名叠加。StackResult = {stacked: bool, stack_count: int, reason: String}。reason: 'stacked' / 'stack_limit_reached' / 'no_existing_binding' |
| `overwrite_binding` | `overwrite_binding(card_instance_id: int, template_id: StringName, character_id: int, slot_index: int) → BindResult` | 覆盖已有绑定位 |
| `remove_binding` | `remove_binding(binding_id: int) → void` | 移除单个绑定（覆盖流程内部调用） |
| `remove_all_bindings` | `remove_all_bindings(character_id: int) → Array[Dictionary]` | 角色阵亡时调用——返回序列化后的绑定数据供 CardSystem 洗回牌库 |
| `suspend_bindings` | `suspend_bindings(character_id: int) → void` | 角色离场——所有 BindingRecord.is_suspended = true |
| `restore_bindings` | `restore_bindings(character_id: int) → void` | 角色重新上场——验证 card_instance_id 后恢复 |
| `get_bindings_by_character` | `get_bindings_by_character(character_id: int) → Array[BindingRecord]` | Dictionary 键 O(1) + 构造 Array[BindingRecord]（O(k) 遍历+分配）。**注意**：每次调用分配新数组——CombatUI 不应每帧调用。热路径改用 `get_binding_ids_by_character()` 返回 int 数组（零分配）后按需逐条获取 BindingRecord |
| `get_binding_ids_by_character` | `get_binding_ids_by_character(character_id: int) → Array[int]` | 零分配查询——返回 binding_id 列表。CombatUI 每帧调用此方法后按需调用 `get_binding(binding_id)` 获取单个 BindingRecord |
| `get_binding` | `get_binding(binding_id: int) → BindingRecord` | O(1) Dictionary 查找单个 BindingRecord——CombatUI 按需获取详情 |
| `get_character_by_card` | `get_character_by_card(card_instance_id: int) → int` | O(1) 反向查询——CardSystem 查询某卡绑在谁身上 |
| `get_accumulated_bonus` | `get_accumulated_bonus(character_id: int, stat_name: String) → float` | 遍历角色所有绑定卡的数值加成累加——CombatSystem 伤害计算时调用 |
| `can_bind` | `can_bind(character_id: int, slot_type: BindingSlot, template_id: StringName) → CanBindResult` | 绑定前预检查——UI 用于着色角色选择面板。CanBindResult = {can_bind: bool, can_stack: bool, must_overwrite: bool, slot_index: int, reason: String} |
| `serialize_all` | `serialize_all() → Dictionary` | 战斗结束时序列化全部活跃绑定 → GSM.battle.bindings |
| `deserialize_all` | `deserialize_all(data: Dictionary) → void` | 从快照恢复（读档/战斗快照恢复） |

#### CardEffectEngine 集成点

BindingManager 在以下时机调用 CardEffectEngine：

| 时机 | 调用 | 说明 |
|------|------|------|
| 绑定成功 | `CardEffectEngine.register_persistent_effect(card_instance_id, template_id, character_id, context: BindingContext)` | 注册功法/法宝的持续效果。BindingContext 包含 native_multiplier 和 stack_count |
| 覆盖旧卡 | `CardEffectEngine.remove_effects_by_source(old_card_instance_id)` | 先移除旧卡效果 |
| 覆盖新卡 | `CardEffectEngine.register_persistent_effect(new_card_instance_id, ...)` | 再注册新卡效果——严格顺序 |
| 角色离场 | `CardEffectEngine.suspend_effects_by_source(all_binding_card_ids)` | 暂挂所有绑定卡效果 |
| 角色上场 | `CardEffectEngine.restore_effects_by_source(valid_binding_card_ids)` | 恢复验证通过的绑定卡效果 |
| 角色阵亡 | `CardEffectEngine.remove_effects_by_source(all_binding_card_ids)` | 移除所有绑定卡效果（含所有叠层） |

#### Cat 2b 信号（通过 `_emit_signal_safe` 路由）

| 信号 | 参数 | 触发时机 | 订阅者 |
|------|------|----------|--------|
| `binding_applied` | `(binding_id, card_instance_id, template_id, character_id, slot_type, is_native)` | 新绑定成功 | CombatUI（创建绑定图标+动画）、Audio（绑定音效） |
| `binding_removed` | `(binding_id, card_instance_id, character_id, reason: String)` | 绑定解除（阵亡/覆盖旧卡） | CombatUI（销毁图标+动画） |
| `binding_overwritten` | `(old_binding_id, new_binding_id, character_id, slot_index)` | 覆盖完成 | CombatUI（替换图标+过渡动画） |
| `binding_stacked` | `(binding_id, template_id, character_id, new_stack_count)` | 同名叠加 | CombatUI（"+1层"文字特效+层数徽章更新） |
| `binding_suspended` | `(character_id, binding_ids: Array[int])` | 角色离场 | CombatUI（图标灰显+半透明） |
| `binding_restored` | `(character_id, binding_ids: Array[int])` | 角色重新上场 | CombatUI（图标恢复色彩） |
| `native_activated` | `(binding_id, template_id, character_id)` | 本命绑定激活 | CombatUI（★金色星标亮起）+ Audio（金色共鸣音） |

信号链深度 ≤2 层——绑定信号 → CombatUI 更新 → 无进一步信号级联。

### GSM 边界——ADR-0011 先例模式

本 ADR 采用与 ADR-0011 StatusEffectSystem 相同的 GSM 边界模式：

- **战斗期间**：所有绑定数据由 BindingManager 内部注册表管理——不存储在 GSM 中。热路径查询（`get_bindings_by_character()`、`get_character_by_card()`）直接在 BindingManager 内部 Dictionary 完成，不经过 GSM 层
- **战斗结束**：`serialize_all()` 导出快照至 `GSM.battle.bindings`——用于存档/战斗快照持久化
- **GSM 只读**：BindingManager 通过 GSM 第一层只读访问 `player.realm_level`（获取绑定位上限）——不调用 GSM 第二层写入方法
- **架构原则例外声明**：与 ADR-0011 相同——`architecture.md` §架构原则 #1 需增加 ADR-0013 例外："战斗中绑定数据由 BindingManager 独立管理，仅战斗结束时导出快照至 GSM"

### 本命绑定判定算法

```
determine_native(character_id: int, card_template: CardTemplate, slot_type: BindingSlot) → {is_native: bool, native_multiplier: float}:
  1. 检查 native_owner 匹配：
     card_template.native_owner == "" or null → return {false, 1.0}
     character.card_id 不以 native_owner 为前缀 → return {false, 1.0}
  
  2. 检查该角色同类型本命位是否已被占用：
     existing_native = 该角色已绑定卡中 slot_type 相同且 is_native=true 的记录
     if existing_native 存在 → return {false, 1.0}  # 本命位已满
  
  3. 本命位空闲 → return {true, 1.5}

注意：
  - 本命判定在绑定时自动执行——无玩家弹窗选择
  - native_multiplier 在绑定时预计算并锁定——不运行时重查
  - 同名叠加不重新判定——沿用首次绑定的 is_native 和 native_multiplier
  - 若本命卡被覆盖（旧卡进弃牌堆），新卡可重新占用本命位——重新执行本命判定
```

### 同名叠加乘法公式

```
effective_value = base_value × native_multiplier × (stack_multiplier ^ (stack_count - 1))
```

| 变量 | 类型 | 范围 | 来源 |
|------|------|------|------|
| base_value | int | 按卡牌定义 | CardTemplate（CardSystem） |
| native_multiplier | float | 1.0 或 1.5 | BindingRecord——首次绑定时判定并锁定 |
| stack_multiplier | float | 1.2-2.0，默认 1.5 | CardTemplate.stack_multiplier（可配置） |
| stack_count | int | 1 到 stack_limit | BindingRecord——每次叠加递增 |

此公式在 BindingManager 内部计算——CardEffectEngine 在结算效果时查询 `BindingManager.get_binding_context(card_instance_id)` 获取预计算的 multiplier 乘积（`native_multiplier × stack_multiplier^(stack_count-1)`），不在引擎中重复计算。

## 考虑的替代方案

### 替代方案 1：GSM 管理绑定数据 + BindingSystem 为无状态服务层

- **描述**：BindingSystem 为普通 Node（挂载在 CombatSystem 下），所有绑定数据存储在 `GSM.battle.bindings` Dictionary 中。BindingSystem 的所有方法通过 GSM 第二层 API 读写。
- **优点**：符合 ADR-0001 的 GSM 单一数据源原则——绑定数据与其他战斗数据（battle.* 域）在同一位置；无 Autoload 数量增加
- **缺点**：（1）每帧 `get_accumulated_bonus()` 查询需通过 GSM 层——额外方法调用开销；（2）绑定操作频繁（覆盖/叠加/阵亡释放）——GSM batch_updated 信号过于粗粒度，需为每个绑定操作发射信号，信号噪音高；（3）BindingRecord 作为嵌套 Dictionary 存储在 GSM 中失去类型安全——ADR-0002/0009/0011 均已采用 RefCounted 实例模型，纯 Dictionary 方案与现有模式不一致
- **拒绝原因**：战斗热路径性能 + 与已建立的 Template/Instance 模式不一致。ADR-0011（StatusEffectSystem）已确立"战斗期间子系统内部管理，战斗结束导出快照至 GSM"的例外模式——本 ADR 遵循此先例

### 替代方案 2：绑定逻辑作为 CombatSystem 内部子系统

- **描述**：无独立 Autoload——绑定逻辑作为 CombatSystem 的内部模块（`CombatSystem._binding_manager` 内部类）。绑定数据直接挂在 Character 节点上（`Character.bindings: Array[BindingRecord]`）。
- **优点**：零 Autoload 开销；绑定数据与角色生命周期自然绑定（角色 free() → 绑定自动清理）；CombatSystem 作为编排器直接管理绑定——无需跨 Autoload 调用
- **缺点**：（1）CardEffectEngine 需要查询绑定上下文（multiplier）——如果绑定数据在 Character 节点上，引擎需要通过 CombatSystem 间接查询，增加耦合；（2）CardSystem 查询"某卡绑在谁身上"需要遍历所有角色——O(n) 而非 O(1)；（3）CombatSystem 已经编排 9 个子系统（ADR-0008）——再内嵌绑定逻辑将使其成为上帝对象；（4）GDD 明确要求 BindingManager 为独立 Autoload
- **拒绝原因**：违反单一职责——CombatSystem 已承担阶段编排，不应再内嵌绑定数据管理。独立 Autoload 使 CardEffectEngine、CardSystem、CombatUI 能以解耦方式查询绑定状态

### 替代方案 3：BindingRecord 使用 Resource 子类

- **描述**：BindingRecord 继承 Resource（而非 RefCounted）——利用 Resource 的序列化支持和 Inspector 可见性。
- **优点**：Resource 原生支持 `ResourceSaver.save()` 序列化；可在 Godot Inspector 中查看运行时绑定状态（调试友好）
- **缺点**：（1）Resource 有引用计数和文件路径开销——RefCounted 更轻量；（2）Resource 设计上可持久化到磁盘——绑定数据是纯运行时数据，不应有文件关联；（3）ADR-0002（CardInstance）、ADR-0009（EffectInstance）、ADR-0011（StatusInstance）全部使用 RefCounted——使用 Resource 会打破已建立的 Template(Resource)/Instance(RefCounted) 模式一致性
- **拒绝原因**：破坏 Template/Instance 分离模式的一致性。Template(Resource) + Instance(RefCounted) 是本项目架构的基础模式——ADR-0002（Card）、ADR-0009（Effect）、ADR-0011（Status）均采用此模式。BindingRecord 作为运行时实例没有持久化到独立文件的需求——RefCounted 是正确的选择

## 后果

### 积极的

- **统一的 Template/Instance 四元组**：CardSystem（CardTemplate/CardInstance）、CardEffectEngine（EffectTemplate/EffectInstance）、StatusEffectSystem（StatusTemplate/StatusInstance）、BindingManager（CardTemplate/BindingRecord）——四个系统采用相同的双层对象模型，降低学习成本和代码审查复杂度
- **战斗热路径性能**：`get_bindings_by_character()` 和 `get_character_by_card()` 为 O(1) Dictionary 查找——不经过 GSM 层。`get_accumulated_bonus()` 遍历角色最多 6 张绑定卡——<0.01ms
- **清晰的效果生命周期**：BindingManager → CardEffectEngine 的调用方向明确——绑定系统负责"何时"触发效果变更，效果引擎负责"如何"管理效果实例。责任边界清晰
- **CombatUI 解耦**：Cat 2b 信号总线使 CombatUI 仅订阅 BindingManager 信号即可获取全部绑定状态变更——无需直接查询 BindingManager API
- **GSM 规模控制**：GSM 不持有 200+ BindingRecord 实例——仅战斗结束时接收序列化快照 Dictionary

### 消极的

- **Autoload 数量增加**：BindingManager 为 Autoload #13——项目 Autoload 总数增至 13 个。初始化顺序依赖链延长（虽然 Godot 的 `_ready()` 顺序保证使此风险可控）
- **GSM 例外模式扩散**：ADR-0011 的"战斗期间子系统内部管理"例外模式被第二处 ADR 采用——需在 `architecture.md` 中明确记录例外清单，防止未来子系统滥用此模式
- **两个暂挂/恢复系统并行**：角色离场/上场时，BindingManager 和 StatusEffectSystem 各自独立处理绑定来源和非绑定来源的效果暂挂/恢复——两个系统的 suspend/restore 调用需在 CombatSystem 中正确排序（先 BindingManager、后 StatusEffectSystem——绑定效果可能依赖状态修正值）

### 风险

- **RefCounted 引用计数开销**：化神期单角色 6 绑定 + 每绑定最多 5 层叠加 = 30 BindingRecord/角色，6 角色 = 180 实例。GDScript 使用引用计数（确定性释放，非 GC）——180 个轻量级 RefCounted 实例的 allocation/deallocation churn 需在目标硬件上验证 60fps 表现。Godot 4.5 优化了引用计数性能，预计此规模下影响可忽略
  - 缓解：BindingRecord 为轻量级（~15 字段，无 Resource 引用）——引用计数开销小。若实测有问题，可引入对象池复用。`remove_binding()` 从 `_bindings` 移除后 RefCounted 引用归零→确定性释放——释放前须确保信号处理器未持有 BindingRecord 引用（ADR-0007 禁止模式 #9：`Callable.bind()` 内存陷阱）
- **三个索引结构的同步一致性**：`_bindings` / `_by_character` / `_card_to_character` 三个 Dictionary 索引在 bind/overwrite/stack/remove 操作后必须保持同步——任一索引的更新遗漏会导致 O(1) 查询返回错误结果
  - 缓解：所有绑定变更操作集中在 `_register_binding()` / `_unregister_binding()` 两个内部私有方法中——同时更新三个索引。GUT 测试覆盖每个操作后的三索引一致性断言
- **绑定上限缓存失效**：绑定位上限在战斗开始时从 RealmSystem 缓存。若 `player.realm_level` 在战斗中途发生变化（丹药效果/境界突破事件），缓存的上限将过时
  - 缓解：战斗期间境界变更在当前设计中不可行（CombatSystem 不触发 realm_up）——若未来设计允许，需添加 GSM `realm_changed` 信号监听 + 缓存刷新。暂不实现，在架构风险中记录
- **`deserialize_all()` 部分恢复策略**：从战斗快照恢复时，若部分 `card_instance_id` 验证失败（在 CardSystem 中已不存在），采用尽力而为策略——逐条验证，失败的跳过 + WARN 日志，其余正常恢复。不存在 card_instance_id 的绑定视为"在快照间隔中被移除"，不阻塞整体恢复
- **同名叠加 + 覆盖的竞态**：覆盖操作只移除一层叠加（stack_count -= 1）——若 `stack_count` 减至 0，BindingRecord 删除。此边界在多层叠加+覆盖+阵亡组合场景下需充分测试
  - 缓解：GUT 测试覆盖全部叠加/覆盖/阵亡/离场/复活路径——至少 15 个场景测试
- **本命位"先到先得"的玩家困惑**：第一张匹配 native_owner 的卡自动占用本命位——玩家可能不知道'万象推衍术'也是林渊的本命但本命位已被'青云剑诀'占用
  - 缓解：CombatUI 在绑定预览中显示"本命位已占用"提示——降低而非消除风险
- **战斗快照恢复时绑定状态不一致**：`deserialize_all()` 从 `GSM.battle.bindings` 恢复 BindingRecord——如果快照中的 card_instance_id 在 CardSystem 中已不存在（被其他操作移除），恢复失败
  - 缓解：`deserialize_all()` 中逐条验证 card_instance_id——验证失败则跳过该 BindingRecord + WARN 日志

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| binding-system.md | §1 绑定数据结构——BindingRecord 含 binding_id/card_instance_id/slot_type/is_native/native_multiplier/stack_slots/stack_count + BindingManager 全局注册表 | RefCounted BindingRecord + `_bindings`/`_by_character`/`_card_to_character` 三个 Dictionary 注册表 |
| binding-system.md | §2 绑定位随境界成长——5 级境界→槽位映射表 | `RealmSystem.get_realm_property(level, "gongfa_slots"/"fabao_slots")` —— 战斗开始时缓存 |
| binding-system.md | §3 正常绑定流程——角色选择面板分层着色（灰遮罩>绿叠加>橙覆盖>蓝空位） | `can_bind()` 预检查 API 返回 CanBindResult —— UI 据此着色 |
| binding-system.md | §4 覆盖绑定流程——旧效果移除→新效果注册原子序列 | `overwrite_binding()` 内严格按序调用 `remove_effects_by_source(old)` → `register_persistent_effect(new)` |
| binding-system.md | §6 角色离场暂挂/重新上场恢复 | `suspend_bindings()` / `restore_bindings()` + CardEffectEngine suspend/restore 接口 |
| binding-system.md | §7 角色阵亡→绑定卡洗回牌库 | `remove_all_bindings()` 返回序列化数据 → CardSystem 洗回牌库 |
| binding-system.md | §8 本命绑定规则——native_owner 固定匹配 + 自动判定 + 先到先得 | `determine_native()` 算法——前缀匹配 + 本命位占用检查 + 预计算锁定 |
| binding-system.md | §10 同名卡叠加——共享槽位 + 乘法叠加 + stack_limit 上限 | `stack_card()` + 乘法公式 `base × native × stack_multiplier^(count-1)` |
| binding-system.md | 公式§3 同名叠加公式 | BindingManager 内部预计算 multiplier 乘积——CardEffectEngine 通过 `get_binding_context()` 查询 |
| binding-system.md | 开放问题 #1——数据模型选择 | RefCounted BindingRecord —— 与 ADR-0002/0009/0011 的 Template/Instance 模式一致 |

## 性能影响
- **CPU**：`bind_card()` 单次 <0.5ms（含本命判定+槽位分配+效果注册）；`get_accumulated_bonus()` <0.01ms；`can_bind()` <0.05ms。对 60fps 帧预算无显著影响
- **内存**：化神期峰值 ~180 BindingRecord × ~200 bytes/实例 ≈ 36KB——可忽略
- **加载时间**：BindingManager._ready() 不加载模板——无启动开销。战斗开始时缓存 RealmSystem 槽位数据——O(1)
- **网络**：不适用（单机游戏）

## 迁移计划
本 ADR 为新系统——无需迁移现有代码。实现顺序：
1. BindingRecord RefCounted 类（数据结构）
2. BindingManager Autoload 骨架（注册表 + 基本 CRUD）
3. `can_bind()` + `bind_card()` + 本命判定
4. `stack_card()` + 同名叠加逻辑
5. `overwrite_binding()` + 反悔窗口逻辑
6. `suspend_bindings()` / `restore_bindings()`
7. `remove_all_bindings()` + 阵亡洗回牌库
8. CardEffectEngine 集成（persistent effect 接口调用）
9. Cat 2b 信号总线
10. CombatUI 订阅

## 验证标准
- GUT 单元测试：`can_bind()` 覆盖全部 4 种着色状态（灰遮罩/绿叠加/橙覆盖/蓝空位）—— 12 个场景
- GUT 单元测试：本命判定——native_owner 匹配/不匹配/本命位已满/同名叠加不重新判定 —— 5 个场景
- GUT 单元测试：叠加逻辑——stack_count 递增/上限拒绝/乘法公式计算/不同角色独立 stack_count —— 6 个场景
- GUT 单元测试：覆盖流程——旧卡进弃牌堆/积累数值保留/本命位覆盖需额外确认 —— 4 个场景
- GUT 单元测试：角色阵亡——全部绑定洗回牌库/BindingManager 条目清除/效果引擎 remove_effects_by_source 调用 —— 3 个场景
- GUT 单元测试：角色离场/上场——暂挂/恢复/验证失败→空位 —— 4 个场景
- 集成测试：完整绑定→覆盖→叠加→阵亡→复活流程——CombatSystem + BindingManager + CardEffectEngine 协同
- 性能测试：`get_bindings_by_character()` × 1000 次调用 <1ms；`get_accumulated_bonus()` × 1000 次调用 <10ms

## 相关决策
- [ADR-0001：GameStateManager](ADR-0001-game-state-manager-autoload-singleton-three-tier-api.md) — GSM 只读 + battle.* 域快照
- [ADR-0002：CardSystem](ADR-0006-card-data-model-template-instance-separation.md) — CardTemplate Resource + CardInstance RefCounted 先例（注：CardSystem ADR 编号为 ADR-0006，文件命名为 ADR-0002——历史命名遗留问题，本文以 ADR 编号为准）
- [ADR-0008：CombatSystem](ADR-0008-combat-system-seven-phase-state-machine.md) — Phase 2 PLAY 触发绑定流程 + 角色阵亡/离场/上场事件
- [ADR-0009：CardEffectEngine](ADR-0009-card-effect-engine-resource-refcounted-model.md) — persistent effect 注册/移除/暂挂/恢复接口
- [ADR-0010：RealmSystem](ADR-0010-realm-system-autoload-dedicated-service.md) — 绑定位上限随境界成长
- [ADR-0011：StatusEffectSystem](ADR-0011-status-effect-system-template-instance-model.md) — Template/Instance 模式 + 战斗热路径 O(1) + GSM 例外先例

## 引擎专家审查追踪

| # | 级别 | 发现 | 处置 |
|---|------|------|------|
| H1 | HIGH | `get_bindings_by_character()` 每帧分配新 Array[BindingRecord]——CombatUI 热路径内存波动 | **已处理**：新增 `get_binding_ids_by_character()` 零分配查询（返回 `Array[int]`）。`get_bindings_by_character()` 保留为非热路径使用——文档标注分配警告 |
| H2 | HIGH | Autoload `_ready()` 信号时序——Godot 信号同步发射不重放，Autoload #13 连接 #1 的信号时信号已发射 | **已处理**：遵循 ADR-0012 模式——BindingManager._ready() 通过直接方法调用查询 GSM/RealmSystem，不 await 信号。在 §排序说明 中记录 |
| H3 | HIGH | `Dictionary[int, BindingRecord]` 键类型提示非编译器强制——`_bindings[id]` 赋值时无编译时类型检查 | **已处理**：在需求章节添加 `assert(_bindings[id] is BindingRecord)` 运行时守卫 |
| L1 | LOW | RefCounted 释放路径——`remove_binding()` 后悬空的信号连接可能持有引用 | **已处理**：在风险章节添加释放路径说明——引用 ADR-0007 禁止模式 #9 |
| L2 | LOW | 术语"GC"——GDScript 使用引用计数（确定性），非垃圾回收（非确定性） | **已处理**：全文"GC 抖动"替换为"引用计数开销 / allocation/deallocation churn" |
| L3 | LOW | `deserialize_all()` 部分恢复策略未明确——全部或无不明确 | **已处理**：在风险章节明确"尽力而为"策略——逐条验证，失败跳过+WARN，其余恢复 |
| L4 | LOW | 绑定位上限缓存失效——战斗中途境界变更可能导致缓存过时 | **已处理**：在风险中记录——当前设计不触发战斗中境界变更，暂不实现，作为已知架构风险 |

**godot-specialist 审查结论**：无阻塞问题——所有 4 HIGH + 4 LOW 已处理。ADR-0013 在 Godot 4.6 架构层面合理。

## 技术主管审查追踪

| # | 级别 | 发现 | 处置 |
|---|------|------|------|
| C#1 | CONCERN | 4a——"启用"字段引用 ADR-0012 为 CombatUI，实际 ADR-0012 为 ProgressionSystem | **已修正**：改为前向引用"CombatUI（尚无独立 ADR……）" |
| C#2 | CONCERN | 4b——"相关决策"ADR-0002 链接指向 ADR-0003 的文件（历史命名遗留） | **已修正**：链接修正为 `ADR-0006-card-data-model-template-instance-separation.md`，加注释说明历史命名问题 |
| C#3 | CONCERN | 4c——`architecture.md` 原则 #1 需增加 ADR-0013 例外——在 Accepted 前执行 | **已确认**：在 GSM 边界章节已声明——标记为 Accepted 时将同步更新 architecture.md |
| C#4 | CONCERN | 4d——两个暂挂/恢复系统并行的排序契约应更强规定 | **已处理**：在消极后果中明确排序方向（先 BindingManager、后 StatusEffectSystem），并在 §风险 中增加三索引同步一致性风险 |

**technical-director 审查结论**：CONCERNS——4 项关注点均已处理。架构决策健全，可在接受后翻转为 Accepted。
