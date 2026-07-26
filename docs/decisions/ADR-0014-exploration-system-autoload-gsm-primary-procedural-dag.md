# ADR-0014：探索系统 — Autoload + GSM 主存储 + 程序化 DAG 生成 + 信号驱动子系统委托

## 状态
Accepted（2026-07-26——Feature 层审查通过。修复：Foundation 编号偏移（ADR-0004→0003 EventSystem、ADR-0006→0005 SceneManager、ADR-0001~0007→0001~0005）。）

## 日期
2026-07-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Exploration |
| **知识风险** | LOW（探索系统使用基础引擎 API——`Node` Autoload、`RandomNumberGenerator`、`Dictionary` 数据结构、Godot 信号系统——均为 4.0+ 稳定 API） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/current-best-practices.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **使用的截止后 API** | None——核心 DAG 生成和导航逻辑不依赖 4.4+ 新 API |
| **需要验证** | `RandomNumberGenerator` 在相同 seed 下的确定性输出（用于地图重播）；`Dictionary` 嵌套 DAG 结构在 `GSM.serialize()` JSON 往返中的序列化性能（预计 100-200 节点 <1ms）；Autoload 初始化顺序——ExplorationSystem 必须在 RealmSystem 之后、任何可能触发地图选择的 UI 之前注册 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`exploration.*` 域运行时状态存储、`batch_updated` 信号传播导航状态变更）；ADR-0003（EventSystem——事件节点触发委托、`event_node_reached` / `event_resolved` 信号协作）；ADR-0005（SceneManager——战斗场景加载/卸载、探索场景切换）；ADR-0007（三分类信号体系——探索系统 Cat 2b 信号定义、信号 vs 直接调用决策矩阵）；ADR-0008（CombatSystem——战斗节点委托、`combat_node_reached` / `combat_ended` 信号协作）；ADR-0010（RealmSystem——`map_unlock` 数据、`map_effective_realm()` 柔性压制查询、`get_realm_property()` 行动力上限查询） |
| **启用** | ADR-0015+（探索 UI 系统——节点图渲染、地图选择界面、交互弹窗的数据源和指令接口） |
| **阻塞** | 探索 Epic（地图选择→DAG 生成→节点导航→子系统协作的完整流程实现）、探索 UI Epic（节点图渲染和交互依赖探索系统的地图数据模型） |
| **排序说明** | Feature 层中期 ADR。在 Foundation 层（ADR-0001~0005）和 Core 层关键 ADR（ADR-0010 RealmSystem、ADR-0012 ProgressionSystem）之后被接受。在探索 UI 系统 ADR 之前被接受——UI 依赖探索系统的数据模型和信号接口 |

## 上下文

### 问题陈述

`exploration-system.md` GDD 定义了完整的探索阶段流程——地图选择、DAG 节点图生成、节点导航、事件/战斗/商店等节点的触发调度、地图通关奖励结算。GDD 覆盖了「玩家体验到的探索流程」，但以下架构问题需要在 ADR 层面解决：

1. **运行时状态归属**：ADR-0001 已将 `exploration.*` 域（map_id、node_position、action_points、map_state）的运行时所有权分配给 GSM，标记为"由 ExplorationSystem 通过 GSM API 写入"。但 GDD 中的导航状态远比最初预想的复杂——`visited_nodes`（Set）、`current_map`（StringName）、`map_entry_count`（Dict）、`collected_resources`（Dict）、`node_graph`（DAG 结构）等。需要明确哪些状态通过 GSM 存储（支持存档/读档），哪些作为 ExplorationSystem 内部计算缓存（不持久化）。

2. **DAG 生成策略**：GDD 待解决问题 #1 标记了「程序化生成 vs 预定义模板」的选择。GDD §3 描述了完整的加权随机分配算法，但需要明确边连接保证、独立路径数约束、后处理验证的具体策略。

3. **子系统委托模式**：探索系统需要触发 6 种不同类型的节点交互（事件、战斗、商店、渡劫、回复、行动力泉），每种涉及不同的子系统。需要统一的信号委托模式——遵循 ADR-0003（EventSystem 委托）和 ADR-0008（CombatSystem 编排）的先例。

4. **地图经济模型**：重入传送费（公式 10）、境界差额惩罚（公式 6）、永久免费地图安全阀——这些经济规则影响 ResourceSystem 和 RealmSystem 的接口设计。

5. **Autoload 定位**：架构层面需要决定 ExplorationSystem 是否为 Autoload。如果是，它在 13 个已有 Autoload 链中的位置是什么？

### 约束

- **Feature 层**：探索系统不属于 Foundation 层——它依赖 Foundation 层（GSM、EventSystem、SceneManager）和 Core 层（RealmSystem）并编排它们
- **GSM exploration.* 域已存在**：ADR-0001 注册表已声明 `exploration.* 域（map_id, node_position, action_points, map_state）` 的所有权——本 ADR 在此现有契约基础上细化，不推翻
- **存档兼容性**：`exploration.map_state` 必须支持 JSON 序列化（`GSM.serialize()` 的一部分）——DAG 结构需设计为纯 Dictionary/Array 格式
- **探索→战斗→探索的往返**：战斗结束后必须恢复到探索场景和节点位置——需要 SceneManager 协作
- **GDD 验收标准约束**：exploration-system.md 定义了 36 条验收标准——本 ADR 的接口设计必须能够满足所有标准
- **帧预算**：DAG 生成在主线程执行（地图加载时）——100-200 节点的图生成预计 <5ms。节点导航每帧 O(1) 查询。不涉及热路径性能敏感操作
- **Godot 4.6 惯用性**：依技术偏好设定，使用 GDScript + Autoload 模式。信号遵循 ADR-0007 Cat 2b 命名规范

### 需求

