# ADR-0001：游戏状态管理器 — Autoload 单例 + 三层 API

## 状态
Proposed

## 日期
2026-07-24

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Core / Foundation |
| **知识风险** | LOW |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **使用的截止后 API** | `Array[String]`（4.4+ 类型化集合——4.5 优化，非破坏性） |
| **需要验证** | `FileAccess.store_*` 返回 `bool`（4.4）——存档系统而非 GSM 直接使用 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | None |
| **启用** | ADR-0002（存档/读档）、ADR-0003（事件系统）、ADR-0004（输入管理器）、ADR-0005（场景管理器）、ADR-0006（卡牌数据模型）、ADR-0007（信号通信）、ADR-0008（战斗系统）、ADR-0009（卡牌效果引擎）——以及所有后续 ADR |
| **阻塞** | **所有史诗**——在 GSM API 被接受之前无法开始 Foundation 层实现 |
| **排序说明** | 必须在所有其他 ADR 之前被接受。必须在任何代码被编写之前被接受 |

## 上下文

### 问题陈述
游戏有 39 个系统（6 个 Foundation、4 个 Core、22 个 Feature、6 个 Presentation、3 个横切）需要对共享游戏状态进行读写操作——玩家境界、修为、资源、卡牌收藏、战斗状态、探索进度、剧情标记等。在缺乏单一仲裁者的情况下，系统将直接修改彼此的状态，导致：
- **数据漂移**：两个系统持有同一数据的副本，其中一个变陈旧
- **重复写入**：三个系统写入 `story_flags` 而无协调（已在 systems-mapping-2026-07-24.md 中检测到）
- **UI 不一致**：HUD 不知道何时刷新，因为变更来源不可预测
- **存档损坏**：序列化没有单一规范——个别系统可能丢失状态

需要的是一个单一数据源，具有明确的读写规则，能够"不被注意到"——如此可靠，以至于开发者永远不会质疑他们是否读取到了最新状态。

### 约束
- 必须作为 Godot Autoload 运行——在任何场景加载之前存在
- 必须支持 35 个消费者系统（从 AI 系统到 HUD），同时保持 16.6ms 帧预算
- 必须在热路径中实现零拷贝读取——结构体拷贝或序列化往返是不可接受的
- 必须在战斗结算期间支持原子多重写入（灵石、修为、卡牌在一次批量操作中全部变化）
- 必须提供一致的信号广播，以使 UI 系统能够刷新而无需轮询
- 必须支持 `serialize()` / `deserialize()` 用于存档系统（非持久化字段自动排除）

### 需求
- 39 个系统的三层读写接口（每帧快速读取、原子多重写入、用于 UI 的信号）
- 启动时以"校验跳过"模式初始化——在卡牌系统就绪之前不进行卡牌 ID 校验
- 写入时类型/范围/引用完整性校验（防损坏）
- 同帧去重（同一路径多次写入 → 仅最后一次变更发射信号）
- 战斗中存档时 `battle` 和 `session` 域排除在序列化之外

## 决策

**GSM 将作为 Godot Autoload 单例实现，具有三层接口：**

### 第一层：直接属性读取（每帧热路径，零开销）
```
GSM.player.realm          → int
GSM.player.cultivation    → float
GSM.player.resources      → Dictionary[String, int]
GSM.session.input_locks   → Array[int]  # 使用 LockType 枚举
GSM.session.current_scene → String
```
- 无信号开销，无拷贝。消费者直接读取 Autoload 属性。
- 35 个系统在战斗期间（约 10-12 个活跃）每帧进行属性查询。每次访问是 O(1) 字典查找。预计每帧 <0.1ms。

### 第二层：原子写入操作（信号广播网关）
所有写入通过 GSM 方法进行。绝不直接写入属性。

