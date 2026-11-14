## ExplorationDAGBuilder —— DAG 生成算法子模块（RefCounted）。
##
## 从 exploration_system.gd 提取的纯 DAG 生成逻辑。[br]
## 持有父节点 ExplorationSystem 引用，通过它访问 _rng / 回调字段 / 常量。[br]
## 边连接与独立路径计数委托给 [code]exploration_dag_graph.gd[/code]（纯算法，
## RNG 由本模块注入——确定性口径不因拆分改变）；节点内容填充（遭遇/事件池/
## 货架/采集载荷/标签）委托给 [code]exploration_dag_content.gd[/code]。[br]
## [br]来源: ADR-0014 §决策 2 程序化 DAG 生成 / GDD exploration-system.md §2-3。
## [br]Sprint 8 Story 8-9：从 exploration_system.gd 拆分；2026-11-10 图算法再拆分；
## 2026-11-14 节点内容填充再拆分（脚本贴 300 行软上限）。
extends RefCounted

## 图骨架算法（边连接 / 交叉边 / 独立路径计数）。
const Graph := preload("res://src/feature/exploration/exploration_dag_graph.gd")
## 节点内容填充（遭遇数据 / 事件池 / 货架 / 采集载荷 / 标签）。
const Content := preload("res://src/feature/exploration/exploration_dag_content.gd")
## 灵泉结算子模块——[b]只为读它的限次判据[/b]（[method ExplorationActionSpring.is_exhausted]
## / [method ExplorationActionSpring.limit_of]）：生成侧与结算侧必须用同一个判据，
## 各写一遍必然出现「刷得出来但回不了」的死节点。
const Spring := preload("res://src/feature/exploration/exploration_action_spring.gd")


## 父节点引用——ExplorationSystem Autoload 实例。
var _parent: Node = null

## 内容填充子模块（惰性——保证 _warned_missing_enemy_realm 的「每次生成只警告一次」
## 跨生成周期成立；每次 new 会让告警按图重刷）。
var _content: RefCounted = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 内容填充子模块（惰性初始化——告警标志需跨调用存活）。
func _content_filler() -> RefCounted:
	if _content == null:
		_content = Content.new(_parent)
	return _content


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
	var nodes_per_layer: Array = Graph.roll_layers(rng, total_layers, min_n, max_n)
	var all_nodes: Array = Graph.all_nodes(nodes_per_layer)

	# Phase 3：分配节点类型
	var node_types: Dictionary = _assign_node_types(
			all_nodes, nodes_per_layer, config, total_layers, map_id)

	# Phase 4：边连接 + 连通性验证 + ≥2 独立路径（迭代重试，不递归——避免栈下溢）
	var graph: Dictionary = Graph.build_edges(all_nodes, nodes_per_layer, total_layers, rng)
	var sink_id: int = all_nodes[all_nodes.size() - 1]
	var path_count: int = Graph.count_vertex_disjoint_paths(graph, 0, sink_id)
	path_count = _repair_paths(graph, nodes_per_layer, total_layers, sink_id, rng, path_count)

	# 仍不足时整体重新生成（最多 2 次，迭代而非递归）
	var regen_retry: int = 0
	while path_count < 2 and regen_retry < 2:
		regen_retry += 1
		# 重置 RNG seed 并加扰重试计数，避免相同图重复生成
		rng.seed = (base_seed ^ map_hash ^ entry_count) + regen_retry
		nodes_per_layer = Graph.roll_layers(rng, total_layers, min_n, max_n)
		all_nodes = Graph.all_nodes(nodes_per_layer)
		node_types = _assign_node_types(all_nodes, nodes_per_layer, config,
				total_layers, map_id)
		graph = Graph.build_edges(all_nodes, nodes_per_layer, total_layers, rng)
		sink_id = all_nodes[all_nodes.size() - 1]
		path_count = Graph.count_vertex_disjoint_paths(graph, 0, sink_id)
		path_count = _repair_paths(graph, nodes_per_layer, total_layers, sink_id, rng, path_count)
	if path_count < 2:
		push_warning("ExplorationSystem: map %s path_count=%d < 2 after retries" % [map_id, path_count])

	# Phase 5：填充节点内容（遭遇/事件池/货架/采集载荷/标签——见 ExplorationDAGContent）
	var node_details: Dictionary = _content_filler().call(&"fill",
			all_nodes, node_types, map_id, player_realm, config)

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