- 地图选择：从 RealmSystem 获取已解锁地图列表 → 验证境界条件/灵石余额 → 进入地图或拒绝
- DAG 生成：程序化生成有向无环图——层数 4-6、每层 2-4 节点、加权随机节点类型分配、至少 2 条独立路径到 Boss
- 节点导航：移动验证（可达性、行动力、回退检测）→ 消耗行动力 → 触发节点交互
- 子系统委托：统一的信号驱动委托模式——事件→EventSystem、战斗→CombatSystem、商店→CardSystem/ResourceSystem
- 地图经济：重入费用计算、境界差额惩罚、永久免费地图安全阀
- 状态持久化：导航状态通过 GSM 存储以支持存档/读档——中途存档恢复到同一节点位置

## 决策

### 决策 1：ExplorationSystem 作为 Autoload #14 + GSM 主存储模型

**ExplorationSystem 注册为 Autoload #14，位于 ProgressionSystem（#12）和 BindingManager（#13）之后。探索运行时状态分层存储：导航状态（current_map、node_position、visited_nodes、action_points、map_entry_count）通过 GSM exploration.* 域存储以支持存档/读档；DAG 生成的计算中间产物（node_graph 结构、reachable_paths 缓存）作为 ExplorationSystem 内部成员变量——不持久化，读档后从 map_state 重建。**

完整的 Autoload 链（14 个）：
```
GSM(1) → InputManager(2) → SceneManager(3) → SaveLoad(4) → EventSystem(5)
→ CardSystem(6) → CostSystem(7) → StatusEffectSystem(8) → CombatSystem(9)
→ CardEffectEngine(10) → RealmSystem(11) → ProgressionSystem(12)
→ BindingManager(13) → ExplorationSystem(14)
```

**状态分层逻辑：**

```
┌─────────────────────────────────────────────────────────────┐
│              探索状态分层模型                                │
│                                                              │
│  GSM exploration.* 域（持久化，支持存档/读档）:               │
│    exploration.current_map: StringName         # 当前地图 ID │
│    exploration.node_position: Dictionary       # {layer, idx}│
│    exploration.visited_nodes: Array[int]       # 已访问节点ID│
│    exploration.action_points: int              # 当前行动力   │
│    exploration.max_action_points: int          # 行动力上限   │
│    exploration.map_states: Dictionary[StringName, Dictionary] │
│      # key = map_id——跨地图重入追踪。每个值:                   │
│      #   entry_count: int          # 本局累计进入次数         │
│      #   is_first_clear: bool      # 是否已首通                │
│      #   collected_ling_shi: int   # 该地图累计获得灵石       │
│      #   collected_cultivation: int # 该地图累计获得修为       │
│      #   collected_cards: Array[StringName]                  │
│      #   last_node_position: Dictionary  # 上次存档时的节点位置（可null）│
│    # 当前地图的 collected_* 通过 exploration.map_states[current_map] 访问│
│    # current_map 和 map_states 的 key 一致性由 ExplorationSystem 维护   │
│                                                              │
│  ExplorationSystem 内部（运行时缓存，不持久化）:              │
│    _node_graph: Dictionary          # DAG 邻接表结构          │
│    _node_details: Dictionary        # 节点类型/敌人/事件模板  │
│    _reachable_cache: Dictionary     # 可达性预计算缓存        │
│    _shop_inventories: Dictionary    # 商店库存（生成时确定）  │
│    _map_config: Dictionary          # 当前地图配置快照        │
└─────────────────────────────────────────────────────────────┘
```

**状态模型论证**：与 ADR-0011（StatusEffectSystem）和 ADR-0013（BindingManager）不同——后两者的运行时数据是战斗专用的、不持久化的中间状态（状态实例、绑定关系在战斗结束时通过 snapshot 导出）。探索的导航状态本身就是需要被存档的游戏状态——玩家期望中途存读档后恢复到同一节点位置。因此采用 GSM-primary 模型（类似 CombatSystem 对 `battle.*` 的独占写入），而非内部注册表模型。

**存档/读档流程：**
```
存档时:
  GSM.serialize() 自动包含 exploration.* 域（JSON 兼容格式）
  → SaveLoadSystem 写入 save.json

读档时:
  SaveLoadSystem.load() → GSM.deserialize()
  → ExplorationSystem 检测 exploration.current_map 非空
  → 从 map_state 重建 _node_graph + _node_details
  → 恢复到 exploration.node_position
```

### 决策 2：程序化 DAG 生成——加权随机分配 + 后处理约束强制执行

**地图节点图完全程序化生成：加权随机分配节点类型（战斗 40/事件 30/商店 15/回复 10/精英 5）+ 确定性边连接 + 后处理约束验证（最小编号的精英/商店数、独立路径数 ≥2）。不使用预定义模板——程序化生成提供每次进入的不同布局，同时保证可玩性约束。**

**生成流程（对应 GDD §3）：**