```
GSM.apply_battle_rewards(lingshi: int, cultivation: float, cards: Array[String]) → void
  # 原子操作：写入 3 个字段，然后一次性发射 batch_updated 信号
  # 不变量：调用前 battle.result != null
  # 保证：原子——全部写入或全部失败（无部分写入）

GSM.change_realm(new_level: int) → void
  # 原子操作：设置 realm_guard = true
  # → 更新 8 个消费者字段（费用、上场、行动力、卡池、探索地图、绑定、HUD）
  # → 发射 realm_changed(old, new)
  # → 设置 realm_guard = false
  # 不变量：调用前 realm_guard == false
  # 保证：所有消费者在 guard 解除后看到一致的新值

GSM.add_resource(type: String, amount: int) → bool
  # 失败返回 false（type 不存在）
  # 成功 → 发射 resource_changed 信号

GSM.allocate_card_id() → int
  # 返回单调递增的 _next_card_id 当前值，然后递增
  # 分配后不可收回——CardSystem 在创建 CardInstance 时调用
  # 定义于 ADR-0002（卡牌数据模型）——此处记录以供 API 完整性

GSM.add_card_to_collection(inst_dict: Dictionary) → void
  # inst_dict 由 CardSystem.serialize_instance() 生成
  # 在 validation_enabled == false 时拒绝写入并记录警告
  # 在 validation_enabled == true 时校验 inst_dict["template_id"] 存在于 CardSystem.templates
  # 定义于 ADR-0002（卡牌数据模型）——此处记录以供 API 完整性

GSM.remove_card_from_collection(card_instance_id: int) → bool
  # 按 card_instance_id 从 owned_cards 中删除
  # 未找到时返回 false
  # 定义于 ADR-0002（卡牌数据模型）

GSM.set_narrative_flag(flag: StringName, value: Variant) → void
  # story_flags 的唯一运行时写入入口——仅 EventSystem 调用
  # 写入 GSM.narrative.story_flags[flag] = value
  # 值无变化时不发射信号（de-deup）
  # 值变更后发射 batch_updated({"narrative.story_flags.{flag}": {old, new}})
  # 定义于 ADR-0004（事件系统）——此处记录以供 API 完整性
  # ⚠️ 剧情/对话/效果引擎不得直接调用——它们通过 EventSystem.set_flag() 委托写入
```

"guard"一词特意使用而非"lock"，以避免与多线程原语混淆——GDScript 是单线程的，guard 是语义屏障。

### 第三层：信号订阅（UI 响应层）
```
GSM.player_changed(prop: String, old_val, new_val)
  # 任何写入后发射。prop = "realm" | "cultivation" | "resources" | ...

GSM.realm_changed(old_level: int, new_level: int)
  # 仅在 change_realm() 成功时发射——在 8 个字段全部更新之后

GSM.batch_updated(changes: Dictionary)  # 展平的合并字典
  # { "player.resources.ling_shi": {old: 100, new: 150},
  #   "player.cultivation": {old: 200, new: 650} }
  # UI 系统使用 'prop' 键过滤只关心它们所关心的内容

GSM.gsm_initialized()  # 一旦 GSM._ready() 完成即发射
```

**信号在数据写入后发射（写入优先，然后通知）。**
消费者绝不从信号处理器内部写入 GSM（防止递归循环）。

### 架构图

