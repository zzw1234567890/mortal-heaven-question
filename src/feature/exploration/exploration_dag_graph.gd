extends RefCounted
## ExplorationDAGGraph —— DAG 骨架的边连接与独立路径计数（纯算法子模块）。[br]
## [br][b]为什么单独一处[/b]：[code]exploration_dag_builder.gd[/code] 已贴近 300 行
## 软上限，而「节点类型怎么分配」与「边怎么连、独立路径够不够」是两件事——后者
## 只依赖 [code]nodes_per_layer[/code] 与 RNG，拆出后可独立推理，也便于后续替换
## 连通性算法。[br]
## [br][b]RNG 由调用方持有[/b]：本模块不新建随机源，所有随机性经 [param p_rng]
## 注入——生成器的确定性（seed = base ^ map_hash ^ entry_count）不因拆分而改变。[br]
##
## 来源: ADR-0014 §决策 2 程序化 DAG 生成、GDD exploration-system.md §3 步骤④。

## 掷每层节点数——首末层固定 1，中间层 [param p_min]~[param p_max]。[br]
## [br][b]为什么放在这里[/b]：层形状与边连接是同一件事的两半（[code]nodes_per_layer[/code]
## 决定图的长相），调用方只需拿到一份「层形状」。[br]
static func roll_layers(p_rng: RandomNumberGenerator, p_total_layers: int,
		p_min: int, p_max: int) -> Array:
	var nodes_per_layer: Array = []
	for i in range(p_total_layers):
		if i == 0 or i == p_total_layers - 1:
			nodes_per_layer.append(1)
		else:
			nodes_per_layer.append(p_rng.randi_range(p_min, p_max))
	return nodes_per_layer


## 按层节点数展开全部节点 ID（[code]layer * 100 + idx[/code]）。
static func all_nodes(p_nodes_per_layer: Array) -> Array:
	var all_nodes: Array = []
	for layer in range(p_nodes_per_layer.size()):
		for idx in range(p_nodes_per_layer[layer]):
			all_nodes.append(layer * 100 + idx)
	return all_nodes


## 构建边连接——每层每个节点至少连接上层 1 个节点。[br]
## [br][param p_all_nodes] 全部节点 ID（[code]layer * 100 + idx[/code]）。[br]
## [param p_nodes_per_layer] 每层节点数。[br]
## [param p_total_layers] 总层数。[br]
## [param p_rng] 随机源（调用方持有，确定性口径不在此处定义）。
static func build_edges(p_all_nodes: Array, p_nodes_per_layer: Array,
		p_total_layers: int, p_rng: RandomNumberGenerator) -> Dictionary:
	var graph: Dictionary = {}
	for node_id in p_all_nodes:
		graph[node_id] = []

	# 从第 1 层开始，每个节点连接上层 1-2 个节点
	for layer in range(1, p_total_layers):
		var prev_layer: int = layer - 1
		var prev_count: int = p_nodes_per_layer[prev_layer]
		var curr_count: int = p_nodes_per_layer[layer]
		for idx in range(curr_count):
			var node_id: int = layer * 100 + idx
			# 至少连接上层 1 个节点
			var parent_idx: int = p_rng.randi_range(0, prev_count - 1)
			var parent_id: int = prev_layer * 100 + parent_idx
			if not graph[parent_id].has(node_id):
				graph[parent_id].append(node_id)
			# 50% 概率连接第二个父节点（如果上层有 ≥2 节点）
			if prev_count >= 2 and p_rng.randf() < 0.5:
				var parent2_idx: int = (parent_idx + 1) % prev_count
				var parent2_id: int = prev_layer * 100 + parent2_idx
				if not graph[parent2_id].has(node_id):
					graph[parent2_id].append(node_id)

	# 确保上层每个节点都有至少 1 个子节点（避免孤儿父节点）
	for layer in range(p_total_layers - 1):
		var next_layer: int = layer + 1
		for idx in range(p_nodes_per_layer[layer]):
			var node_id: int = layer * 100 + idx
			if graph[node_id].is_empty():
				# 连接下层第一个节点
				var child_id: int = next_layer * 100 + 0
				graph[node_id].append(child_id)
	return graph


## 添加交叉边——增加独立路径数（独立路径不足时的第一道补救）。[br]
## [br][b]原地修改[/b] [param p_graph]（生成器持有同一份引用，无需回传）。
static func add_cross_edges(p_graph: Dictionary, p_nodes_per_layer: Array,
		p_total_layers: int, p_rng: RandomNumberGenerator) -> void:
	for layer in range(1, p_total_layers):
		var prev_layer: int = layer - 1
		var prev_count: int = p_nodes_per_layer[prev_layer]
		for idx in range(p_nodes_per_layer[layer]):
			var node_id: int = layer * 100 + idx
			# 尝试连接额外的父节点
			for parent_idx in range(prev_count):
				var parent_id: int = prev_layer * 100 + parent_idx
				if not p_graph[parent_id].has(node_id):
					if p_rng.randf() < 0.3:
						p_graph[parent_id].append(node_id)


## 计算顶点不相交路径数——BFS 找路径 → 移除中间顶点 → 重复，最多 10 条。[br]
## [br][b]不修改原图[/b]：在 [code]duplicate(true)[/code] 的工作副本上删点。
static func count_vertex_disjoint_paths(p_graph: Dictionary, p_source: int,
		p_sink: int) -> int:
	# 深拷贝图（不修改原图）
	var working: Dictionary = p_graph.duplicate(true)
	var path_count: int = 0
	var max_paths: int = 10
	while path_count < max_paths:
		var path: Array = bfs_path(working, p_source, p_sink)
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


## BFS 寻找路径——返回 source→sink 的节点 ID 路径（找不到返回空数组）。[br]
## [br][b]注意[/b]：visited 检查必须包裹 parent 赋值和 queue.append，
## 否则已访问节点会被反复入队导致 BFS 无法终止→栈崩溃。
static func bfs_path(p_graph: Dictionary, p_source: int, p_sink: int) -> Array:
	if p_source == p_sink:
		return [p_source]
	var queue: Array = [p_source]
	var visited: Dictionary = {p_source: true}
	var parent: Dictionary = {p_source: -1}
	while not queue.is_empty():
		var u: int = queue.pop_front()
		if not p_graph.has(u):
			continue
		for v in p_graph[u]:
			if not visited.has(v):
				visited[v] = true
				parent[v] = u
				if v == p_sink:
					# 回溯路径
					var path: Array = []
					var curr: int = v
					while curr != -1:
						path.push_front(curr)
						curr = int(parent.get(curr, -1))
					return path
				queue.append(v)
	return []