```
generate_map(map_id: StringName, player_realm: int) → Dictionary:
  Phase 1 — 读取配置:
    config = _get_map_config(map_id, player_realm)
    # config 从 RealmSystem.get_realm_property() 衍生:
    #   layers: 4-6（根据 map_difficulty）
    #   nodes_per_layer: [2-3, 2-4, 2-4, ...]
    #   elite_count: 0-3
    #   shop_count: 1-2
    #   event_count: 1-4
    #   权重: {combat:40, event:30, shop:15, rest:10, elite:5}

  Phase 2 — 生成 DAG 骨架:
    layers = config.total_layers  # 含入口层(0)和Boss层(layers-1)
    nodes_per_layer = [randi_range(config.min_nodes, config.max_nodes) for each layer]
    nodes_per_layer[0] = 1            # 入口层
    nodes_per_layer[layers-1] = 1     # Boss层

  Phase 3 — 分配节点类型（加权随机）:
    for layer in 1..layers-2:
      for node in 0..nodes_per_layer[layer]-1:
        type = _weighted_random(config.weights, rng)
        # 排除已满足数量约束的类型（精英/商店）
        if type == ELITE and elites_assigned >= config.elite_count:
          type = _weighted_random(adjusted_weights, rng)
        if type == SHOP and shops_assigned >= config.shop_count:
          type = _weighted_random(adjusted_weights, rng)

  Phase 4 — 边连接（确保连通性 + ≥2 独立路径）:
    for layer in 1..layers-1:
      # 每层每个节点至少连接上层 1 个节点
      # 上层每个节点连接下层 1-2 个节点
      for node in nodes_per_layer[layer]:
        parents = _select_parents(layer, node, rng)
        # 验证：所有节点都可达入口、都存在到Boss的路径
        _connect(node, parents)

    if _count_vertex_disjoint_paths() < 2:
      # 回退：添加交叉边直到满足 ≥2 独立路径
      _add_cross_edges(max_attempts=3)
      if still < 2:
        # 概率性回退：重新生成 DAG（最多 2 次，预期重试率 <1%）
        log_warning("vertex_disjoint_paths < 2 for map %s——retrying generation" % map_id)
        if not _retry_generation(map_id, max_retries=2):
          # 最终回退：边不相交但顶点可相交
          log_error("vertex_disjoint_paths < 2 after retries for map %s" % map_id)

  Phase 5 — 填充节点内容:
    for combat_node in combat_nodes:
      enemy_roster = _generate_enemy_roster(map_id, player_realm)
    for event_node in event_nodes:
      # 不在此处分配具体事件——到达时才触发（防SL刷事件）
      event_node.event_pool = _get_event_pool(map_id)
    for shop_node in shop_nodes:
      shop_node.inventory = _generate_shop_inventory(player_realm)

  Phase 6 — 返回图结构:
    return {
      graph: adjacency_list,       # {node_id: [child_ids]}
      nodes: node_details,         # {node_id: {type, layer, ...}}
      layers: nodes_per_layer,
      boss_node_id: boss_id,
      path_count: vertex_disjoint_count
    }
```

**随机性保证：**
- 使用独立 `RandomNumberGenerator` 实例——seed 来自 `GSM.meta.seed`（与 ADR-0009 PRDEngine 一致的确定性模式）
- 同一 seed + 同一 map_id + 同一 entry_count → 同一节点图（支持重播和回归测试）
- 事件节点的具体事件内容在到达时才确定（GDD 明确要求防 SL）
- 商店库存在地图生成时确定（防到达顺序差异）

### 决策 3：统一信号驱动子系统委托

**探索系统通过 Cat 2b 信号触发子系统交互——遵循 ADR-0003（EventSystem 委托）和 ADR-0008（CombatSystem 编排）的先例。探索系统本身只负责地图生成、节点导航和状态管理——节点到达后的具体交互委托给对应的子系统。**

**信号接口定义（Godot 4.6 Cat 2b——遵循 ADR-0007）：**

| 信号 | 发射方 | 载荷 | 监听方 | 触发条件 |
|------|--------|------|--------|----------|
| `map_generated` | ExplorationSystem | `(map_id: StringName, map_data: Dictionary)` | 探索 UI 系统 | DAG 生成完成 |
| `node_moved` | ExplorationSystem | `(from_node: int, to_node: int, ap_remaining: int)` | 探索 UI 系统、音频系统 | 节点移动完成 |
| `event_node_reached` | ExplorationSystem | `(map_pool: StringName, player_realm: int)` | EventSystem | 到达事件节点 |
| `combat_node_reached` | ExplorationSystem | `(enemy_roster: Array[Dictionary], combat_type: StringName)` | CombatSystem | 到达战斗/精英节点 |
| `boss_node_reached` | ExplorationSystem | `(boss_data: Dictionary)` | CombatSystem | 到达 Boss 节点 |
| `node_interaction_triggered` | ExplorationSystem | `(node_id: int, interaction_type: StringName, payload: Dictionary)` | 探索 UI 系统 | 到达商店/回复/灵泉/渡劫台/传送等非子系统委托节点——UI 根据 interaction_type 分发到对应面板 |
| `map_cleared` | ExplorationSystem | `(map_id: StringName, rewards: Dictionary, is_first_clear: bool)` | GSM、SaveLoadSystem、探索 UI 系统 | Boss 击败 |
| `exploration_ended` | ExplorationSystem | `(reason: StringName, summary: Dictionary)` | 探索 UI 系统 | 探索阶段结束 |
| `map_reentry_denied` | ExplorationSystem | `(map_id: StringName, reason: StringName)` | 探索 UI 系统 | 重入被拒绝 |

**委托流程（事件节点示例——遵循 ADR-0003 先例）：**

```
① 玩家移动到事件节点 → ExplorationSystem.move_to_node(node_id)
② move_to_node() 验证移动 → 消耗 AP → 更新 GSM exploration.node_position → 发射 node_moved
③ ExplorationSystem 检测 node_type == EVENT → 发射 event_node_reached(map_pool, player_realm)
④ EventSystem（监听器）→ select_event(map_pool, player_realm) → 弹出事件面板
⑤ UI 展示事件选项 → 玩家选择 → EventSystem 结算
⑥ EventSystem 发射 event_resolved(result)
⑦ ExplorationSystem（监听器）→ 恢复节点交互状态（玩家可继续移动）
```

**子系统直接调用（非信号——编排器模式）：**