```
┌─────────────────────────────────────────────────────────┐
│                    GameStateManager (Autoload)          │
│                                                         │
│  ┌─ 第一层：属性读取 ──────────────────────────┐        │
│  │ GSM.player.*   GSM.collection.*              │        │
│  │ GSM.deck.*     GSM.exploration.*             │        │
│  │ GSM.narrative.*  GSM.session.*               │        │
│  │ → 无拷贝，O(1) 字典访问，每帧数百万次读取安全     │        │
│  └──────────────────────────────────────────────┘        │
│                                                         │
│  ┌─ 第二层：原子方法 ──────────────────────────┐        │
│  │ apply_battle_rewards()   change_realm()       │        │
│  │ add_cultivation()        spend_resource()    │        │
│  │ add_card_to_collection() battle_start/end()  │        │
│  │ → 多重写入合并在一个信号内                     │        │
│  │ → 写入时做范围/类型/引用完整性校验             │        │
│  └──────────────────────────────────────────────┘        │
│                                                         │
│  ┌─ 第三层：信号 ──────────────────────────────┐        │
│  │ player_changed    realm_changed                │        │
│  │ resource_changed  batch_updated                │        │
│  │ gsm_initialized   card_collection_changed      │        │
│  │ → 先写入，后发射。消费者不可在处理器中写回        │        │
│  └──────────────────────────────────────────────┘        │
│                                                         │
│  ┌─ 内部 ───────────────────────────────────────┐       │
│  │ _validate_type()   _validate_range()            │       │
│  │ _validate_card_ref()  _dedup_same_frame()       │       │
│  │ _check_recursive_write()                        │       │
│  │ validation_enabled: bool = false（启动时）       │       │
│  └──────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────┘
         ▲                    ▲
         │ 读取               │ 写入 + 信号
    ┌────┴─────┐         ┌───┴──────────┐
    │ 35 消费者  │         │ 约 15 写入者   │
    │（每帧读取） │         │（事件驱动写入） │
    └──────────┘         └──────────────┘
```

### 关键接口

```
## 读取者契约（所有消费者）
1. 任意时刻均允许读取——不需要 guard
2. 每帧读取：直接属性访问，不含 GSM 方法调用
3. 事件驱动读取：在信号处理器中（但不写回）

## 写入者契约
1. 仅通过第二层原子方法写入——绝不直接修改属性
2. 在一次信号处理中绝不多次写入同一路径
3. 检查返回值（spend_resource 和 add_resource 会失败）
4. 写入仅在事件响应中（按键/结算/章节推进）——从不在 _process 中

## 启动合约
1. GSM 以 validation_enabled = false 启动
2. CardSystem Autoload 在 _ready() 中加载后调用 GSM.enable_validation(db)
3. GSM._ready() 发射 gsm_initialized
4. 在 gsm_initialized 信号前任何系统不得写入 GSM

## 序列化合约
1. GSM.serialize() → Dictionary（battle 和 session 域被排除）
2. GSM.deserialize(Dictionary) → bool（达到校验标准）
3. 存档 I/O 由 SaveLoadSystem 负责——GSM 仅提供数据
```

## 考虑的替代方案

### 替代方案 A：得墨忒耳式委托（每域单独管理器）
- **描述**：`PlayerManager`、`CollectionManager`、`BattleManager`、`ExplorationManager`——每个域一个管理器，而非一个整体式 GSM。
- **优点**：更清晰的关注点分离、更小的类、更细粒度的信号
- **缺点**：跨域变更（"战斗结算更新灵石 AND 修为 AND 卡牌"）需要协调多个管理器，可能带来不一致的部分更新。存档序列化必须聚合 8 个独立的管理器。Autoload 注册表的大小将是原来的 8 倍。
- **拒绝原因**：得墨忒耳违反了批处理一致性。一次战斗结算更新 3 个域；一次境界突破更新 8 个域。如果变更 A 到达 PlayerManager 但在到达 ResourceManager 前失败，游戏状态将变得不一致。GSM 的原子批量操作（`apply_battle_rewards`、`change_realm`）保证了一致性——这一保证在多个管理器下将不复存在。

### 替代方案 B：Godot Resource 层级结构（每个节点一个 Resource）
- **描述**：GameState 作为 Resource 内嵌在节点中。系统通过节点查找（`get_node("/root/GameState")`）而非 Autoload 单例来访问 Resource。
- **优点**：在编辑器中可检查、可内嵌到场景中、自然支持 `ResourceSaver` 存档。
- **缺点**：无 Autoload 保证——场景可能在没有 GameState 节点的情况下加载。信号从 Resource 发射（不如 Autoload 方便）。Resource 的 `duplicate()` 语义在嵌套 Resource 中容易出错（可能传播引用而非克隆——`duplicate_deep()` 在 4.5 中修复，但行为差异很大）。
- **拒绝原因**：Resource 缺乏 Autoload 的生命周期保证。GSM 必须在所有场景加载前就存在，并在场景变更后继续留存。Resource 可以做到这一点，但 Godot 的 Autoload 系统已经是为此而构建的——重新实现它是一种反模式。

