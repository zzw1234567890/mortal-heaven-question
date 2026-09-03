extends Node
## ExplorationSystem —— 探索系统 Autoload（ADR-0014 #19）。
##
## Feature 层 Autoload。程序化 DAG 地图生成 + 节点导航 + 子系统委托调度。[br]
## DAG 生成算法委托给 [ExplorationDAGBuilder]（RefCounted 子模块），[br]
## 经济计算委托给 [ExplorationEconomy]（RefCounted 子模块）。[br]
## [br][b]已注册进 project.godot[/b]——Autoload #19（ExplorationSystem）。[br]
## [br]来源: ADR-0014 §决策 2 程序化 DAG 生成 / GDD exploration-system.md §2-3。[br]
## [br]Sprint 8 Story 8-9：DAG 生成 + 经济计算拆分到子模块。


# === 枚举 ========================================================================

## 节点类型枚举——DAG 节点的类型标识。
enum NodeType {
	ENTRY = 0,         ## 入口——第 0 层固定
	COMBAT = 1,        ## 普通战斗
	ELITE = 2,         ## 精英战斗
	BOSS = 3,          ## Boss——末层固定
	EVENT = 4,         ## 事件
	SHOP = 5,          ## 商店
	TELEPORT = 6,      ## 传送——不消耗行动力
	ACTION_SPRING = 7, ## 行动力泉——回复全部行动力
	REST = 8,          ## 回复点——全体回复 50% 已损失 HP
	TRIBULATION = 9,   ## 渡劫台——修为已满时触发渡劫
}

## 地图难度枚举。
enum MapDifficulty {
	LOW = 0,       ## 低——4 层，2-3 节点/层
	MEDIUM = 1,    ## 中——5 层，2-4 节点/层
	HIGH = 2,      ## 高——5 层，3-4 节点/层
	VERY_HIGH = 3, ## 极高——6 层，3-4 节点/层
}

## 探索结束原因枚举。
enum EndReason {
	BOSS_DEFEATED,  ## Boss 击败——通关奖励结算
	BATTLE_LOST,    ## 战斗失败——修为保留 50%
	AP_DEPLETED,    ## 行动力耗尽——全额保留
	PLAYER_QUIT,    ## 玩家主动退出——全额保留
}


# === 内部状态 ====================================================================

## DAG 邻接表——{node_id: [child_ids]}。
var _node_graph: Dictionary = {}

## 节点详情——{node_id: {type, layer, idx, ...}}。
var _node_details: Dictionary = {}

## 可达性缓存——{node_id: bool}。
var _reachable_cache: Dictionary = {}

## 当前地图配置快照。
var _map_config: Dictionary = {}

## DAG 缓存就绪标志——_ready() 末尾设为 true，公共方法入口守卫（ADR-0014 R7）。
var _dag_ready: bool = false

## 独立 RNG 实例——确定性 DAG 生成。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 可注入回调——获取地图配置（桩阶段返回默认配置）。
var get_map_config_cb: Callable = Callable()

## 可注入回调——生成敌人阵容（桩阶段返回空 Array）。
var generate_enemy_roster_cb: Callable = Callable()

## 可注入回调——获取事件池（桩阶段返回空 Array）。
var get_event_pool_cb: Callable = Callable()

## 可注入回调——生成商店库存（桩阶段返回空 Dictionary）。
var generate_shop_inventory_cb: Callable = Callable()

## 可注入回调——获取 RNG seed（桩阶段返回 42）。
var get_seed_cb: Callable = Callable()


# === 常量（保留在主文件——测试通过 es.get 访问）==============================

## 默认地图难度配置表——按 MapDifficulty 枚举索引。
const DIFFICULTY_CONFIGS: Array = [
	{  # LOW
		"layers": 4, "min_nodes": 2, "max_nodes": 3,
		"elite_count": 1, "shop_count": 1, "event_count": 2,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5},
	},
	{  # MEDIUM
		"layers": 5, "min_nodes": 2, "max_nodes": 4,
		"elite_count": 2, "shop_count": 1, "event_count": 3,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5},
	},
	{  # HIGH
		"layers": 5, "min_nodes": 3, "max_nodes": 4,
		"elite_count": 2, "shop_count": 2, "event_count": 3,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5},
	},
	{  # VERY_HIGH
		"layers": 6, "min_nodes": 3, "max_nodes": 4,
		"elite_count": 3, "shop_count": 2, "event_count": 4,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5},
	},
]

