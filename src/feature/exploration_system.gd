extends Node
## ExplorationSystem —— 探索系统 Autoload（ADR-0014 #14）。
##
## Feature 层 Autoload。程序化 DAG 地图生成 + 节点导航 + 子系统委托调度。[br]
## 本文件持有 [method generate_map] 程序化 DAG 生成 + 地图难度配置 + 加权随机分配 +
## 边连接连通性保证 + 独立路径验证。[br]
## [br][b]本 Story 范围[/b]（5-1）：纯 DAG 生成逻辑——不写入 GSM、不处理导航、不触发事件。[br]
## [b]不注册进 project.godot[/b]——待各系统接线后统一注册（5-0b 终验）。[br]
## [br]来源: ADR-0014 §决策 2 程序化 DAG 生成 / GDD exploration-system.md §2-3。


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


# === 内部状态 ====================================================================

## DAG 邻接表——{node_id: [child_ids]}。
var _node_graph: Dictionary = {}

## 节点详情——{node_id: {type, layer, idx, ...}}。
var _node_details: Dictionary = {}

## 可达性缓存——{node_id: bool}。
var _reachable_cache: Dictionary = {}

## 当前地图配置快照。
var _map_config: Dictionary = {}

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


# === 地图难度配置 =================================================================

## 默认地图难度配置表——按 MapDifficulty 枚举索引。
## 每项含 layers / min_nodes / max_nodes / elite_count / shop_count / event_count / weights。
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


# === DAG 生成（Story 001）=======================================================

## 程序化生成 DAG 地图——加权随机分配 + 确定性边连接 + 后处理约束验证。[br]
## [br][param map_id] 地图 ID（用于 seed 计算）。[br]
## [br][param player_realm] 玩家境界等级（用于配置衍生）。[br]
## [br][param entry_count] 本局该地图进入次数（用于 seed 计算）。[br]
## [br][b]返回[/b]: [code]{graph, nodes, layers, boss_node_id, path_count}[/code] Dictionary。[br]
## [br]来源: ADR-0014 §决策 2 / GDD §3。
func generate_map(map_id: StringName, player_realm: int = 1, entry_count: int = 1) -> Dictionary:
	# Phase 1：读取配置
	var config: Dictionary = _get_map_config(map_id, player_realm)

	# 初始化 RNG——seed = base_seed XOR map_id.hash() XOR entry_count
	var base_seed: int = _get_seed()
	var map_hash: int = hash(map_id)
	_rng.seed = base_seed ^ map_hash ^ entry_count

	# Phase 2：生成 DAG 骨架
	var total_layers: int = int(config.get("layers", 5))
	var min_n: int = int(config.get("min_nodes", 2))
	var max_n: int = int(config.get("max_nodes", 4))
	var nodes_per_layer: Array = []
	for i in range(total_layers):
		if i == 0 or i == total_layers - 1:
			nodes_per_layer.append(1)
		else:
			nodes_per_layer.append(_rng.randi_range(min_n, max_n))

	# 生成节点 ID——格式: layer * 100 + idx
	var all_nodes: Array = []
	for layer in range(total_layers):
		for idx in range(nodes_per_layer[layer]):
			all_nodes.append(layer * 100 + idx)

	# Phase 3：分配节点类型
	var node_types: Dictionary = _assign_node_types(all_nodes, nodes_per_layer, config, total_layers)

	# Phase 4：边连接 + 连通性验证 + ≥2 独立路径（迭代重试，不递归——避免栈下溢）
	var graph: Dictionary = _build_edges(all_nodes, nodes_per_layer, total_layers)
	var sink_id: int = all_nodes[all_nodes.size() - 1]
	var path_count: int = _count_vertex_disjoint_paths(graph, 0, sink_id)

	# 独立路径不足时先添加交叉边（最多 2 次）
	var cross_retry: int = 0
	while path_count < 2 and cross_retry < 2:
		_add_cross_edges(graph, nodes_per_layer, total_layers)
		path_count = _count_vertex_disjoint_paths(graph, 0, sink_id)
		cross_retry += 1

	# 仍不足时整体重新生成（最多 2 次，迭代而非递归）
	var regen_retry: int = 0
	while path_count < 2 and regen_retry < 2:
		regen_retry += 1
		# 重置 RNG seed 并加扰重试计数，避免相同图重复生成
		_rng.seed = (base_seed ^ map_hash ^ entry_count) + regen_retry
		nodes_per_layer = []
		for i in range(total_layers):
			if i == 0 or i == total_layers - 1:
				nodes_per_layer.append(1)
			else:
				nodes_per_layer.append(_rng.randi_range(min_n, max_n))
		all_nodes = []
		for layer in range(total_layers):
			for idx in range(nodes_per_layer[layer]):
				all_nodes.append(layer * 100 + idx)
		node_types = _assign_node_types(all_nodes, nodes_per_layer, config, total_layers)
		graph = _build_edges(all_nodes, nodes_per_layer, total_layers)
		sink_id = all_nodes[all_nodes.size() - 1]
		path_count = _count_vertex_disjoint_paths(graph, 0, sink_id)
		cross_retry = 0
		while path_count < 2 and cross_retry < 2:
			_add_cross_edges(graph, nodes_per_layer, total_layers)
			path_count = _count_vertex_disjoint_paths(graph, 0, sink_id)
			cross_retry += 1
	if path_count < 2:
		push_warning("ExplorationSystem: map %s path_count=%d < 2 after retries" % [map_id, path_count])

	# Phase 5：填充节点内容
	var node_details: Dictionary = _fill_node_content(all_nodes, node_types, nodes_per_layer, total_layers, map_id, player_realm)

	# Phase 6：返回图结构
	_node_graph = graph.duplicate(true)
	_node_details = node_details.duplicate(true)
	_map_config = config.duplicate(true)

	var boss_id: int = (total_layers - 1) * 100
	return {
		"graph": graph,
		"nodes": node_details,
		"layers": nodes_per_layer,
		"boss_node_id": boss_id,
		"path_count": path_count,
	}


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

	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("ExplorationSystem.enter_map: GSM 不可用，导航状态未写入")
		return map_data

	# 写入导航状态——通过 GSM 第二层原子方法（ADR-0014 §GSM 写入契约）
	gsm.set_exploration_map(map_id)
	gsm.set_exploration_ap(max_ap, max_ap)

	# 递增 entry_count
	var entry_count: int = _get_entry_count(map_id) + 1
	gsm.update_exploration_map_state(map_id, {"entry_count": entry_count})

	return map_data


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