### 替代方案 C：事件溯源（不可变事件日志）
- **描述**：所有状态变更以事件形式记录（`CultivationIncreased(100)`、`ResourceSpent("灵石", 50)`）。当前状态通过回放事件日志推导得出。存档就是事件日志。
- **优点**：完整审计追踪、自然支持回放/调试、时间旅行调试、"撤销"天生支持。
- **缺点**：当前状态的计算在每次查询时需要重放日志（或保存快照）。222 张卡牌 × 30 回合 × 每局 5 场战斗 = 以事件形式记录的约 33,000 个事件——重放以重构状态变得代价高昂。GDScript 不是为此模式设计的——没有不可变数据结构的原生支持。
- **拒绝原因**：对于单线程游戏引擎中 39 个系统的实时游戏循环来说，事件溯源过于繁重。以事件日志形式回放 33,000 个事件来重构状态以实现每帧读取，这违背了 60fps 的要求。快照 + 事件（折中方案）又退化为第二层 + 日志的形式，复杂性成倍增加，却没有带来时间旅行能力。

## 后果

### 积极的
- **单一真理来源**：35 个消费者读取同一份内存中的数据。没有漂移。
- **原子多重写入**：`apply_battle_rewards` 保证灵石、修为和卡牌三者全部变化，或全部不变。消除了经典的"获得灵石但修为未增加"的 bug。
- **信号是可靠的最后保证**：UI 总是在数据一致后收到通知——不会读取写入了一半的状态。
- **校验在写入时进行**：无效卡牌 ID、资源溢出、类型不匹配将在处理链的早期被捕获——仅到达状态层即被截停，而非在 5 个系统之外才报错。
- **存档变得简单**：在所有消费者之外，一个 `serialize()` 调用（排除 battle + session）产生完整状态。`deserialize()` 在加载时进行一次校验，然后信号通知所有系统刷新。

### 消极的
- **单点故障**：如果 GSM 崩溃或返回谬误数据，所有系统都会受到影响——没有后备数据源。
- **上帝对象的风险**：GSM 触及所有领域。随着游戏的成长，它必须抵制积累业务逻辑的倾向（"我应该在发放修为之前检查 curse_flag 吗？"——不，那属于行为系统，而非 GSM）。
- **Autoload 初始化顺序混乱**：Godot 的 Autoload `_ready()` 顺序取决于 Project Settings 中的列表顺序，而非类名。如果顺序错误，消费者可能在 GSM 的 `_ready()` 完成前调用 `GSM.get()`，从而导致静默的空值读取。
- **信号发射成本**：战斗结算期间的 `batch_updated` 带有 3-5 个变更的字典需要分配字典并进行信号回调跳跃——对于在 16.6ms 预算内运行的 2D 卡牌游戏而言微不足道，但确实是开销。