## AP=0 豁免节点类型集合——不消耗行动力且行动力不足时仍可移动。
const AP_EXEMPT_TYPES: Array = [NodeType.TELEPORT, NodeType.ACTION_SPRING, NodeType.BOSS]

## 永久免费地图列表——每个境界 1 张，重入始终免费（GDD §1 经济安全阀）。
const PERMANENT_FREE_MAPS: Dictionary = {
	&"qing_yun_jian_zong": 1,   # 青云剑宗（炼气）
	&"sui_xing_wai_huan": 2,    # 碎星外环（筑基）
	&"xi_yu_gu_lin": 3,         # 西域古林（金丹）
	&"mu_lan_cao_yuan": 4,      # 慕兰草原（元婴）
	&"gui_xu_fu_yun_lu": 5,     # 归墟·浮云陆（化神）
}

## 重入费用基价表——按 MapDifficulty 枚举索引（GDD §公式 10）。
const REENTRY_BASE_COSTS: Array = [30, 60, 100, 150]  # LOW/MEDIUM/HIGH/VERY_HIGH

## 通关奖励基价表——按 MapDifficulty 枚举索引（GDD §公式 5）。
const CLEAR_REWARDS: Array = [
	{"ling_shi": 50,  "cultivation": 50},   # LOW
	{"ling_shi": 100, "cultivation": 80},   # MEDIUM
	{"ling_shi": 200, "cultivation": 120},  # HIGH
	{"ling_shi": 300, "cultivation": 150},  # VERY_HIGH
]


# === 子模块实例 ===================================================================

## DAG 生成器子模块。
var _dag_builder: RefCounted = null

## 经济计算子模块。
var _economy: RefCounted = null


# === DAG 生成（委托给 ExplorationDAGBuilder）===================================

## 程序化生成 DAG 地图——委托给 _dag_builder 子模块。[br]
## [br][param map_id] 地图 ID。[br]
## [br][param player_realm] 玩家境界等级。[br]
## [br][param entry_count] 本局该地图进入次数。[br]
## [br][b]返回[/b]: [code]{graph, nodes, layers, boss_node_id, path_count}[/code] Dictionary。
func generate_map(map_id: StringName, player_realm: int = 1, entry_count: int = 1) -> Dictionary:
	return _get_dag_builder().generate_map(map_id, player_realm, entry_count)


# === 节点导航（Story 003）=====================================================

## Cat 2b 信号——探索结束（ADR-0014 §决策 5）。
signal exploration_ended(reason: int, summary: Dictionary)

## Cat 2b 信号——节点移动完成（ADR-0007 / ADR-0014 §决策 3）。
signal node_moved(from_node: int, to_node: int, ap_remaining: int)

## Cat 2b 信号——到达事件节点，委托 EventSystem（ADR-0014 §决策 3）。
signal event_node_reached(map_pool: Array, player_realm: int)

## Cat 2b 信号——到达战斗/精英节点，委托 CombatSystem（ADR-0014 §决策 3）。
signal combat_node_reached(enemy_roster: Array, combat_type: StringName)

## Cat 2b 信号——到达 Boss 节点，委托 CombatSystem（ADR-0014 §决策 3）。
signal boss_node_reached(boss_data: Dictionary)

## Cat 2b 信号——到达商店/回复/灵泉/渡劫台/传送节点，UI 按 interaction_type 分发（ADR-0014 §决策 3）。
signal node_interaction_triggered(node_id: int, interaction_type: StringName, payload: Dictionary)

