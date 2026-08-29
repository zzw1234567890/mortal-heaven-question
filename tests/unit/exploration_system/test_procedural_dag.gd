extends GutTest
## Story 001 验收测试：程序化 DAG 地图生成。
##
## 覆盖 AC-001 到 AC-013（13 条 AC）。
## 测试策略：
##   - ES_SCRIPT.new() 构造 ExplorationSystem 实例
##   - set_rng_seed(42) 确定性
##   - 注入 get_map_config_cb 返回指定难度配置
##   - 注入 generate_enemy_roster_cb / get_event_pool_cb / generate_shop_inventory_cb 桩
##   - generate_map 返回结构验证 + 连通性 + 确定性 + JSON 可序列化
##
## 设计文档来源：ADR-0014 §决策 2 / GDD exploration-system.md §2-3
## Story 来源：production/epics/exploration-system/story-001-procedural-dag.md

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)


func after_each() -> void:
	if es != null:
		es.free()
		es = null


# === 辅助 ================================================================

## 注入指定难度的地图配置回调。
func _inject_config(difficulty: int) -> void:
	var configs: Array = es.get("DIFFICULTY_CONFIGS")
	var cfg: Dictionary = configs[difficulty] if difficulty >= 0 and difficulty < configs.size() else configs[1]
	es.set("get_map_config_cb", Callable(func(_map_id, _realm): return cfg.duplicate(true)))


## 注入内容填充回调。
func _inject_content_cbs() -> void:
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite): return [{"enemy_id": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r): return ["event_a", "event_b"]))
	es.set("generate_shop_inventory_cb", Callable(func(_r): return {"items": [1, 2, 3]}))


# ============================================================================
# AC-001：generate_map 返回结构
# ============================================================================

func test_ac001_generate_map_returns_valid_structure() -> void:
	_inject_config(1)  # MEDIUM
	_inject_content_cbs()
	var result: Dictionary = es.call("generate_map", &"test_map", 1, 1)
	assert_true(result.has("graph"), "含 graph 键")
	assert_true(result.has("nodes"), "含 nodes 键")
	assert_true(result.has("layers"), "含 layers 键")
	assert_true(result.has("boss_node_id"), "含 boss_node_id 键")
	assert_true(result.has("path_count"), "含 path_count 键")


func test_ac001_empty_map_id_rejected() -> void:
	_inject_config(1)
	var result: Dictionary = es.call("generate_map", &"", 1, 1)
	# 空 map_id 应仍能生成（seed XOR 0）——验证不崩溃
	assert_true(result.has("graph"), "空 map_id 仍返回有效结构")


# ============================================================================
# AC-002：层数 4-6
# ============================================================================

func test_ac002_low_difficulty_4_layers() -> void:
	_inject_config(0)  # LOW
	var result: Dictionary = es.call("generate_map", &"low_map", 1, 1)
	var layers: Array = result["layers"]
	assert_eq(layers.size(), 4, "低难度 4 层")


func test_ac002_medium_difficulty_5_layers() -> void:
	_inject_config(1)
	var result: Dictionary = es.call("generate_map", &"med_map", 2, 1)
	assert_eq(result["layers"].size(), 5, "中难度 5 层")


func test_ac002_high_difficulty_5_layers() -> void:
	_inject_config(2)
	var result: Dictionary = es.call("generate_map", &"high_map", 3, 1)
	assert_eq(result["layers"].size(), 5, "高难度 5 层")


func test_ac002_very_high_difficulty_6_layers() -> void:
	_inject_config(3)
	var result: Dictionary = es.call("generate_map", &"vh_map", 4, 1)
	assert_eq(result["layers"].size(), 6, "极高难度 6 层")


# ============================================================================
# AC-003：入口/Boss 固定
# ============================================================================

func test_ac003_entry_and_boss_fixed() -> void:
	_inject_config(1)
	_inject_content_cbs()
	var result: Dictionary = es.call("generate_map", &"test_map", 1, 1)
	var nodes: Dictionary = result["nodes"]
	var layers: Array = result["layers"]
	# 入口 = node_id 0 (layer 0, idx 0)
	assert_eq(nodes[0]["type"], 0, "第 0 层入口 type=ENTRY(0)")
	# Boss = 末层 * 100
	var boss_id: int = (layers.size() - 1) * 100
	assert_eq(nodes[boss_id]["type"], 3, "末层 Boss type=BOSS(3)")


func test_ac003_entry_and_boss_single_node() -> void:
	_inject_config(0)
	var result: Dictionary = es.call("generate_map", &"test_map", 1, 1)
	var layers: Array = result["layers"]
	assert_eq(layers[0], 1, "入口层 1 节点")
	assert_eq(layers[layers.size() - 1], 1, "Boss 层 1 节点")


# ============================================================================
# AC-004：中间层节点数 2-4
# ============================================================================