| 调用 | 目标 | 场景 |
|------|------|------|
| `RealmSystem.get_realm_property()` | RealmSystem | 地图解锁验证、压制计算、行动力上限 |
| `RealmSystem.map_effective_realm()` | RealmSystem | 柔性压制计算 |
| `RealmSystem.get_rarity_weights()` | RealmSystem | 商店库存生成 |
| `CardSystem.get_template()` | CardSystem | 商店库存生成（卡牌池查询） |
| `CardSystem.create_instance()` | CardSystem | 卡牌奖励发放 |
| `GSM.exploration.*` | GSM | 运行时状态读写 |
| `GSM.add_resource()` | GSM | 灵石扣除（重入费） |
| `GSM.apply_battle_rewards()` | GSM | 通关奖励结算 |
| `SceneManager.request_scene_change()` | SceneManager | 战斗场景切换 |

### 决策 4：地图经济模型——三重安全阀

**地图重入经济遵循 GDD 公式 10（传送费 = base × multiplier）+ 公式 6（境界差额惩罚）+ 永久免费地图安全阀。探索系统自身执行经济计算，但灵石扣除通过 `GSM.add_resource()` 委托（遵循 ADR-0001 禁止模式——不绕过 GSM 直接操作资源）。**

**经济计算接口：**

```
# 重入费用判定（探索系统内部计算，不通过 GSM）
calculate_reentry_cost(map_id: StringName) → int:
  map_config = _get_map_config(map_id)
  map_state = GSM.exploration.map_states.get(map_id, {})
  entry_count = map_state.get("entry_count", 0)
  if _is_permanent_free_map(map_id): return 0
  if entry_count <= 1: return 0  # 首次进入免费
  base = REENTRY_BASE[map_difficulty]
  multiplier = min(1.0 + (entry_count - 2) * 0.5, 3.0)  # 硬上限 3.0x
  return floor(base * multiplier)

# 境界差额惩罚（→ RealmSystem）
calculate_realm_penalty(player_realm: int, map_max_realm: int) → float:
  return RealmSystem.map_effective_realm(player_realm, map_max_realm)
  # 返回 {offensive_lv, defensive_lv}——探索系统使用 defensive_lv 作为行动力上限

# 通关奖励计算（完整公式 5 + 6）
calculate_map_clear_rewards(map_id: StringName, is_first_clear: bool) → Dictionary:
  base = CLEAR_REWARDS[map_difficulty]  # {ling_shi: 50, cultivation: 50}
  penalty = calculate_realm_penalty(player_realm, map_max_realm)
  adjusted_ling_shi = floor(base.ling_shi * penalty.penalty_multiplier)
  rewards = {ling_shi: adjusted_ling_shi, cultivation: base.cultivation}
  if is_first_clear: rewards.extra = map_config.first_clear_reward
  return rewards
```

**永久免费地图列表（编译时常量）：**
```
const PERMANENT_FREE_MAPS = {
  "qing_yun_jian_zong": 1,   # 青云剑宗（炼气）
  "sui_xing_wai_huan": 2,    # 碎星外环（筑基）
  "xi_yu_gu_lin": 3,         # 西域古林（金丹）
  "mu_lan_cao_yuan": 4,      # 慕兰草原（元婴）
  "gui_xu_fu_yun_lu": 5,     # 归墟·浮云陆（化神）
}
```

### 决策 5：探索结束结算——战败/通关/行动力耗尽三种路径

**探索结束遵循 GDD §5 定义的三种结算路径。探索系统自身执行结算计算，然后通过 GSM 原子写入发放奖励。战败保留 50% 修为在 GSM 层处理（而非探索系统特殊处理）。**

```
end_exploration(reason: EndReason) → void:
  match reason:
    EndReason.BOSS_DEFEATED:
      rewards = calculate_map_clear_rewards(current_map, is_first_clear)
      GSM.apply_battle_rewards(rewards.ling_shi, rewards.cultivation, [])
      if is_first_clear and rewards.extra:
        _grant_first_clear_reward(rewards.extra)  # → CardSystem.create_instance()
      _mark_map_cleared(current_map)
      emit_signal("map_cleared", current_map, rewards, is_first_clear)

    EndReason.BATTLE_LOST:
      # 标准战败：灵石/卡牌/物品全额保留
      # _flush_map_state() 将 map_states[current_map] 中已收集的资源转移到 player.* 域
      _flush_map_state(current_map)  # → GSM.add_resource("ling_shi", collected) 等
      # 修为由 CultivationSystem 处理（保留 50%）
      # 不标记地图为通关
      summary = _build_exploration_summary()
      emit_signal("exploration_ended", "battle_lost", summary)

    EndReason.AP_DEPLETED:
      # 全额保留已收集资源
      _flush_map_state(current_map)  # → GSM.add_resource("ling_shi", collected) 等
      summary = _build_exploration_summary()
      emit_signal("exploration_ended", "ap_depleted", summary)

    EndReason.PLAYER_QUIT:
      # 全额保留已收集资源
      _flush_map_state(current_map)  # → GSM.add_resource("ling_shi", collected) 等（与 AP_DEPLETED 相同结算）
      summary = _build_exploration_summary()
      emit_signal("exploration_ended", "player_quit", summary)

  # 清理：释放内部缓存（_node_graph / _node_details / _reachable_cache / _shop_inventories）
  _clear_internal_state()
  # GSM exploration.* 域保留 map_states 用于下一地图继续——仅清除导航状态字段
  GSM.clear_exploration_navigation()

  # _flush_map_state(current_map) 的作用：将 map_states[current_map] 中收集的资源
  # 通过 GSM.add_resource() / GSM.add_cultivation() 写入 player.* 域，然后清除该 map_id 的 collected_* 字段。
  # 这确保地图间资源结算正确——每张地图的 collected_* 在结算后归零，entry_count + is_first_clear 保留。
```

### GSM 写入契约（ADR-0001 合规）

**ExplorationSystem 通过 GSM 第二层原子方法写入 `exploration.*` 域——绝不绕过 GSM 直接赋值。**