### 风险
- **热路径中的上帝对象**：所有 35 个系统都触碰 GSM——如果读取 API 变慢，所有系统都会变慢。缓解措施：第一层直接属性读取是 O(1) 字典访问，无方法调用开销。在战斗期间，性能分析可进行路由变更。实际消耗预计 <0.1ms/帧。
- **Autoload 顺序导致静默空值读取**：消费者在 GSM 初始化期间读取未初始化的属性。缓解措施：GSM 必须在第一个 Autoload 位置。消费系统在它们的 `_ready()` 中检查 `GSM._initialized` 并在 GSM 就绪之前延迟读取。
- **递归写入循环**：系统 A 写入 → 信号 → 系统 B 从处理器写回同一路径。缓解措施：GSM 检测递归写入并记录警告而非阻塞（允许，但被观察到）。下次运行时开发者会看到日志，应修复调用者。
- **校验跳过窗口期间卡牌损坏**：在 `enable_validation()` 被调用之前，理论上一张无效卡牌可能会溜过 GSM 的防线。缓解措施：GSM 在 `enable_validation()` 被调用之前拒绝所有 `add_card_to_collection()` 调用（在跳过模式下返回 false），实际上阻止了卡牌写入，直到卡牌系统就绪。

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| game-state-manager.md | §概述：GSM 为运行时单一数据源，通过 Autoload 常驻内存 | 确立 Godot Autoload 单例模式，在所有场景之前初始化，场景变更后继续留存 |
| game-state-manager.md | §详细设计 #2 读写接口规范：通用 `get(path)`、批量设置、类型安全读取 | 定义三层接口：直接属性读取（第一层）、原子方法（第二层）、信号订阅（第三层） |
| game-state-manager.md | §详细设计 #3 信号广播机制：13 个命名事件，同帧去重，`batch_updated` 用于批量变更 | 确立"写入优先，然后信号"的执行顺序，以及 HUD 高效刷新的 `batch_updated` 展平合并字典格式 |
| game-state-manager.md | §公式 #5 卡牌校验初始化合约：GSM 以跳过模式启动，card-system 调用 `enable_validation()` | 正式确立启动合约，将其作为 Foundation 层初始化顺序的一部分 |
| game-state-manager.md | §边界情况：batch_updated 载荷格式——展平合并字典 | 确立 `{ "player.resources.ling_shi": {old, new}, ... }` 格式 |
| game-state-manager.md | §调优参数：单帧最大信号广播 50，资源上限 999999 | 作为配置常量纳入 GSM——可调节，有文档记录 |
| systems-mapping-2026-07-24.md | §4.1：GSM 必须定义三层访问，然后任何消费者才能开始 | 直接解决——本 ADR 正是该规范 |

## 性能影响
- **CPU**：每帧 <0.1ms 用于读取（约 10-12 个活跃系统的 35 × O(1) 字典查询）。信号发射仅在事件中（每场战斗 1 次战斗结算、每局 1-4 次境界突破），而非每帧。
- **内存**：完整运行时 GameState 字典 <1MB（39 个系统的序列化后状态——卡牌标题、资源整数、剧情标记）。battle 域在非战斗时为 null（无内存占用）。progression.dat 独立存储，不在 GSM 内存中。
- **加载时间**：GSM `_ready()` 是即时的（初始化空字典）。卡牌模板加载发生在 CardSystem `_ready()` 中（独立 ADR——ADR-0006），而非 GSM 中。
- **网络**：不适用（纯单机游戏）。

## 迁移计划
无现有代码需迁移——这是首个 Foundation 决策。所有后续实现将以此为构建起点。

## 验证标准
- 通过 GUT：`GameStateManager` 测试套件覆盖：所有写入方法、所有信号发射、类型校验拒绝无效写入、范围校验强制资源非负、引用完整性校验拒绝无效卡牌 ID、在同帧去重中多次写入仅发射一次信号、`batch_updated` 携带一致的值（旧值匹配写入前的状态）。
- 通过性能分析：独处模式下的战斗场景——GSM 读取在 60fps 下每帧 <0.1ms。战斗结算信号发射 <0.5ms。
- 通过集成：两个系统在同一帧写入同一路径→发出警告，第二次写入胜出。境界突破原子操作——8 个消费者字段全部更新，无一遗漏。

## 相关决策
- ADR-0002（存档/读档：JSON + 模式版本 + 迁移链）——消费 `GSM.serialize()` / `GSM.deserialize()`
- ADR-0006（卡牌数据模型：Template/Instance 分离）——消费 `GSM.add_card_to_collection()` 并在启动时调用 `enable_validation()`
- ADR-0007（信号驱动通信：粒度 + 变更掩码）——细化信号粒度（`player_changed` 变更掩码 vs 每次属性一个信号）