## 节点导航——从 from_node 移动到 to_node。[br]
## [br][b]验证链路[/b]（短路求值）：可达性 → 已访问 → 行动力。[br]
## [br][b]AP=0 豁免[/b]：传送/行动力泉/Boss 节点不消耗 AP，行动力不足时仍可移动。[br]
## [br][b]成功后[/b]：更新 GSM 导航状态 → 消耗 AP → 发射 node_moved → 调用 resolve_node。[br]
## [br][param from_node] 起始节点 ID。[br]
## [br][param to_node] 目标节点 ID。[br]
## [br][b]返回[/b]: [code]{success: bool, reason: String, ap_remaining: int}[/code] Dictionary。[br]
## [br]来源: ADR-0014 §关键接口 + GDD §4 节点导航。
func move_to_node(from_node: int, to_node: int) -> Dictionary:
	var result: Dictionary = {"success": false, "reason": "", "ap_remaining": 0}

	# _dag_ready 守卫（ADR-0014 R7）
	if not _dag_ready:
		result["reason"] = "DAG 缓存未就绪"
		return result

	# 验证 1：可达性——graph[from] 包含 to
	if not _is_reachable(from_node, to_node):
		result["reason"] = "不可达"
		return result

	# 验证 2：已访问——不可回退到已访问节点
	var gsm: Node = _get_gsm()
	if gsm == null:
		result["reason"] = "GSM 不可用"
		return result
	var visited: Array = gsm.exploration.get("visited_nodes", [])
	if visited.has(to_node):
		result["reason"] = "已访问"
		return result

	# 验证 3：行动力——非豁免节点 AP 不足时拒绝
	var ap: int = int(gsm.exploration.get("action_points", 0))
	var to_type: int = _get_node_type(to_node)
	var is_exempt: bool = AP_EXEMPT_TYPES.has(to_type)
	if ap < 1 and not is_exempt:
		result["reason"] = "行动力不足"
		return result

	# 验证通过——执行移动
	var ap_cost: int = 1
	if is_exempt:
		ap_cost = 0
	var new_ap: int = ap - ap_cost

	# 更新 GSM 导航状态（通过第二层方法——ADR-0014 §GSM 写入契约）
	var to_layer: int = to_node / 100
	var to_idx: int = to_node % 100
	gsm.set_exploration_position(to_layer, to_idx)
	gsm.add_visited_node(to_node)
	gsm.set_exploration_ap(new_ap, int(gsm.exploration.get("max_action_points", 0)))

	result["success"] = true
	result["ap_remaining"] = new_ap

	# 发射 node_moved Cat 2b 信号
	_emit_safe(&"node_moved", [from_node, to_node, new_ap])

	# 自动调用 resolve_node 触发节点交互
	resolve_node(to_node)

	return result


## 只读查询——验证从 from_node 是否可移动到 to_node。[br]
## [br][b]不修改任何状态[/b]——与 move_to_node() 分离（查询 vs 命令，ADR-0014 §关键接口）。[br]
## [br][param from_node] 起始节点 ID。[br]
## [br][param to_node] 目标节点 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 可移动，[code]false[/code] 不可移动。[br]
## [br]来源: ADR-0014 §关键接口 can_move_to。
func can_move_to(from_node: int, to_node: int) -> bool:
	# _dag_ready 守卫（ADR-0014 R7）
	if not _dag_ready:
		return false
	if not _is_reachable(from_node, to_node):
		return false
	var gsm: Node = _get_gsm()
	if gsm == null:
		return false
	var visited: Array = gsm.exploration.get("visited_nodes", [])
	if visited.has(to_node):
		return false
	var ap: int = int(gsm.exploration.get("action_points", 0))
	var to_type: int = _get_node_type(to_node)
	var is_exempt: bool = AP_EXEMPT_TYPES.has(to_type)
	if ap < 1 and not is_exempt:
		return false
	return true