遵循 ADR-0008 的先例（CombatSystem 通过 `GSM._set_battle_phase()`、`GSM._increment_battle_turn()` 写入 `battle.*` 域），ExplorationSystem 通过以下 GSM 方法写入：

```
# === GSM 第二层：探索专用原子写入操作 ===

GSM.set_exploration_map(map_id: StringName) → void:
  # 设置 exploration.current_map + 重置 exploration.node_position 为入口
  # 发射 batch_updated({"exploration.current_map": {old, new}})

GSM.set_exploration_position(layer: int, idx: int) → void:
  # 更新 exploration.node_position
  # 发射 batch_updated({"exploration.node_position": {old, new}})

GSM.add_visited_node(node_id: int) → void:
  # 追加到 exploration.visited_nodes
  # 发射 batch_updated({"exploration.visited_nodes": {old_len, new_len}})

GSM.set_exploration_ap(current: int, max_ap: int) → void:
  # 设置 exploration.action_points + exploration.max_action_points
  # 发射 batch_updated({"exploration.action_points": {old, new}})

GSM.update_exploration_map_state(changes: Dictionary) → void:
  # 合并写入 exploration.map_state（entry_count、collected_* 等子字段）
  # 发射 batch_updated({"exploration.map_state.*": {old, new}})

GSM.clear_exploration_navigation() → void:
  # 清除导航状态字段（current_map、node_position、visited_nodes）
  # 保留 map_state（跨地图累计数据）
  # 在探索阶段结束时调用
```

> **注意**：上述伪代码中的 `GSM.exploration.current_map = map_id` 等直接属性写入选型是接口契约的概念性表述。实际实现必须通过上述 GSM 第二层方法——这确保 `batch_updated` 信号正确传播给 UI 消费者（HUD 行动力指示器、探索 UI 节点图），且写入在 GSM 语义围栏内受到保护（防止递归写入、_process() 写入检测）。

### 关键接口

```
# === 地图选择 ===
select_map(map_id: StringName) → MapSelectResult:
  # MapSelectResult = {success: bool, reason: String, cost: int}
  # 验证: 境界条件、灵石余额
  # 首次进入免费 → 直接生成地图
  # 重入 → 弹出确认（由 UI 处理确认流程，探索系统仅验证）
  # 永久免费地图 → 始终 0 费用

enter_map(map_id: StringName) → void:
  # 扣除灵石（如有费用）→ 生成 DAG → 更新 GSM exploration.*
  # → 发射 map_generated → 发射 node_moved(0, entry_node_id, max_ap)

# === 节点导航 ===
move_to_node(from_node: int, to_node: int) → MoveResult:
  # MoveResult = {success: bool, reason: String, ap_remaining: int}
  # 验证链路: 可达性 → 未访问 → 行动力足够 → 不是回退
  # AP=0 豁免: 传送节点、行动力泉、Boss 节点
  # 成功 → 更新 GSM exploration.node_position + visited_nodes
  #      → 消耗 AP → 触发节点交互 → 发射 node_moved / *_reached

can_move_to(from_node: int, to_node: int) → bool:
  # 只读查询函数——UI 在悬停/渲染时调用
  # 不修改任何状态——与 move_to_node() 分离（查询 vs 命令）

# === 地图查询 ===
get_map_list() → Array[Dictionary]:
  # 返回已解锁地图列表（从 RealmSystem + GSM exploration.map_state 合拢）
  # [{map_id, name, difficulty, is_cleared, is_unlocked, reentry_cost, is_permanent_free}]

get_map_status() → Dictionary:
  # 当前探索进度摘要——UI 状态面板数据源
  # {current_map, layer_progress, nodes_cleared, total_nodes, ap_remaining, collected_ling_shi, ...}

get_node_detail(node_id: int) → Dictionary:
  # 节点详情——UI 悬停 tooltip 数据源
  # {type, name, description, enemy_info (if combat), ...}

# === 对 GSM 的写入契约 ===
# ExplorationSystem 是 exploration.* 域的唯一运行时写入者（类似 CombatSystem 对 battle.* 的独占写入）
# 写入方法（通过 GSM 第二层——详见 §GSM 写入契约）:
#   GSM.set_exploration_map(map_id)
#   GSM.set_exploration_position(layer, idx)
#   GSM.add_visited_node(node_id)
#   GSM.set_exploration_ap(current, max_ap)
#   GSM.update_exploration_map_states(map_id, changes)
#   GSM.clear_exploration_navigation()
# 读取方法（GSM 第一层——只读）:
#   GSM.player.realm_level
#   GSM.collection.owned_cards
#   GSM.resources.ling_shi
#   GSM.exploration.*（导航状态——只读，由 ExplorationSystem 自己写入）
```

### 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                     探索系统架构                                  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  ExplorationSystem (Autoload #14)                           │ │
│  │                                                              │ │
│  │  地图选择层:                                                  │ │
│  │    select_map() → 验证境界/灵石 → enter_map()                 │ │
│  │    calculate_reentry_cost() → 经济计算（不通过GSM）           │ │
│  │                                                              │ │
│  │  DAG 生成层:                                                  │ │
│  │    generate_map() → 6 阶段程序化生成                          │ │
│  │    _weighted_random() → 加权随机节点类型                      │ │
│  │    _connect_edges() → 连通性保证 + ≥2 独立路径                │ │
│  │                                                              │ │
│  │  节点导航层:                                                  │ │
│  │    move_to_node() → 验证 → 消耗AP → 更新GSM → 触发交互       │ │
│  │    can_move_to() → 只读可达性查询（UI 渲染用）                │ │
│  │                                                              │ │
│  │  内部缓存(不持久化):        GSM exploration.* (持久化):        │ │
│  │    _node_graph               exploration.current_map          │ │
│  │    _node_details             exploration.node_position        │ │
│  │    _reachable_cache          exploration.visited_nodes        │ │
│  │    _shop_inventories         exploration.action_points        │ │
│  │    _map_config               exploration.max_action_points    │ │
│  │                              exploration.map_state            │ │
│  └──────────┬──────────────────────────────────────────────────┘ │
│             │                                                     │
│  ┌──────────┼──────────────────────────────────────────────────┐ │
│  │          ▼                信号委托 (Cat 2b)                  │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │ │
│  │  │  Event   │  │ Combat   │  │  Card/    │  │Tribute/AP/ │  │ │
│  │  │  System  │  │ System   │  │  Resource │  │Rest System │  │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │ │
│  │    事件节点       战斗/精英        商店节点      特殊节点      │ │
│  │                  /Boss节点                                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              直接方法调用（编排器模式）                       │ │
│  │  RealmSystem: map_unlock, realm_penalty, action_points       │ │
│  │  GSM: exploration.* 读写, add_resource, apply_battle_rewards │ │
│  │  SceneManager: request_scene_change (战斗场景切换)            │ │
│  │  CardSystem: create_instance (卡牌奖励发放)                   │ │
│  │  SaveLoadSystem: 不直接调用——通过 GSM 信号间接触发            │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