## 加权随机分配节点类型——排除超限类型后重新加权。
func _assign_node_types(all_nodes: Array, nodes_per_layer: Array, config: Dictionary, total_layers: int) -> Dictionary:
	var weights: Dictionary = config.get("weights", {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5})
	var max_elite: int = int(config.get("elite_count", 2))
	var max_shop: int = int(config.get("shop_count", 1))
	var elite_assigned: int = 0
	var shop_assigned: int = 0
	var node_types: Dictionary = {}

	for node_id in all_nodes:
		var layer: int = node_id / 100
		if layer == 0:
			node_types[node_id] = NodeType.ENTRY
		elif layer == total_layers - 1:
			node_types[node_id] = NodeType.BOSS
		else:
			var adjusted_weights: Dictionary = weights.duplicate()
			if elite_assigned >= max_elite:
				adjusted_weights.erase("elite")
			if shop_assigned >= max_shop:
				adjusted_weights.erase("shop")
			var type_str: String = _weighted_random(adjusted_weights)
			var ntype: int = _string_to_node_type(type_str)
			node_types[node_id] = ntype
			if ntype == NodeType.ELITE:
				elite_assigned += 1
			elif ntype == NodeType.SHOP:
				shop_assigned += 1
	return node_types


## 加权随机选择——返回权重最大的键。
func _weighted_random(weights: Dictionary) -> String:
	var total: int = 0
	for key in weights:
		total += int(weights[key])
	if total <= 0:
		return "combat"
	var roll: int = _rng.randi_range(1, total)
	var cumulative: int = 0
	for key in weights:
		cumulative += int(weights[key])
		if roll <= cumulative:
			return key
	return weights.keys()[0]


## 字符串节点类型名→枚举值。
func _string_to_node_type(type_str: String) -> int:
	match type_str:
		"combat": return NodeType.COMBAT
		"event": return NodeType.EVENT
		"shop": return NodeType.SHOP
		"rest": return NodeType.REST
		"elite": return NodeType.ELITE
		_: return NodeType.COMBAT


## 构建边连接——每层每个节点至少连接上层 1 个节点。
func _build_edges(all_nodes: Array, nodes_per_layer: Array, total_layers: int) -> Dictionary:
	var graph: Dictionary = {}
	for node_id in all_nodes:
		graph[node_id] = []

	# 从第 1 层开始，每个节点连接上层 1-2 个节点
	for layer in range(1, total_layers):
		var prev_layer: int = layer - 1
		var prev_count: int = nodes_per_layer[prev_layer]
		var curr_count: int = nodes_per_layer[layer]
		for idx in range(curr_count):
			var node_id: int = layer * 100 + idx
			# 至少连接上层 1 个节点
			var parent_idx: int = _rng.randi_range(0, prev_count - 1)
			var parent_id: int = prev_layer * 100 + parent_idx
			if not graph[parent_id].has(node_id):
				graph[parent_id].append(node_id)
			# 50% 概率连接第二个父节点（如果上层有 ≥2 节点）
			if prev_count >= 2 and _rng.randf() < 0.5:
				var parent2_idx: int = (parent_idx + 1) % prev_count
				var parent2_id: int = prev_layer * 100 + parent2_idx
				if not graph[parent2_id].has(node_id):
					graph[parent2_id].append(node_id)

	# 确保上层每个节点都有至少 1 个子节点（避免孤儿父节点）
	for layer in range(total_layers - 1):
		var next_layer: int = layer + 1
		var next_count: int = nodes_per_layer[next_layer]
		for idx in range(nodes_per_layer[layer]):
			var node_id: int = layer * 100 + idx
			if graph[node_id].is_empty():
				# 连接下层第一个节点
				var child_id: int = next_layer * 100 + 0
				graph[node_id].append(child_id)
	return graph


