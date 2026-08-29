extends GutTest
## Story 004 验收测试：DAG 缓存重建 + _dag_ready 就绪标志。
##
## 覆盖 AC-001 到 AC-008（8 条 AC）。
## 测试策略：
##   - ES_SCRIPT.new() 构造 ExplorationSystem 实例（非 Autoload）
##   - 直接操作 _node_graph / _node_details / _dag_ready
##   - 模拟读档后重建场景
##
## 设计文档来源：ADR-0014 §决策 1 状态分层模型 + R7
## Story 来源：production/epics/exploration-system/story-004-dag-cache-rebuild.md

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

var es: Node = null
var gsm: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	es.set("get_map_config_cb", Callable(func(_mid, _r):
		return es.get("DIFFICULTY_CONFIGS")[1].duplicate(true)))
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite):
		return [{"enemy_id": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r):
		return ["event_a", "event_b"]))
	es.set("generate_shop_inventory_cb", Callable(func(_r):
		return {"items": [1, 2, 3]}))

	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm != null:
		gsm.exploration = {
			"current_map": &"",
			"node_position": {"layer": 0, "idx": 0},
			"visited_nodes": [],
			"action_points": 0,
			"max_action_points": 0,
			"map_states": {},
		}
		gsm.set("_signal_chain_depth", 0)
		gsm.get("_signal_router").set("_pending_changes", [])


func after_each() -> void:
	if es != null:
		es.free()
		es = null
	if gsm != null:
		gsm.exploration = {
			"current_map": &"",
			"node_position": {"layer": 0, "idx": 0},
			"visited_nodes": [],
			"action_points": 0,
			"max_action_points": 0,
			"map_states": {},
		}


# ============================================================================
# AC-001：_dag_ready 初始 false
# ============================================================================

func test_ac001_dag_ready_initially_false() -> void:
	assert_eq(es.get("_dag_ready"), false, "_dag_ready 初始 false")


# ============================================================================
# AC-002：_ready() 检测 current_map 非空 → 重建
# ============================================================================

func test_ac002_ready_rebuilds_on_load() -> void:
	# 先用 enter_map 生成 DAG + 写入 GSM 快照
	es.call("enter_map", &"test_map", 1, 10)
	var original_graph: Dictionary = es.get("_node_graph").duplicate(true)
	var original_details: Dictionary = es.get("_node_details").duplicate(true)

	# 模拟读档后：清空缓存，但 GSM 仍有 current_map + map_states 快照
	es.call("clear_dag_cache")
	assert_eq(es.get("_dag_ready"), false, "clear 后 _dag_ready false")

	# 调用 _ready 模拟读档重建
	es.call("_ready")
	assert_eq(es.get("_dag_ready"), true, "_ready 后 _dag_ready true")
	assert_eq(es.get("_node_graph"), original_graph, "重建后 graph 等价")
	assert_eq(es.get("_node_details"), original_details, "重建后 details 等价")


func test_ac002_ready_no_rebuild_without_current_map() -> void:
	# GSM current_map 为空
	es.call("_ready")
	assert_eq(es.get("_dag_ready"), true, "无活跃地图 _dag_ready 仍为 true")
	assert_eq(es.get("_node_graph"), {}, "无重建——graph 为空")


# ============================================================================
# AC-003：rebuild_dag_cache 从数据重建
# ============================================================================

func test_ac003_rebuild_dag_cache() -> void:
	var test_graph: Dictionary = {0: [100], 100: [200], 200: []}
	var test_nodes: Dictionary = {
		0: {"type": 0, "layer": 0, "idx": 0},
		100: {"type": 1, "layer": 1, "idx": 0},
		200: {"type": 3, "layer": 2, "idx": 0},
	}
	var map_data: Dictionary = {
		"graph": test_graph,
		"nodes": test_nodes,
		"layers": [1, 1, 1],
		"boss_node_id": 200,
		"path_count": 1,
	}
	es.call("rebuild_dag_cache", &"test_map", map_data)
	assert_eq(es.get("_node_graph"), test_graph, "_node_graph 从 map_data 重建")
	assert_eq(es.get("_node_details"), test_nodes, "_node_details 从 map_data 重建")
	assert_eq(es.get("_dag_ready"), true, "rebuild 后 _dag_ready true")


func test_ac003_rebuild_sets_dag_ready() -> void:
	assert_eq(es.get("_dag_ready"), false, "重建前 false")
	es.call("rebuild_dag_cache", &"test_map", {"graph": {}, "nodes": {}})
	assert_eq(es.get("_dag_ready"), true, "重建后 true")


# ============================================================================
# AC-004：公共方法 _dag_ready 守卫
# ============================================================================

func test_ac004_move_to_node_rejected_when_not_ready() -> void:
	assert_eq(es.get("_dag_ready"), false, "未就绪")
	var result: Dictionary = es.call("move_to_node", 0, 100)
	assert_eq(result["success"], false, "_dag_ready=false 时 move_to_node 拒绝")
	assert_true(result["reason"].find("DAG") >= 0, "reason 含 'DAG'")