## 考虑的替代方案

### 替代方案 1：纯 GSM 驱动——ExplorationSystem 不作为 Autoload，所有逻辑内嵌在 GSM 中

- **描述**：探索逻辑作为 GSM 的方法集合——`GSM.generate_map()`、`GSM.move_to_node()`。所有状态天然在 GSM 中，无需同步。
- **优点**：无额外 Autoload——减少初始化链复杂度；状态与逻辑耦合为零——数据和方法在同一对象上
- **缺点**：GSM 膨胀为「上帝对象」——GSM 职责应是状态仲裁，而非游戏逻辑编排。GDD 探索逻辑 ~800 行伪代码 + DAG 生成算法——添加到 GSM 会使其违反单一职责原则。违反 ADR-0001 的设计意图（GSM 是数据层，非逻辑层）。探索 UI 系统无法独立于 GSM 测试——测试耦合度高
- **拒绝原因**：GSM 的三层 API 设计（ADR-0001）已明确其职责为数据仲裁——添加 DAG 生成、导航编排、经济计算会破坏此边界。探索系统的复杂性（15 个信号、6 阶段生成、3 种结算路径）需要一个独立模块。遵循 ADR-0008 的先例——战斗系统（Feature 层）作为 Autoload 编排 9 个子系统，而非嵌入 GSM

### 替代方案 2：内部注册表模型（遵循 ADR-0011/0013 先例）

- **描述**：ExplorationSystem 作为 Autoload + 内部 Dictionary 注册表存储 DAG、导航状态、地图选择状态。不通过 GSM 存储——仅在存档时或探索阶段结束时导出快照至 GSM。
- **优点**：与 ADR-0011（StatusEffectSystem）和 ADR-0013（BindingManager）的架构模式一致——内部 O(1) 查询、战斗结束 snapshot 导出。减少 GSM 的序列化/反序列化开销
- **缺点**：探索状态本身就是需要被存档的游戏状态——玩家期望中途存读档后恢复到同一节点。内部注册表模型要求每次存档前手动序列化，读档后手动重建——增加 SaveLoadSystem 的耦合。与 ADR-0001 注册表已声明的 `exploration.*` 域所有权矛盾
- **拒绝原因**：探索的导航状态与战斗中的状态实例有本质区别——前者是游戏进度（需要存档），后者是运行时中间态（不需要存档）。GSM-primary 模型简化了存档/读档——GSM.serialize() 自动包含探索状态，读档后通过现有 GSM 恢复管道自动恢复

### 替代方案 3：组件模式——非 Autoload，作为探索场景节点上的组件

- **描述**：ExplorationSystem 不是 Autoload，而是挂在探索场景根节点上的 `Node` 组件。探索场景加载时实例化，离开时销毁。所有状态存储在 GSM exploration.* 域中。
- **优点**：减轻 Autoload 链压力（不用增加第 14 个）。生命周期与探索场景绑定——场景退出时自动清理，无泄漏风险。遵循 Godot 场景驱动的惯用模式
- **缺点**：探索→战斗→探索往返时，组件在战斗场景中不存在——战斗结束后的回调需要特殊处理（通过 GSM 信号重新连接）。DAG 生成需要在每次进入探索场景时重新执行——如果玩家从战斗场景返回，内部缓存（_node_graph、_reachable_cache）已丢失。违反 ADR-0008 的先例——战斗系统作为 Autoload 在战斗场景之间保持状态
- **拒绝原因**：探索系统的「往返」特性（探索→战斗→探索→事件→探索）要求其在场景切换间保持内部缓存。组件模式每次切换场景都需重建 DAG 缓存（~5ms 生成 + 额外的节点内容填充）——不必要且影响转场流畅度。Autoload 模型确保 DAG 缓存跨场景存活——战斗结束返回时节点图立即可用

## 后果

### 积极的

- **清晰的职责边界**：ExplorationSystem（Autoload #14）负责地图生成、导航编排、经济计算。GSM 负责状态持久化。子系统通过信号接收委托——各司其职
- **存档/读档简化**：GSM-primary 模型使探索状态自动纳入 GSM.serialize() 管道——无需自定义序列化逻辑。读档后从 map_state 重建 DAG 缓存的复杂度可控（纯函数式重建）
- **程序化生成的可重播性**：独立 RNG 实例 + GSM.meta.seed 种子 → 同一 seed 产生同一地图。支持调试重播和回归测试
- **信号委托的统一性**：遵循 ADR-0003（事件委托）和 ADR-0008（战斗编排）的先例——所有子系统交互通过 Cat 2b 信号，无直接跨层依赖。新增节点类型只需添加新信号 + 新监听器
- **Autoload 定位清晰**：位置 #14——在 RealmSystem(#11) 之后（需要境界数据），在探索 UI 系统 ADR 之前（UI 依赖探索数据模型）
- **经济安全阀**：永久免费地图确保玩家始终有可进入的地图——防止「全通+灵石不足」的软锁状态