## 独立路径不足时加交叉边（最多 2 次），返回最终路径数。
func _repair_paths(p_graph: Dictionary, p_nodes_per_layer: Array, p_total_layers: int,
		p_sink: int, p_rng: RandomNumberGenerator, p_path_count: int) -> int:
	var path_count: int = p_path_count
	var cross_retry: int = 0
	while path_count < 2 and cross_retry < 2:
		Graph.add_cross_edges(p_graph, p_nodes_per_layer, p_total_layers, p_rng)
		path_count = Graph.count_vertex_disjoint_paths(p_graph, 0, p_sink)
		cross_retry += 1
	return path_count


## 加权随机分配节点类型——排除超限类型后重新加权。[br]
## [br][param p_map_id] 地图 ID——灵泉限次要读这张图的 [code]map_states[/code]
## （次数是[b]按图[/b]累计的，不是按节点：同一张图重新生成时灵泉会落在别的节点 ID
## 上，只按节点记等于换个位置就能再刷一次）。[br]
## [br][b]灵泉上限 = 限次 - 本图已用[/b]：已用满时不再把灵泉放进权重表，玩家不会
## 走到一个注定回复 0 的节点上；判据与结算侧共用 [ExplorationActionSpring]（见
## [constant Spring]），不各判一套。
func _assign_node_types(all_nodes: Array, nodes_per_layer: Array, config: Dictionary,
		total_layers: int, p_map_id: StringName = &"") -> Dictionary:
	var weights: Dictionary = config.get("weights", {"combat": 40, "event": 30, "shop": 15, "rest": 10, "harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6, "elite": 5, "action_spring": 8})
	var max_elite: int = int(config.get("elite_count", 2))
	var max_shop: int = int(config.get("shop_count", 1))
	var max_spring: int = _spring_room(p_map_id, config)
	var elite_assigned: int = 0
	var shop_assigned: int = 0
	var spring_assigned: int = 0
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
			if spring_assigned >= max_spring:
				adjusted_weights.erase("action_spring")
			var type_str: String = _weighted_random(adjusted_weights)
			var ntype: int = _string_to_node_type(type_str)
			node_types[node_id] = ntype
			if ntype == _parent.NodeType.ELITE:
				elite_assigned += 1
			elif ntype == _parent.NodeType.SHOP:
				shop_assigned += 1
			elif ntype == _parent.NodeType.ACTION_SPRING:
				spring_assigned += 1
	return node_types


## 本图还能刷出几个灵泉节点——限次减去该图 [code]map_states[/code] 里已记录的使用次数。[br]
## [br][b]无 GSM / 无地图 ID 时按满额[/b]（单测直调生成器是常态）：生成是只读操作，
## 拿不到状态就不该把灵泉从图里抹掉——真正的次数扣减在结算侧，那里有写入守卫。
func _spring_room(p_map_id: StringName, config: Dictionary) -> int:
	var limit: int = Spring.limit_of(config)
	var gsm: Node = _parent.call(&"_get_gsm") if _parent.has_method(&"_get_gsm") else null
	if gsm == null or p_map_id == &"" or str(p_map_id).is_empty():
		return limit
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(p_map_id, {})
	return maxi(limit - Spring.uses_of(state), 0)


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
		"harvest": return _parent.NodeType.HARVEST
		"alchemy": return _parent.NodeType.ALCHEMY
		"forge": return _parent.NodeType.FORGE
		"meditation": return _parent.NodeType.MEDITATION
		"elite": return _parent.NodeType.ELITE
		"action_spring": return _parent.NodeType.ACTION_SPRING
		_: return _parent.NodeType.COMBAT
