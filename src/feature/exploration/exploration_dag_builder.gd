## ExplorationDAGBuilder —— DAG 生成算法子模块（RefCounted）。
##
## 从 exploration_system.gd 提取的纯 DAG 生成逻辑。[br]
## 持有父节点 ExplorationSystem 引用，通过它访问 _rng / 回调字段 / 常量。[br]
## 边连接与独立路径计数委托给 [code]exploration_dag_graph.gd[/code]（纯算法，
## RNG 由本模块注入——确定性口径不因拆分改变）。[br]
## [br]来源: ADR-0014 §决策 2 程序化 DAG 生成 / GDD exploration-system.md §2-3。
## [br]Sprint 8 Story 8-9：从 exploration_system.gd 拆分；2026-11-10 图算法再拆分。
extends RefCounted

## 遭遇数据契约（写入 / 读取的唯一口径——生成器与开战上下文共用）。
const Fields := preload("res://assets/enemies/encounter_fields.gd")
## 图骨架算法（边连接 / 交叉边 / 独立路径计数）。
const Graph := preload("res://src/feature/exploration/exploration_dag_graph.gd")

## 地图配置里敌人基准境界的键（缺键 = 旧配置，回退玩家境界并警告一次）。
const KEY_ENEMY_REALM: String = "enemy_realm"


## 父节点引用——ExplorationSystem Autoload 实例。
var _parent: Node = null