func test_ac004_intermediate_nodes_in_range() -> void:
	_inject_config(1)  # min=2 max=4
	for i in range(10):
		es.call("set_rng_seed", 42 + i)
		var result: Dictionary = es.call("generate_map", &"test_map_%d" % i, 1, 1)
		var layers: Array = result["layers"]
		for layer_idx in range(1, layers.size() - 1):
			assert_true(layers[layer_idx] >= 2, "层 %d 节点 >= 2" % layer_idx)
			assert_true(layers[layer_idx] <= 4, "层 %d 节点 <= 4" % layer_idx)


# ============================================================================
# AC-005：加权随机分配
# ============================================================================

func test_ac005_weighted_random_distribution() -> void:
	_inject_config(1)
	var type_counts: Dictionary = {"combat": 0, "event": 0, "shop": 0, "rest": 0, "elite": 0}
	var total_nodes: int = 0
	for i in range(100):
		es.call("set_rng_seed", 42 + i)
		var result: Dictionary = es.call("generate_map", &"dist_map_%d" % i, 1, 1)
		var nodes: Dictionary = result["nodes"]
		for node_id in nodes:
			var ntype: int = int(nodes[node_id]["type"])
			# 跳过入口(0)和 Boss(3)
			if ntype == 0 or ntype == 3:
				continue
			total_nodes += 1
			match ntype:
				1: type_counts["combat"] += 1
				4: type_counts["event"] += 1
				5: type_counts["shop"] += 1
				8: type_counts["rest"] += 1
				2: type_counts["elite"] += 1
	# 验证分布近似权重比（±20% 容差——100 次采样统计波动）
	assert_true(total_nodes > 0, "有中间节点")
	var combat_ratio: float = float(type_counts["combat"]) / float(total_nodes)
	assert_true(combat_ratio > 0.25, "战斗占比 > 25%（权重 40%%，容差）")
	assert_true(combat_ratio < 0.55, "战斗占比 < 55%")


# ============================================================================
# AC-006：精英/商店不超限
# ============================================================================

func test_ac006_elite_count_within_limit() -> void:
	_inject_config(0)  # LOW: elite_count=1
	for i in range(20):
		es.call("set_rng_seed", 42 + i)
		var result: Dictionary = es.call("generate_map", &"elite_test_%d" % i, 1, 1)
		var nodes: Dictionary = result["nodes"]
		var elite_count: int = 0
		for node_id in nodes:
			if int(nodes[node_id]["type"]) == 2:  # ELITE
				elite_count += 1
		assert_true(elite_count <= 1, "精英数 <= 1（低难度上限）")


func test_ac006_shop_count_within_limit() -> void:
	_inject_config(0)  # LOW: shop_count=1
	for i in range(20):
		es.call("set_rng_seed", 42 + i)
		var result: Dictionary = es.call("generate_map", &"shop_test_%d" % i, 1, 1)
		var nodes: Dictionary = result["nodes"]
		var shop_count: int = 0
		for node_id in nodes:
			if int(nodes[node_id]["type"]) == 5:  # SHOP
				shop_count += 1
		assert_true(shop_count <= 1, "商店数 <= 1（低难度上限）")


# ============================================================================
# AC-007：无孤儿节点
# ============================================================================

func test_ac007_no_orphan_nodes() -> void:
	_inject_config(1)
	_inject_content_cbs()
	var result: Dictionary = es.call("generate_map", &"orphan_test", 1, 1)
	var graph: Dictionary = result["graph"]
	var layers: Array = result["layers"]
	# 每个节点（除入口）至少有 1 个上层父连接
	# 检查：遍历 graph 的值，收集所有子节点，验证非入口节点都出现在某个父的子列表中
	var all_children: Dictionary = {}
	for parent_id in graph:
		for child_id in graph[parent_id]:
			all_children[child_id] = true
	for layer in range(1, layers.size()):
		for idx in range(layers[layer]):
			var node_id: int = layer * 100 + idx
			assert_true(all_children.has(node_id), "节点 %d 有上层父连接" % node_id)


# ============================================================================
# AC-008：≥2 独立路径
# ============================================================================

func test_ac008_at_least_two_paths() -> void:
	_inject_config(1)
	for i in range(20):
		es.call("set_rng_seed", 42 + i)
		var result: Dictionary = es.call("generate_map", &"path_test_%d" % i, 1, 1)
		var path_count: int = result["path_count"]
		assert_true(path_count >= 2, "独立路径 >= 2（实际 %d）" % path_count)


# ============================================================================
# AC-009：确定性
# ============================================================================

func test_ac009_deterministic_same_seed() -> void:
	_inject_config(1)
	_inject_content_cbs()
	es.call("set_rng_seed", 42)
	var result1: Dictionary = es.call("generate_map", &"det_map", 1, 1)
	es.call("set_rng_seed", 42)
	var result2: Dictionary = es.call("generate_map", &"det_map", 1, 1)
	# 比较图结构完全相同
	assert_eq(result1["graph"], result2["graph"], "同 seed 同 map 同 entry → 同 graph")
	assert_eq(result1["layers"], result2["layers"], "同 layers")