## 节点交互分发——按节点类型发射 Cat 2b 委托信号。[br]
## [br][param node_id] 节点 ID。[br]
## [br][b]分发规则[/b]（ADR-0014 §决策 3）:[br]
## [br]EVENT → event_node_reached(map_pool, player_realm)[br]
## [br]COMBAT/ELITE → combat_node_reached(enemy_roster, combat_type)[br]
## [br]BOSS → boss_node_reached(boss_data)[br]
## [br]SHOP/REST/ACTION_SPRING/TELEPORT/TRIBULATION → node_interaction_triggered(node_id, type, payload)[br]
## [br]来源: ADR-0014 §决策 3 信号驱动子系统委托。
func resolve_node(node_id: int) -> void:
	# _dag_ready 守卫（ADR-0014 R7）
	if not _dag_ready:
		push_warning("ExplorationSystem.resolve_node: DAG 缓存未就绪，跳过节点交互")
		return
	var ntype: int = _get_node_type(node_id)
	var detail: Dictionary = _node_details.get(node_id, {})
	var gsm: Node = _get_gsm()
	var player_realm: int = 1
	if gsm != null:
		player_realm = int(gsm.player.get("realm", 1))

	match ntype:
		NodeType.EVENT:
			var map_pool: Array = detail.get("event_pool", [])
			_emit_safe(&"event_node_reached", [map_pool, player_realm])
		NodeType.COMBAT:
			var roster: Array = detail.get("enemy_roster", [])
			_emit_safe(&"combat_node_reached", [roster, &"combat"])
		NodeType.ELITE:
			var roster_elite: Array = detail.get("enemy_roster", [])
			_emit_safe(&"combat_node_reached", [roster_elite, &"elite"])
		NodeType.BOSS:
			var boss_data: Dictionary = {"node_id": node_id, "enemy_roster": detail.get("enemy_roster", [])}
			_emit_safe(&"boss_node_reached", [boss_data])
		NodeType.SHOP:
			var payload: Dictionary = {"inventory": detail.get("inventory", {})}
			_emit_safe(&"node_interaction_triggered", [node_id, &"shop", payload])
		NodeType.REST:
			_emit_safe(&"node_interaction_triggered", [node_id, &"rest", {}])
		NodeType.ACTION_SPRING:
			_emit_safe(&"node_interaction_triggered", [node_id, &"action_spring", {}])
		NodeType.TELEPORT:
			_emit_safe(&"node_interaction_triggered", [node_id, &"teleport", {}])
		NodeType.TRIBULATION:
			_emit_safe(&"node_interaction_triggered", [node_id, &"tribulation", {}])
		NodeType.ENTRY:
			pass  # 入口无交互


## 检查 from→to 是否邻接（graph[from] 包含 to）。
func _is_reachable(from_node: int, to_node: int) -> bool:
	if not _node_graph.has(from_node):
		return false
	return _node_graph[from_node].has(to_node)


## 获取节点类型——从 _node_details 读取。
func _get_node_type(node_id: int) -> int:
	var detail: Dictionary = _node_details.get(node_id, {})
	return int(detail.get("type", NodeType.COMBAT))


## 通过 GSM._emit_signal_safe 路由 Cat 2b 信号（ADR-0007）。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var gsm: Node = _get_gsm()
	if gsm != null and gsm.has_method("_emit_signal_safe"):
		gsm._emit_signal_safe(self, signal_name, args)
		return
	push_warning("ExplorationSystem: GSM 不可用，%s 信号绕过 _emit_signal_safe 路由" % signal_name)
	var call_args: Array = [signal_name]
	call_args.append_array(args)
	callv("emit_signal", call_args)


# === 导航状态 GSM 主存储（Story 002）===========================================

## 进入地图——生成 DAG + 初始化 GSM exploration.* 导航状态。[br]
## [br][param map_id] 地图 ID。[br]
## [br][param player_realm] 玩家境界等级。[br]
## [br][param max_ap] 行动力上限（由 RealmSystem 查询，此处由调用方传入）。[br]
## [br][b]流程[/b]：generate_map → set_exploration_map → set_exploration_ap → update_exploration_map_state(entry_count++)。[br]
## [br][b]返回[/b]: generate_map 返回的图结构 Dictionary。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型 + §GSM 写入契约。
func enter_map(map_id: StringName, player_realm: int = 1, max_ap: int = 10) -> Dictionary:
	var map_data: Dictionary = generate_map(map_id, player_realm, _get_entry_count(map_id))

	# generate_map 已填充 _node_graph / _node_details / _map_config——缓存就绪
	_dag_ready = true

	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("ExplorationSystem.enter_map: GSM 不可用，导航状态未写入")
		return map_data

	# 写入导航状态——通过 GSM 第二层原子方法（ADR-0014 §GSM 写入契约）
	gsm.set_exploration_map(map_id)
	gsm.set_exploration_ap(max_ap, max_ap)

	# 递增 entry_count + 缓存 DAG 快照到 map_states（供读档后重建）
	var entry_count: int = _get_entry_count(map_id) + 1
	gsm.update_exploration_map_state(map_id, {
		"entry_count": entry_count,
		"graph": map_data["graph"],
		"nodes": map_data["nodes"],
	})

	return map_data