### 消极的

- **Autoload 数量增长**：第 14 个 Autoload——初始化顺序复杂度继续增长。但探索系统仅依赖 RealmSystem + GSM + EventSystem（3 个上游），初始化依赖链简洁
- **GSM exploration.* 域膨胀**：新增 `visited_nodes`（Array[int]）、`map_state`（Dictionary）等字段。但 GSM 按设计处理此类嵌套数据结构——整体序列化体积增加 <2KB
- **DAG 生成的确定性约束**：使用独立 RNG + GSM.meta.seed 意味着测试必须提供 seed 才能实现确定性——与 ADR-0009 PRDEngine 相同的约束。这是设计选择而非 bug
- **信号数量**：8 个 Cat 2b 信号——多于 CombatSystem（5 个）但少于 BindingManager（7 个拆分后的等效数量）。6 个仅面向探索 UI 的节点交互信号已合并为一个 `node_interaction_triggered` 信号（interaction_type 区分商店/回复/灵泉/渡劫台/传送）。与 ADR-0007 的载荷设计指南一致——当多个信号共享相同的消费者时，合并为单一信号 + 类型字段优于分散信号。

### 风险

- **R1 — DAG 生成边缘情况**：程序化生成可能产生极端布局——如所有战斗节点集中在一条路径上。缓解：后处理验证步骤检测节点类型分布偏差——如果某条路径上有 >70% 的战斗节点，重新分配
- **R2 — 存档兼容性**：新增 `exploration.*` 子字段时，旧存档缺少该字段。缓解：SaveLoadSystem 迁移链处理缺失字段——默认值填充（如 `visited_nodes: []`）
- **R3 — 读档后 DAG 重建失败**：如果 `map_state` 数据损坏或版本不匹配，DAG 重建可能失败。缓解：重建失败时——记录错误 → 强制结束当前探索（保留已收集资源）→ 返回地图选择界面。不阻塞主流程
- **R4 — 事件节点内容在到达时才确定的时序**：如果玩家到达事件节点后立即存档退出，读档后事件内容丢失（事件系统尚未分配到该节点）。缓解：在 `exploration.map_states[current_map]` 中存储事件池 ID + 随机种子，使读档后可以确定性地重新选择事件。在 `move_to_node()` 末尾检查当前节点是否为事件节点——如果是且事件尚未触发，将事件选择所需的上下文（`map_pool`, `rng_state`）写入 `map_states` 的 `pending_event_context` 字段，存档时自动持久化。读档后 ExplorationSystem 检测 `pending_event_context` 非空 → 重新触发事件选择。这保持了 SaveLoadSystem 的职责边界——它是不透明的状态序列化器，无需理解事件节点语义
- **R5 — 探索→战斗→探索往返的帧同步**：战斗场景退出后重新进入探索场景，GSM exploration.* 状态恢复——但 DAG 缓存（_node_graph 等）需要从 GSM 数据重建。缓解：在 `_ready()` 中检测 `GSM.exploration.current_map` 非空 → 触发 DAG 重建。与场景切换完全解耦——DAG 重建在探索场景 `_ready()` 之后、第一个 `_process()` 之前完成（<5ms）
- **R6 — Autoload 初始化顺序依赖**：ExplorationSystem 依赖 RealmSystem（查询 map_unlock）和 GSM（读写 exploration.*）。如果 RealmSystem 初始化滞后，探索系统 `_ready()` 时 realm_table 可能尚未就绪。缓解：不主动查询——探索系统在 `select_map()` 被 UI 调用时才查询境界数据。此时 RealmSystem 必然已就绪（因为 UI 在 RealmSystem 之后才能加载）

- **R7 — `_ready()` 中 DAG 重建与 UI 场景 `_ready()` 的竞态**：Godot 4.6 初始化序列为：所有 Autoload `_init()` → 所有 Autoload `_ready()` → 根场景 `_ready()` → 子节点 `_ready()`。如果 ExplorationSystem（Autoload #14）在 `_ready()` 中执行 DAG 重建（读档场景），且 UI 场景在其 `_ready()` 中立即调用 `select_map()`，则 DAG 缓存可能尚未就绪。缓解：ExplorationSystem 在 `_ready()` 末尾设置 `_dag_ready = true` 标志。所有公共入口方法（`select_map()`、`get_map_list()`）在 `_dag_ready == false` 时返回错误或排队等待。DAG 重建为同步操作（<5ms）——在 `_ready()` 完成前必然已结束——此标志保护边缘情况（如 UI Autoload `_ready()` 中的早期调用）

- **R8 — GDScript `const Dictionary` 内容可变性**：`const PERMANENT_FREE_MAPS`（Dictionary）的编译时不可变性仅保护变量绑定——Dictionary 内容在运行时仍可被修改（`PERMANENT_FREE_MAPS["new"] = 99` 编译通过且运行无错误）。GDScript 不提供真正的不可变 Dictionary。缓解：团队约定——不修改 `const Dictionary` 内容。GUT 冒烟测试验证永久免费地图列表完整性。与 ADR-0010（RealmSystem `const realm_table`）和 ADR-0011（`const Dictionary` 模板）的已确立模式一致

