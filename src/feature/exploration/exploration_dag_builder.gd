## ExplorationDAGBuilder —— DAG 生成算法子模块（RefCounted）。
##
## 从 exploration_system.gd 提取的纯 DAG 生成逻辑。[br]
## 持有父节点 ExplorationSystem 引用，通过它访问 _rng / 回调字段 / 常量。[br]
## [br]来源: ADR-0014 §决策 2 程序化 DAG 生成 / GDD exploration-system.md §2-3。
## [br]Sprint 8 Story 8-9：从 exploration_system.gd 拆分。
extends RefCounted


## 父节点引用——ExplorationSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 程序化生成 DAG 地图——加权随机分配 + 确定性边连接 + 后处理约束验证。[br]
## [br][param map_id] 地图 ID（用于 seed 计算）。[br]
## [br][param player_realm] 玩家境界等级（用于配置衍生）。[br]
## [br][param entry_count] 本局该地图进入次数（用于 seed 计算）。[br]
## [br][b]返回[/b]: [code]{graph, nodes, layers, boss_node_id, path_count}[/code] Dictionary。[br]
## [br]来源: ADR-0014 §决策 2 / GDD §3。
func generate_map(map_id: StringName, player_realm: int = 1, entry_count: int = 1) -> Dictionary:
	# Phase 1：读取配置
	var config: Dictionary = _parent.call("_get_map_config", map_id, player_realm)

	# 初始化 RNG——seed = base_seed XOR map_id.hash() XOR entry_count
	var base_seed: int = _parent.call("_get_seed")
	var map_hash: int = hash(map_id)
	var rng: RandomNumberGenerator = _parent.get("_rng")
	rng.seed = base_seed ^ map_hash ^ entry_count

	# Phase 2：生成 DAG 骨架
	var total_layers: int = int(config.get("layers", 5))
	var min_n: int = int(config.get("min_nodes", 2))
	var max_n: int = int(config.get("max_nodes", 4))
	var nodes_per_layer: Array = []
	for i in range(total_layers):
		if i == 0 or i == total_layers - 1:
			nodes_per_layer.append(1)
		else:
			nodes_per_layer.append(rng.randi_range(min_n, max_n))

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
		rng.seed = (base_seed ^ map_hash ^ entry_count) + regen_retry
		nodes_per_layer = []
		for i in range(total_layers):
			if i == 0 or i == total_layers - 1:
				nodes_per_layer.append(1)
			else:
				nodes_per_layer.append(rng.randi_range(min_n, max_n))
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
	_parent.set("_node_graph", graph.duplicate(true))
	_parent.set("_node_details", node_details.duplicate(true))
	_parent.set("_map_config", config.duplicate(true))

	var boss_id: int = (total_layers - 1) * 100
	return {
		"graph": graph,
		"nodes": node_details,
		"layers": nodes_per_layer,
		"boss_node_id": boss_id,
		"path_count": path_count,
	}


## 加权随机分配节点类型——排除超限类型后重新加权。
func _assign_node_types(all_nodes: Array, nodes_per_layer: Array, config: Dictionary, total_layers: int) -> Dictionary:
	var weights: Dictionary = config.get("weights", {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5})
	var max_elite: int = int(config.get("elite_count", 2))
	var max_shop: int = int(config.get("shop_count", 1))
	var elite_assigned: int = 0
	var shop_assigned: int = 0
	var node_types: Dictionary = {}
	var rng: RandomNumberGenerator = _parent.get("_rng")

	for node_id in all_nodes:
		var layer: int = node_id / 100
		if layer == 0:
			node_types[node_id] = _parent.NodeType.ENTRY
		elif layer == total_layers - 1:
			node_types[node_id] = _parent.NodeType.BOSS
		else:
			var adjusted_weights: Dictionary = weights.duplicate()
			if elite_assigned >= max_elite:
				adjusted_weights.erase("elite")
			if shop_assigned >= max_shop:
				adjusted_weights.erase("shop")
			var type_str: String = _weighted_random(adjusted_weights)
			var ntype: int = _string_to_node_type(type_str)
			node_types[node_id] = ntype
			if ntype == _parent.NodeType.ELITE:
				elite_assigned += 1
			elif ntype == _parent.NodeType.SHOP:
				shop_assigned += 1
	return node_types