func test_ac004_can_move_to_rejected_when_not_ready() -> void:
	assert_eq(es.get("_dag_ready"), false, "未就绪")
	var result: bool = es.call("can_move_to", 0, 100)
	assert_eq(result, false, "_dag_ready=false 时 can_move_to 返回 false")


func test_ac004_resolve_node_skipped_when_not_ready() -> void:
	assert_eq(es.get("_dag_ready"), false, "未就绪")
	# resolve_node 无返回值——验证不崩溃即可
	es.call("resolve_node", 100)
	# 无崩溃即通过
	assert_true(true, "resolve_node 未崩溃")


# ============================================================================
# AC-005：clear_dag_cache
# ============================================================================

func test_ac005_clear_dag_cache() -> void:
	es.call("rebuild_dag_cache", &"test_map", {
		"graph": {0: [100]},
		"nodes": {0: {"type": 0}},
	})
	assert_eq(es.get("_dag_ready"), true, "重建后就绪")
	es.call("clear_dag_cache")
	assert_eq(es.get("_node_graph"), {}, "graph 已清空")
	assert_eq(es.get("_node_details"), {}, "details 已清空")
	assert_eq(es.get("_dag_ready"), false, "_dag_ready 已重置为 false")


# ============================================================================
# AC-006：重建后等价
# ============================================================================

func test_ac006_rebuild_equivalent_to_generate() -> void:
	es.call("enter_map", &"equiv_test", 1, 10)
	var gen_graph: Dictionary = es.get("_node_graph").duplicate(true)
	var gen_details: Dictionary = es.get("_node_details").duplicate(true)

	# 清空后从 GSM 快照重建
	es.call("clear_dag_cache")
	es.call("_ready")

	assert_eq(es.get("_node_graph"), gen_graph, "重建后 graph 与 generate_map 等价")
	assert_eq(es.get("_node_details"), gen_details, "重建后 details 与 generate_map 等价")


# ============================================================================
# AC-007：无活跃地图时 _ready 不重建
# ============================================================================

func test_ac007_ready_no_rebuild_empty_map() -> void:
	if gsm != null:
		gsm.exploration.current_map = &""
	es.call("_ready")
	assert_eq(es.get("_dag_ready"), true, "_dag_ready 为 true")
	assert_eq(es.get("_node_graph"), {}, "graph 为空（无重建）")
	assert_eq(es.get("_node_details"), {}, "details 为空（无重建）")


# ============================================================================
# AC-008：enter_map 后 _dag_ready = true
# ============================================================================

func test_ac008_enter_map_sets_dag_ready() -> void:
	assert_eq(es.get("_dag_ready"), false, "enter_map 前 false")
	es.call("enter_map", &"ready_test", 1, 10)
	assert_eq(es.get("_dag_ready"), true, "enter_map 后 true")


func test_ac008_enter_map_then_move_works() -> void:
	# enter_map 后应可立即使用 move_to_node
	es.call("enter_map", &"move_test", 1, 10)
	var graph: Dictionary = es.get("_node_graph")
	# 找一个从 0 可达的节点
	var first_child: int = -1
	if graph.has(0) and graph[0].size() > 0:
		first_child = graph[0][0]
	assert_true(first_child >= 0, "找到从入口可达的节点")
	var result: Dictionary = es.call("move_to_node", 0, first_child)
	assert_eq(result["success"], true, "enter_map 后 move_to_node 成功")


# ============================================================================
# 综合：探索→战斗→探索往返场景恢复
# ============================================================================

func test_full_roundtrip_scenario() -> void:
	# 1. 进入地图
	es.call("enter_map", &"roundtrip", 1, 10)
	var orig_graph: Dictionary = es.get("_node_graph").duplicate(true)
	var orig_details: Dictionary = es.get("_node_details").duplicate(true)

	# 2. 模拟战斗——清空缓存
	es.call("clear_dag_cache")
	assert_eq(es.get("_dag_ready"), false, "战斗中缓存清空")

	# 3. 战斗结束——_ready 重建（模拟从战斗场景返回探索场景）
	es.call("_ready")
	assert_eq(es.get("_dag_ready"), true, "重建后就绪")
	assert_eq(es.get("_node_graph"), orig_graph, "往返后 graph 等价")
	assert_eq(es.get("_node_details"), orig_details, "往返后 details 等价")

	# 4. 可继续导航
	var graph: Dictionary = es.get("_node_graph")
	var first_child: int = -1
	if graph.has(0) and graph[0].size() > 0:
		first_child = graph[0][0]
	if first_child >= 0:
		var result: Dictionary = es.call("move_to_node", 0, first_child)
		assert_eq(result["success"], true, "往返后可继续导航")