## 缺 [constant KEY_ENEMY_REALM] 的告警已发标志——每次生成只提醒一次，
## 避免每张图几十个战斗节点各刷一条（旧配置回退是过渡态，不是逐节点事件）。
var _warned_missing_enemy_realm: bool = false


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
	var nodes_per_layer: Array = Graph.roll_layers(rng, total_layers, min_n, max_n)
	var all_nodes: Array = Graph.all_nodes(nodes_per_layer)

	# Phase 3：分配节点类型
	var node_types: Dictionary = _assign_node_types(
			all_nodes, nodes_per_layer, config, total_layers)

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
		node_types = _assign_node_types(all_nodes, nodes_per_layer, config, total_layers)
		graph = Graph.build_edges(all_nodes, nodes_per_layer, total_layers, rng)
		sink_id = all_nodes[all_nodes.size() - 1]
		path_count = Graph.count_vertex_disjoint_paths(graph, 0, sink_id)
		path_count = _repair_paths(graph, nodes_per_layer, total_layers, sink_id, rng, path_count)
	if path_count < 2:
		push_warning("ExplorationSystem: map %s path_count=%d < 2 after retries" % [map_id, path_count])

	# Phase 5：填充节点内容
	var node_details: Dictionary = _fill_node_content(
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


## 填充战斗/精英节点的遭遇数据（[code]enemy_roster[/code] + 四键遭遇契约）。[br]
## [br][b]写入什么[/b]：名册 + [code]encounter[/code] 子字典 + 顶层
## [code]enemy_level[/code] / [code]rewards[/code] / [code]label[/code]——
## 顶层两键是 [code]CombatLaunchContext[/code] 的读取面，子字典是弹窗预览的聚合载体。[br]
## [br][b]等级口径[/b]（GDD §7 回旧地图：敌人强度按地图本身境界）：地图配置
## [code]enemy_realm[/code] > 玩家当前境界（旧配置缺键的过渡兜底，警告一次）。[br]
## [br][b]掉落口径[/b]：条目自带 [code]rewards[/code] > 模板 [code]reward_config[/code]
## 聚合；都没有则为 [code]{}[/code]（「本节点无掉落配置」，不是 0 掉落）。[br]
## [br][b]不臆造[/b]：名册回调缺失时名册为 [code][][/code]，由开战校验给出可读失败。
func _fill_encounter(p_detail: Dictionary, p_node_id: int, p_map_id: StringName,
		p_player_realm: int, p_is_elite: bool, p_config: Dictionary) -> void:
	var roster_cb: Callable = _parent.get("generate_enemy_roster_cb")
	var roster: Array = []
	if roster_cb.is_valid():
		roster = roster_cb.call(p_map_id, p_player_realm, p_is_elite)
		if not (roster is Array):
			roster = []
	var lookup: Callable = _template_lookup()
	var label: String = Fields.label_of(roster, p_is_elite)
	var encounter: Dictionary = Fields.make(
			"%s_%d" % [p_map_id, p_node_id], Fields.name_of(roster, p_is_elite),
			Fields.template_ids_of(roster), Fields.LEVEL_UNSPECIFIED, {})
	# 等级：地图境界定档优先（GDD「回旧地图」），旧配置缺键时回退玩家境界。
	var level: int = _level_of(p_map_id, p_player_realm, p_config)
	encounter[Fields.KEY_ENEMY_LEVEL] = level
	var rewards: Dictionary = Fields.rewards(encounter, roster, lookup)
	encounter[Fields.KEY_REWARDS] = rewards
	p_detail["enemy_roster"] = roster
	p_detail["label"] = label
	p_detail[Fields.KEY_ENCOUNTER] = encounter
	p_detail[Fields.KEY_ENEMY_LEVEL] = level
	p_detail[Fields.KEY_REWARDS] = rewards


## 节点等级定档——地图配置 [code]enemy_realm[/code] 优先，缺键（旧配置）时
## 回退玩家境界并警告一次。[br]
## [br][b]为什么不再让名册境界插队[/b]：GDD §7 要求「高境界玩家回低境界地图，
## 敌人强度仍按地图本身境界设定」。名册条目的境界来自敌人模板（出厂模板恒为
## 炼气），若它先命中，地图境界配置就永远不起作用——低境界图与高境界图的节点
## 强度会完全一样。名册境界只在开战上下文（[code]EncounterFields.enemy_level[/code]）
## 作为「节点未定档」时的读取兜底，不参与生成期定档。[br]
## [br][b]旧配置兼容[/b]：缺 [constant KEY_ENEMY_REALM] 时回退玩家境界并警告
## 一次（每次生成一条，不按节点刷屏）。
func _level_of(p_map_id: StringName, p_player_realm: int, p_config: Dictionary) -> int:
	var map_realm: int = int(p_config.get(KEY_ENEMY_REALM, 0))
	if map_realm > 0:
		return map_realm
	if not _warned_missing_enemy_realm:
		_warned_missing_enemy_realm = true
		push_warning("ExplorationDAGBuilder: 地图配置缺少 %s（map=%s），节点等级回退玩家境界 %d"
				% [KEY_ENEMY_REALM, p_map_id, p_player_realm])
	return maxi(p_player_realm, Fields.LEVEL_UNSPECIFIED)


## 模板查询闭包——注入回调优先，其次 Autoload AISystem，都没有时返回无效
## Callable（掉落聚合退化为「只读名册条目自带的 rewards」）。[br]
## [br][b]为什么允许注入[/b]：DAG 生成在单测里跑在裸 [code]Node[/code] 上
## （不在场景树中），此时拿不到 Autoload——注入让「据 reward_config 聚合掉落」
## 也能被单测覆盖。缺模板不应让地图生成崩溃。
func _template_lookup() -> Callable:
	if _parent == null:
		return Callable()
	var injected: Variant = _parent.get("enemy_template_lookup_cb")
	if injected is Callable and (injected as Callable).is_valid():
		return injected
	if not _parent.is_inside_tree():
		return Callable()
	var ai: Node = _parent.get_node_or_null(NodePath("/root/AISystem"))
	if ai != null and ai.has_method(&"get_template"):
		return Callable(ai, &"get_template")
	return Callable()


## 填充节点内容——战斗=敌人阵容、事件=pool、商店=库存。
func _fill_node_content(all_nodes: Array, node_types: Dictionary,
		map_id: StringName, player_realm: int, config: Dictionary) -> Dictionary:
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
				_fill_encounter(detail, node_id, map_id, player_realm,
						ntype == _parent.NodeType.ELITE, config)
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