# === DAG 缓存重建（Story 004）=================================================

## Autoload 就绪——检测读档后是否有活跃地图，重建 DAG 缓存。[br]
## [br][b]流程[/b]（ADR-0014 §决策 1 状态分层模型 + R7）:[br]
## [br]1. 检测 GSM.exploration.current_map 非空[br]
## [br]2. 非空 → 从 map_states 读取 graph/nodes 快照 → rebuild_dag_cache[br]
## [br]3. 为空 → 跳过重建[br]
## [br]4. 末尾设 _dag_ready = true（保护 UI 早期调用）[br]
## [br]来源: ADR-0014 §决策 1 + R7。
func _ready() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		_dag_ready = true
		return

	var current_map: StringName = gsm.exploration.get("current_map", &"")
	if current_map != &"" and not str(current_map).is_empty():
		# 读档后重建——从 map_states 读取 graph/nodes 快照
		var map_states: Dictionary = gsm.exploration.get("map_states", {})
		var state: Dictionary = map_states.get(current_map, {})
		if state.has("graph") and state.has("nodes"):
			var map_data: Dictionary = {
				"graph": state["graph"],
				"nodes": state["nodes"],
				"layers": state.get("layers", []),
				"boss_node_id": state.get("boss_node_id", 0),
				"path_count": state.get("path_count", 0),
			}
			rebuild_dag_cache(current_map, map_data)
		else:
			push_warning("ExplorationSystem._ready: current_map=%s 但 map_states 无 graph/nodes 快照" % current_map)

	_dag_ready = true


## 从已有数据重建 DAG 缓存——不重新生成，直接填充内部成员。[br]
## [br][param map_id] 地图 ID。[br]
## [br][param map_data] 含 graph/nodes/layers/boss_node_id/path_count 的 Dictionary。[br]
## [br][b]用途[/b]：读档后从 map_states 快照重建 + 探索→战斗→探索往返恢复。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func rebuild_dag_cache(map_id: StringName, map_data: Dictionary) -> void:
	_node_graph = (map_data.get("graph", {}) as Dictionary).duplicate(true)
	_node_details = (map_data.get("nodes", {}) as Dictionary).duplicate(true)
	_map_config = {}
	_dag_ready = true


## 清理 DAG 缓存——重置所有内部状态。[br]
## [br][b]用途[/b]：end_exploration 后清理 + 测试清理。[br]
## [br]来源: ADR-0014 §决策 5 探索结束结算。
func clear_dag_cache() -> void:
	_node_graph.clear()
	_node_details.clear()
	_reachable_cache.clear()
	_map_config.clear()
	_dag_ready = false


## 获取当前地图的进入次数——从 GSM exploration.map_states 读取。[br]
## [br][param map_id] 地图 ID。[br]
## [br][b]返回[/b]: 进入次数（0 表示从未进入）。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func _get_entry_count(map_id: StringName) -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 0
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(map_id, {})
	return int(state.get("entry_count", 0))


## 获取 GSM 引用——通过 SceneTree Autoload。[br]
## [br][b]返回[/b]: GSM 节点或 null（未注册时）。[br]
## [br]来源: ADR-0014 §决策 1 ExplorationSystem 作为 Autoload。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 获取地图配置——优先注入回调，回退到难度配置表。
func _get_map_config(map_id: StringName, player_realm: int) -> Dictionary:
	if get_map_config_cb.is_valid():
		var cfg = get_map_config_cb.call(map_id, player_realm)
		if cfg is Dictionary and not cfg.is_empty():
			return cfg
	# 回退：默认中难度配置
	var difficulty: int = int(player_realm) - 1
	if difficulty < 0 or difficulty >= DIFFICULTY_CONFIGS.size():
		difficulty = 1  # MEDIUM
	return DIFFICULTY_CONFIGS[difficulty]


## 获取 RNG seed——优先注入回调，回退到默认 42。
func _get_seed() -> int:
	if get_seed_cb.is_valid():
		return int(get_seed_cb.call())
	return 42


# === 测试桩 API ==================================================================