## 添加交叉边——增加独立路径数。
func _add_cross_edges(graph: Dictionary, nodes_per_layer: Array, total_layers: int) -> void:
	for layer in range(1, total_layers):
		var prev_layer: int = layer - 1
		var prev_count: int = nodes_per_layer[prev_layer]
		for idx in range(nodes_per_layer[layer]):
			var node_id: int = layer * 100 + idx
			# 尝试连接额外的父节点
			for parent_idx in range(prev_count):
				var parent_id: int = prev_layer * 100 + parent_idx
				if not graph[parent_id].has(node_id):
					if _rng.randf() < 0.3:
						graph[parent_id].append(node_id)


## 计算顶点不相交路径数——简化版：BFS 找路径 + 移除中间顶点 + 重复。[br]
## [br]DAG 中顶点不相交路径数 = 找一条路径→移除中间顶点→再找→直到找不到。[br]
## 最多查找 max_paths 条（防止无限循环）。
func _count_vertex_disjoint_paths(graph: Dictionary, source: int, sink: int) -> int:
	# 深拷贝图（不修改原图）
	var working: Dictionary = graph.duplicate(true)
	var path_count: int = 0
	var max_paths: int = 10
	while path_count < max_paths:
		var path: Array = _bfs_path(working, source, sink)
		if path.is_empty():
			break
		path_count += 1
		# 移除中间顶点（保留 source 和 sink）
		for i in range(1, path.size() - 1):
			var mid: int = path[i]
			working.erase(mid)
		# 从所有邻接列表中移除已删顶点
		for parent_id in working:
			var children: Array = working[parent_id]
			for c in range(children.size() - 1, -1, -1):
				if not working.has(children[c]):
					children.remove_at(c)
	return path_count


## BFS 寻找路径——返回 source→sink 的节点 ID 路径。[br]
## [br]注意：visited 检查必须包裹 parent 赋值和 queue.append，[br]
## 否则已访问节点会被反复入队导致 BFS 无法终止→栈崩溃。
func _bfs_path(graph: Dictionary, source: int, sink: int) -> Array:
	if source == sink:
		return [source]
	var queue: Array = [source]
	var visited: Dictionary = {source: true}
	var parent: Dictionary = {source: -1}
	while not queue.is_empty():
		var u: int = queue.pop_front()
		if not graph.has(u):
			continue
		for v in graph[u]:
			if not visited.has(v):
				visited[v] = true
				parent[v] = u
				if v == sink:
					# 回溯路径
					var path: Array = []
					var curr: int = v
					while curr != -1:
						path.push_front(curr)
						curr = int(parent.get(curr, -1))
					return path
				queue.append(v)
	return []


## 填充节点内容——战斗=敌人阵容、事件=pool、商店=库存。
func _fill_node_content(all_nodes: Array, node_types: Dictionary, nodes_per_layer: Array, total_layers: int, map_id: StringName, player_realm: int) -> Dictionary:
	var details: Dictionary = {}
	for node_id in all_nodes:
		var layer: int = node_id / 100
		var idx: int = node_id % 100
		var ntype: int = int(node_types.get(node_id, NodeType.COMBAT))
		var detail: Dictionary = {
			"type": ntype,
			"layer": layer,
			"idx": idx,
		}
		match ntype:
			NodeType.ENTRY:
				detail["label"] = "入口"
			NodeType.BOSS:
				detail["label"] = "Boss"
			NodeType.COMBAT, NodeType.ELITE:
				if generate_enemy_roster_cb.is_valid():
					detail["enemy_roster"] = generate_enemy_roster_cb.call(map_id, player_realm, ntype == NodeType.ELITE)
				else:
					detail["enemy_roster"] = []
			NodeType.EVENT:
				# 不分配具体事件——仅记录 pool
				if get_event_pool_cb.is_valid():
					detail["event_pool"] = get_event_pool_cb.call(map_id, player_realm)
				else:
					detail["event_pool"] = []
			NodeType.SHOP:
				if generate_shop_inventory_cb.is_valid():
					detail["inventory"] = generate_shop_inventory_cb.call(player_realm)
				else:
					detail["inventory"] = {}
			NodeType.REST:
				detail["label"] = "回复点"
			NodeType.ACTION_SPRING:
				detail["label"] = "行动力泉"
			NodeType.TELEPORT:
				detail["label"] = "传送"
			NodeType.TRIBULATION:
				detail["label"] = "渡劫台"
		details[node_id] = detail
	return details


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