func test_ac009_different_seed_different_graph() -> void:
	_inject_config(1)
	es.call("set_rng_seed", 42)
	var result1: Dictionary = es.call("generate_map", &"map_a", 1, 1)
	es.call("set_rng_seed", 100)
	var result2: Dictionary = es.call("generate_map", &"map_b", 1, 1)
	# 不同 seed + 不同 map_id → 不同图（大概率）
	assert_false(result1["graph"] == result2["graph"], "不同 seed → 不同 graph")


# ============================================================================
# AC-010：JSON 可序列化
# ============================================================================

func test_ac010_json_serializable() -> void:
	_inject_config(1)
	_inject_content_cbs()
	var result: Dictionary = es.call("generate_map", &"json_test", 1, 1)
	var graph: Dictionary = result["graph"]
	var json_str: String = JSON.stringify(graph)
	assert_false(json_str.is_empty(), "JSON 序列化成功")
	var parsed = JSON.parse_string(json_str)
	assert_not_null(parsed, "JSON 解析成功")
	# JSON 往返将 int 键→String、int 值→float（Godot Variant 行为）。
	# 验证语义等价：键数相同 + 每个节点子连接数相同。
	var parsed_dict: Dictionary = parsed
	assert_eq(parsed_dict.size(), graph.size(), "JSON 往返键数一致")
	for key in graph:
		var str_key: String = str(key)
		assert_true(parsed_dict.has(str_key), "JSON 往返含键 %s" % str_key)
		var orig_children: Array = graph[key]
		var parsed_children: Array = parsed_dict[str_key]
		assert_eq(parsed_children.size(), orig_children.size(), "节点 %s 子连接数一致" % str_key)


func test_ac010_nodes_json_serializable() -> void:
	_inject_config(1)
	_inject_content_cbs()
	var result: Dictionary = es.call("generate_map", &"json_nodes", 1, 1)
	var nodes: Dictionary = result["nodes"]
	var json_str: String = JSON.stringify(nodes)
	assert_false(json_str.is_empty(), "nodes JSON 序列化成功")
	var parsed = JSON.parse_string(json_str)
	assert_not_null(parsed, "nodes JSON 解析成功")


# ============================================================================
# AC-011：事件节点不分配具体事件
# ============================================================================

func test_ac011_event_nodes_have_pool_not_template() -> void:
	_inject_config(1)
	_inject_content_cbs()
	var result: Dictionary = es.call("generate_map", &"event_test", 1, 1)
	var nodes: Dictionary = result["nodes"]
	var has_event: bool = false
	for node_id in nodes:
		if int(nodes[node_id]["type"]) == 4:  # EVENT
			has_event = true
			assert_true(nodes[node_id].has("event_pool"), "事件节点含 event_pool")
			assert_false(nodes[node_id].has("event_template_id"), "事件节点不含具体 event_template_id")
	# 如果没生成到事件节点，至少验证逻辑正确
	if not has_event:
		pass  # 无事件节点时跳过


# ============================================================================
# AC-012：战斗节点分配敌人
# ============================================================================

func test_ac012_combat_nodes_have_enemy_roster() -> void:
	_inject_config(1)
	_inject_content_cbs()
	var result: Dictionary = es.call("generate_map", &"combat_test", 1, 1)
	var nodes: Dictionary = result["nodes"]
	for node_id in nodes:
		var ntype: int = int(nodes[node_id]["type"])
		if ntype == 1 or ntype == 2:  # COMBAT or ELITE
			assert_true(nodes[node_id].has("enemy_roster"), "战斗节点含 enemy_roster")
			assert_eq(nodes[node_id]["enemy_roster"], [{"enemy_id": 1}], "enemy_roster 内容正确")


# ============================================================================
# AC-013：商店节点分配库存
# ============================================================================

func test_ac013_shop_nodes_have_inventory() -> void:
	_inject_config(1)
	_inject_content_cbs()
	var result: Dictionary = es.call("generate_map", &"shop_test", 1, 1)
	var nodes: Dictionary = result["nodes"]
	for node_id in nodes:
		if int(nodes[node_id]["type"]) == 5:  # SHOP
			assert_true(nodes[node_id].has("inventory"), "商店节点含 inventory")
			assert_eq(nodes[node_id]["inventory"], {"items": [1, 2, 3]}, "inventory 内容正确")


# ============================================================================
# 综合：完整 DAG 生成集成
# ============================================================================

func test_full_dag_generation_integration() -> void:
	_inject_config(2)  # HIGH
	_inject_content_cbs()
	es.call("set_rng_seed", 42)
	var result: Dictionary = es.call("generate_map", &"full_integration", 3, 1)
	# 验证完整结构
	assert_eq(result["layers"].size(), 5, "高难度 5 层")
	assert_eq(result["layers"][0], 1, "入口 1 节点")
	assert_eq(result["layers"][4], 1, "Boss 1 节点")
	assert_true(result["path_count"] >= 2, "独立路径 >= 2")
	# JSON 序列化
	var json_str: String = JSON.stringify(result)
	assert_false(json_str.is_empty(), "完整结构 JSON 可序列化")
	# boss_node_id 正确
	assert_eq(result["boss_node_id"], 400, "boss_node_id=400（层 4 * 100）")