- **R9 — 信号链深度累积风险**：从 `event_node_reached` → `event_resolved` → `realm_changed`（如果事件奖励触发境界突破）→ `exploration.max_action_points` 更新 → 如果再发射信号则逼近 ADR-0007 的 4 层硬限制。缓解：已验证——最坏情况信号链为 3 层（`node_moved`[1] → `event_resolved`[2] → `save_completed`[3]），在限制范围内。`realm_changed` 由 GSM 发射（Cat 1）——不触发探索系统信号级联，仅触发内部状态重算

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| exploration-system.md | §1 地图选择——境界解锁、重入费用、永久免费地图 | select_map() + calculate_reentry_cost() + PERMANENT_FREE_MAPS 编译时常量——完整经济模型 |
| exploration-system.md | §2-3 节点图布局与生成——有向无环图、4-6 层、2-4 节点/层、≥2 独立路径 | generate_map() 6 阶段程序化生成——加权随机 + 后处理约束验证 |
| exploration-system.md | §4 节点导航——2 层可见性、不可回退、AP=0 豁免 | move_to_node() + can_move_to() 分离（命令 vs 查询）——完整验证链路 |
| exploration-system.md | §5 行动力限制与探索结束——3 种结算路径 | end_exploration() 统一结算入口——BOSS_DEFEATED / BATTLE_LOST / AP_DEPLETED / PLAYER_QUIT |
| exploration-system.md | §6 Boss 节点与地图通关——首次通关奖励、地图状态标记 | calculate_map_clear_rewards() + _mark_map_cleared()——经济公式 5 + 6 |
| exploration-system.md | §7 回旧地图——柔性压制、境界差额惩罚、卡牌池提升 | calculate_realm_penalty() → RealmSystem.map_effective_realm()——进攻压制/防御保留分离 |
| exploration-system.md | §8 地图初始解锁顺序——章节驱动的渐进式解锁 | get_map_list() 从 RealmSystem.get_realm_property() 查询 map_unlock——不硬编码序列 |
| exploration-system.md | §10 事件节点与事件系统的协作——信号架构 | event_node_reached 信号 → EventSystem 委托——遵循 ADR-0003 先例 |
| action-point-system.md | 行动力在 GSM exploration 域中的存储路径 | exploration.action_points / exploration.max_action_points——GSM 第二层写入 |
| action-point-system.md | 行动力变更通知（action_points_changed/depleted/refilled） | 通过 GSM batch_updated 信号传播——遵循 ADR-0007 Cat 1 数据变更通知 |
| realm-system.md | 行动力上限按境界查询 | 通过 RealmSystem.get_realm_property(L, "action_points") 查询——不重复定义数值 |
| combat-system.md | 战斗节点触发——combat_node_reached / boss_node_reached 信号 | Cat 2b 信号委托——CombatSystem 监听并编排战斗 |
| event-system.md | 事件节点触发——event_node_reached 信号 | Cat 2b 信号委托——EventSystem 监听并选择事件模板 |

## 性能影响
- **CPU**：DAG 生成在主线程执行——100-200 节点图 <5ms（含节点类型分配 + 边连接 + 后处理验证）。节点导航每次移动 O(1) 验证——无可感知的性能开销。总结：非热路径——仅在进入地图时一次性生成
- **内存**：DAG 内部缓存 `_node_graph` + `_node_details` + `_reachable_cache` + `_shop_inventories`——预计 50-100KB（100 节点 × ~1KB/节点详情）。GSM exploration.* 域序列化体积 <2KB。总结：内存影响可忽略
- **加载时间**：DAG 生成在 `enter_map()` 调用时执行——非启动时。不增加启动时间。地图加载动画（0.8s 节点展开）可完全覆盖生成时间
- **网络**：不适用（单机游戏）

## 迁移计划
本 ADR 为新建架构——无现有代码需迁移。实现顺序：
1. 在 project.godot 中注册 Autoload #14
2. 实现 DAG 生成核心（generate_map 6 阶段流程）
3. 实现节点导航（move_to_node + can_move_to）
4. 实现信号委托（13 个 Cat 2b 信号）
5. 实现经济计算（reentry_cost + realm_penalty 集成）
6. 实现 GSM exploration.* 读写接口
7. 实现存档/读档 DAG 重建
8. 在 EventSystem、CombatSystem 中实现信号监听（上游系统适配）
9. 探索 UI 系统集成（在 ADR-0015+ 中单独处理）

## 验证标准
- **GIVEN** 玩家选择已解锁地图，**WHEN** enter_map() 被调用，**THEN** DAG 生成完成且满足 ≥2 条独立路径到 Boss
- **GIVEN** 同一 seed + 同一 map_id，**WHEN** 两次调用 generate_map()，**THEN** 产生完全相同的 DAG 结构（确定性验证）
- **GIVEN** 玩家在节点图中移动，**WHEN** 行动力不足（AP <1 且非豁免节点），**THEN** move_to_node() 返回 false
- **GIVEN** 玩家到达事件节点，**WHEN** move_to_node() 完成，**THEN** event_node_reached 信号被发射且 EventSystem 响应
- **GIVEN** 玩家 Boss 战胜利，**WHEN** map_cleared 信号发射，**THEN** 通关奖励通过 GSM.apply_battle_rewards() 发放
- **GIVEN** 永久免费地图，**WHEN** 第 N 次进入，**THEN** calculate_reentry_cost() 返回 0
- **GIVEN** 探索中途存档，**WHEN** 读档后，**THEN** exploration.node_position 恢复到存档时的节点位置

## 相关决策
- ADR-0001：GSM 三层 API——exploration.* 域状态所有权基础
- ADR-0003：EventSystem 信号委托模式——探索事件委托的先例
- ADR-0005：SceneManager——探索/战斗场景切换
- ADR-0007：三分类信号体系——探索系统 Cat 2b 信号命名和路由
- ADR-0008：CombatSystem 7 阶段状态机——战斗节点委托目标
- ADR-0010：RealmSystem——map_unlock、行动力上限、柔性压制
- ADR-0011：StatusEffectSystem——GSM 例外模式的对比参考（本 ADR 采用 GSM-primary 而非内部注册表）
- ADR-0013：BindingManager——信号委托模式参考