## 设置 RNG seed（确定性测试用）。
func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value

## 返回当前 DAG 图（测试桩）。
func get_node_graph() -> Dictionary:
	return _node_graph

## 返回当前节点详情（测试桩）。
func get_node_details() -> Dictionary:
	return _node_details


# === 经济计算（委托给 ExplorationEconomy）=======================================

## 计算地图重入传送费——委托给 _economy 子模块。
func calculate_reentry_cost(map_id: StringName) -> int:
	return _get_economy().calculate_reentry_cost(map_id)


## 计算地图通关奖励——委托给 _economy 子模块。
func calculate_map_clear_rewards(map_id: StringName, is_first_clear: bool, player_realm: int, map_max_realm: int) -> Dictionary:
	return _get_economy().calculate_map_clear_rewards(map_id, is_first_clear, player_realm, map_max_realm)


## 境界差额惩罚系数——委托给 _economy 子模块。
func realm_gap_penalty(player_L: int, map_max_L: int) -> float:
	return _get_economy().realm_gap_penalty(player_L, map_max_L)


## 收集资源——累积到 map_states[current_map].collected_*。[br]
## [br][param resource_type] 资源类型（"ling_shi" / "cultivation" / "cards"）。[br]
## [br][param amount] 数量。[br]
## [br][b]不直接写入 GSM player.* 域[/b]——仅累积到 map_states，结算时 _flush_map_state 转移。[br]
## [br]来源: ADR-0014 §决策 5 探索结束结算。
func collect_resource(resource_type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("ExplorationSystem.collect_resource: GSM 不可用")
		return
	var current_map: StringName = gsm.exploration.get("current_map", &"")
	if current_map == &"" or str(current_map).is_empty():
		push_warning("ExplorationSystem.collect_resource: 无活跃地图")
		return
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(current_map, {})
	var key_str: String = "collected_" + str(resource_type)
	var current_val: int = int(state.get(key_str, 0))
	# 通过 update_exploration_map_state 传增量字典——不直接修改 GSM 内部引用（H-1 修复）
	gsm.update_exploration_map_state(current_map, {key_str: current_val + amount})


## 将 map_states[map_id] 中的 collected_* 转移到 GSM player.* 域。[br]
## [br][param map_id] 地图 ID。[br]
## [br][b]流程[/b]: 读取 collected_ling_shi / collected_cultivation → GSM 原子写入 → 清零 collected_*。[br]
## [br]来源: ADR-0014 §决策 5 探索结束结算。
func _flush_map_state(map_id: StringName) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(map_id, {})
	var changes: Dictionary = {}
	# 转移灵石
	var collected_ls: int = int(state.get("collected_ling_shi", 0))
	if collected_ls > 0:
		var current_ls: int = int(gsm.player.resources.get("ling_shi", 0))
		gsm._set_resource_ling_shi(current_ls + collected_ls)
		changes["collected_ling_shi"] = 0
	# 转移修为
	var collected_cult: int = int(state.get("collected_cultivation", 0))
	if collected_cult > 0:
		gsm.add_cultivation(collected_cult, "exploration_flush")
		changes["collected_cultivation"] = 0
	# 回写清零后的 state——传增量字典（H-1 修复：不直接修改 GSM 内部引用）
	if not changes.is_empty():
		gsm.update_exploration_map_state(map_id, changes)


## 探索结束结算——三种路径（GDD §公式 11 + ADR-0014 §决策 5）。[br]
## [br][param reason] 结束原因（EndReason 枚举）。[br]
## [br][b]结算路径[/b]:[br]
## [br]BOSS_DEFEATED → 通关奖励 + collected_* 全额转移[br]
## [br]BATTLE_LOST → collected_ling_shi 全额转移，collected_cultivation 保留 50%[br]
## [br]AP_DEPLETED / PLAYER_QUIT → collected_* 全额转移[br]
## [br][b]流程[/b]: _flush_map_state → clear_exploration_navigation → clear_dag_cache。[br]
## [br]来源: ADR-0014 §决策 5 + GDD §公式 11。
func end_exploration(reason: int) -> Dictionary:
	var gsm: Node = _get_gsm()
	var summary: Dictionary = {"reason": reason, "rewards": {}}
	if gsm == null:
		push_warning("ExplorationSystem.end_exploration: GSM 不可用")
		return summary
	var current_map: StringName = gsm.exploration.get("current_map", &"")
	if current_map == &"" or str(current_map).is_empty():
		push_warning("ExplorationSystem.end_exploration: 无活跃地图")
		return summary

	match reason:
		EndReason.BOSS_DEFEATED:
			# 通关奖励
			var is_first: bool = not _is_map_cleared(current_map)
			var player_realm: int = _get_player_realm()
			var map_max_realm: int = _get_map_max_realm(current_map)
			var rewards: Dictionary = calculate_map_clear_rewards(current_map, is_first, player_realm, map_max_realm)
			summary["rewards"] = rewards
			# 发放通关奖励
			if rewards.has("ling_shi") and rewards["ling_shi"] > 0:
				var current_ls: int = int(gsm.player.resources.get("ling_shi", 0))
				gsm._set_resource_ling_shi(current_ls + rewards["ling_shi"])
			if rewards.has("cultivation") and rewards["cultivation"] > 0:
				gsm.add_cultivation(rewards["cultivation"], "map_clear")
			# 标记地图通关
			_mark_map_cleared(current_map)
			# 转移已收集资源
			_flush_map_state(current_map)
		EndReason.BATTLE_LOST:
			# 灵石全额保留，修为保留 50%
			_flush_map_state_half_cultivation(current_map)
		EndReason.AP_DEPLETED, EndReason.PLAYER_QUIT:
			# 全额保留已收集资源
			_flush_map_state(current_map)

	# 清理导航状态 + DAG 缓存
	gsm.clear_exploration_navigation()
	clear_dag_cache()

	# 发射探索结束信号
	_emit_safe(&"exploration_ended", [reason, summary])

	return summary


## 战败结算——灵石全额，修为保留 50%（GDD §公式 11）。
func _flush_map_state_half_cultivation(map_id: StringName) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(map_id, {})
	var changes: Dictionary = {}
	# 灵石全额
	var collected_ls: int = int(state.get("collected_ling_shi", 0))
	if collected_ls > 0:
		var current_ls: int = int(gsm.player.resources.get("ling_shi", 0))
		gsm._set_resource_ling_shi(current_ls + collected_ls)
		changes["collected_ling_shi"] = 0
	# 修为保留 50%
	var collected_cult: int = int(state.get("collected_cultivation", 0))
	if collected_cult > 0:
		var retained: int = int(floor(collected_cult * 0.5))
		if retained > 0:
			gsm.add_cultivation(retained, "battle_lost_half")
		changes["collected_cultivation"] = 0
	# 回写清零后的 state——传增量字典（H-1 修复：不直接修改 GSM 内部引用）
	if not changes.is_empty():
		gsm.update_exploration_map_state(map_id, changes)


## 检查地图是否已通关——从 map_states 读取 is_first_clear。
func _is_map_cleared(map_id: StringName) -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return false
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(map_id, {})
	return bool(state.get("is_first_clear", false))


## 标记地图通关——写入 is_first_clear=true。
func _mark_map_cleared(map_id: StringName) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	gsm.update_exploration_map_state(map_id, {"is_first_clear": true})


## 获取玩家境界——从 GSM player.realm 读取。
func _get_player_realm() -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 1
	return int(gsm.player.get("realm", 1))


## 获取地图最高允许境界——从 PERMANENT_FREE_MAPS 或配置读取。
func _get_map_max_realm(map_id: StringName) -> int:
	if PERMANENT_FREE_MAPS.has(map_id):
		return int(PERMANENT_FREE_MAPS[map_id])
	var config: Dictionary = _get_map_config(map_id, _get_player_realm())
	return int(config.get("max_realm", 1))


# === 子模块获取（惰性初始化）===================================================

## 获取 DAG 生成器子模块实例。
func _get_dag_builder() -> RefCounted:
	if _dag_builder == null:
		_dag_builder = preload("res://src/feature/exploration/exploration_dag_builder.gd").new(self)
	return _dag_builder


## 获取经济计算子模块实例。
func _get_economy() -> RefCounted:
	if _economy == null:
		_economy = preload("res://src/feature/exploration/exploration_economy.gd").new(self)
	return _economy