## 加权随机选择——返回权重最大的键。
func _weighted_random(weights: Dictionary) -> String:
	var rng: RandomNumberGenerator = _parent.get("_rng")
	var total: int = 0
	for key in weights:
		total += int(weights[key])
	if total <= 0:
		return "combat"
	var roll: int = rng.randi_range(1, total)
	var cumulative: int = 0
	for key in weights:
		cumulative += int(weights[key])
		if roll <= cumulative:
			return key
	return weights.keys()[0]


## 字符串节点类型名→枚举值。
func _string_to_node_type(type_str: String) -> int:
	match type_str:
		"combat": return _parent.NodeType.COMBAT
		"event": return _parent.NodeType.EVENT
		"shop": return _parent.NodeType.SHOP
		"rest": return _parent.NodeType.REST
		"elite": return _parent.NodeType.ELITE
		_: return _parent.NodeType.COMBAT


## 构建边连接——每层每个节点至少连接上层 1 个节点。
func _build_edges(all_nodes: Array, nodes_per_layer: Array, total_layers: int) -> Dictionary:
	var graph: Dictionary = {}
	for node_id in all_nodes:
		graph[node_id] = []
	var rng: RandomNumberGenerator = _parent.get("_rng")

	# 从第 1 层开始，每个节点连接上层 1-2 个节点
	for layer in range(1, total_layers):
		var prev_layer: int = layer - 1
		var prev_count: int = nodes_per_layer[prev_layer]
		var curr_count: int = nodes_per_layer[layer]
		for idx in range(curr_count):
			var node_id: int = layer * 100 + idx
			# 至少连接上层 1 个节点
			var parent_idx: int = rng.randi_range(0, prev_count - 1)
			var parent_id: int = prev_layer * 100 + parent_idx
			if not graph[parent_id].has(node_id):
				graph[parent_id].append(node_id)
			# 50% 概率连接第二个父节点（如果上层有 ≥2 节点）
			if prev_count >= 2 and rng.randf() < 0.5:
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
	var rng: RandomNumberGenerator = _parent.get("_rng")
	for layer in range(1, total_layers):
		var prev_layer: int = layer - 1
		var prev_count: int = nodes_per_layer[prev_layer]
		for idx in range(nodes_per_layer[layer]):
			var node_id: int = layer * 100 + idx
			# 尝试连接额外的父节点
			for parent_idx in range(prev_count):
				var parent_id: int = prev_layer * 100 + parent_idx
				if not graph[parent_id].has(node_id):
					if rng.randf() < 0.3:
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
		var ntype: int = int(node_types.get(node_id, _parent.NodeType.COMBAT))
		var detail: Dictionary = {
			"type": ntype,
			"layer": layer,
			"idx": idx,
		}
		match ntype:
			_parent.NodeType.ENTRY:
				detail["label"] = "入口"
			_parent.NodeType.BOSS:
				detail["label"] = "Boss"
			_parent.NodeType.COMBAT, _parent.NodeType.ELITE:
				var roster_cb: Callable = _parent.get("generate_enemy_roster_cb")
				if roster_cb.is_valid():
					detail["enemy_roster"] = roster_cb.call(map_id, player_realm, ntype == _parent.NodeType.ELITE)
				else:
					detail["enemy_roster"] = []
			_parent.NodeType.EVENT:
				# 不分配具体事件——仅记录 pool
				var event_cb: Callable = _parent.get("get_event_pool_cb")
				if event_cb.is_valid():
					detail["event_pool"] = event_cb.call(map_id, player_realm)
				else:
					detail["event_pool"] = []
			_parent.NodeType.SHOP:
				var shop_cb: Callable = _parent.get("generate_shop_inventory_cb")
				if shop_cb.is_valid():
					detail["inventory"] = shop_cb.call(player_realm)
				else:
					detail["inventory"] = {}
			_parent.NodeType.REST:
				detail["label"] = "回复点"
			_parent.NodeType.ACTION_SPRING:
				detail["label"] = "行动力泉"
			_parent.NodeType.TELEPORT:
				detail["label"] = "传送"
			_parent.NodeType.TRIBULATION:
				detail["label"] = "渡劫台"
		details[node_id] = detail
	return details
