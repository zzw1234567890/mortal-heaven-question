extends GutTest
## Story 002 验收测试：导航状态 GSM exploration.* 主存储。
##
## 覆盖 AC-001 到 AC-009（9 条 AC）。
## 测试策略：
##   - 使用 Autoload GSM 实例（非 ES_SCRIPT.new() 的独立实例）
##   - 通过 GSM 第二层方法直接测试写入 + batch_updated 传播
##   - 序列化往返验证 exploration 域完整性
##
## 设计文档来源：ADR-0014 §决策 1 状态分层模型 + §GSM 写入契约
## Story 来源：production/epics/exploration-system/story-002-navigation-gsm.md

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

var gsm: Node = null
var es: Node = null
var _batch_changes: Array = []


func before_each() -> void:
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	# 重置 exploration 域为默认值
	gsm.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	# 重置信号链深度 + 待缓冲变更
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	_batch_changes.clear()
	gsm.batch_updated.connect(_on_batch_updated)


func after_each() -> void:
	if gsm != null and gsm.batch_updated.is_connected(_on_batch_updated):
		gsm.batch_updated.disconnect(_on_batch_updated)
	_batch_changes.clear()
	# 清理 exploration 域
	if gsm != null:
		gsm.exploration = {
			"current_map": &"",
			"node_position": {"layer": 0, "idx": 0},
			"visited_nodes": [],
		"action_points": 0,
			"max_action_points": 0,
			"map_states": {},
		}


func _on_batch_updated(changes: Dictionary) -> void:
	_batch_changes.append(changes.duplicate(true))


## 刷新 GSM 帧末缓冲——等待一帧让 _do_flush 执行。
func _flush() -> void:
	await get_tree().process_frame


# ============================================================================
# AC-001：exploration 域默认值含 6 个字段
# ============================================================================

func test_ac001_exploration_default_has_6_fields() -> void:
	gsm.exploration = gsm.get("_serializer")._get_default_for_domain("exploration")
	var exp: Dictionary = gsm.exploration
	assert_true(exp.has("current_map"), "含 current_map")
	assert_true(exp.has("node_position"), "含 node_position")
	assert_true(exp.has("visited_nodes"), "含 visited_nodes")
	assert_true(exp.has("action_points"), "含 action_points")
	assert_true(exp.has("max_action_points"), "含 max_action_points")
	assert_true(exp.has("map_states"), "含 map_states")


func test_ac001_default_values_correct() -> void:
	gsm.exploration = gsm.get("_serializer")._get_default_for_domain("exploration")
	assert_eq(gsm.exploration["current_map"], &"", "current_map 默认空 StringName")
	assert_eq(gsm.exploration["node_position"], {"layer": 0, "idx": 0}, "node_position 默认入口")
	assert_eq(gsm.exploration["visited_nodes"], [], "visited_nodes 默认空数组")
	assert_eq(gsm.exploration["action_points"], 0, "action_points 默认 0")
	assert_eq(gsm.exploration["max_action_points"], 0, "max_action_points 默认 0")
	assert_eq(gsm.exploration["map_states"], {}, "map_states 默认空字典")


# ============================================================================
# AC-002：set_exploration_map
# ============================================================================

func test_ac002_set_exploration_map() -> void:
	gsm.set_exploration_map(&"test_map")
	await _flush()
	assert_eq(gsm.exploration["current_map"], &"test_map", "current_map 已设置")
	assert_eq(gsm.exploration["node_position"], {"layer": 0, "idx": 0}, "node_position 重置为入口")


func test_ac002_set_exploration_map_batch_updated() -> void:
	gsm.set_exploration_map(&"test_map")
	await _flush()
	assert_true(_batch_changes.size() > 0, "batch_updated 被发射")
	var found_map: bool = false
	var found_pos: bool = false
	for changes in _batch_changes:
		if changes.has("exploration.current_map"):
			found_map = true
		if changes.has("exploration.node_position"):
			found_pos = true
	assert_true(found_map, "batch_updated 含 exploration.current_map")
	assert_true(found_pos, "batch_updated 含 exploration.node_position")


# ============================================================================
# AC-003：set_exploration_position
# ============================================================================

func test_ac003_set_exploration_position() -> void:
	gsm.set_exploration_position(2, 1)
	await _flush()
	assert_eq(gsm.exploration["node_position"], {"layer": 2, "idx": 1}, "node_position 已更新")


func test_ac003_set_exploration_position_batch_updated() -> void:
	gsm.set_exploration_position(3, 0)
	await _flush()
	assert_true(_batch_changes.size() > 0, "batch_updated 被发射")
	var found: bool = false
	for changes in _batch_changes:
		if changes.has("exploration.node_position"):
			found = true
	assert_true(found, "batch_updated 含 exploration.node_position")


# ============================================================================
# AC-004：add_visited_node（去重）
# ============================================================================

func test_ac004_add_visited_node() -> void:
	gsm.add_visited_node(101)
	gsm.add_visited_node(102)
	await _flush()
	assert_eq(gsm.exploration["visited_nodes"], [101, 102], "visited_nodes 已追加")


func test_ac004_add_visited_node_dedup() -> void:
	gsm.add_visited_node(101)
	gsm.add_visited_node(101)  # 重复
	gsm.add_visited_node(102)
	await _flush()
	assert_eq(gsm.exploration["visited_nodes"], [101, 102], "重复节点不追加（去重）")


func test_ac004_add_visited_node_batch_updated() -> void:
	gsm.add_visited_node(201)
	await _flush()
	var found: bool = false
	for changes in _batch_changes:
		if changes.has("exploration.visited_nodes"):
			found = true
	assert_true(found, "batch_updated 含 exploration.visited_nodes")


# ============================================================================
# AC-005：set_exploration_ap
# ============================================================================

func test_ac005_set_exploration_ap() -> void:
	gsm.set_exploration_ap(8, 10)
	await _flush()
	assert_eq(gsm.exploration["action_points"], 8, "action_points 已设置")
	assert_eq(gsm.exploration["max_action_points"], 10, "max_action_points 已设置")


func test_ac005_set_exploration_ap_batch_updated() -> void:
	gsm.set_exploration_ap(5, 10)
	await _flush()
	var found_ap: bool = false
	var found_max: bool = false
	for changes in _batch_changes:
		if changes.has("exploration.action_points"):
			found_ap = true
		if changes.has("exploration.max_action_points"):
			found_max = true
	assert_true(found_ap, "batch_updated 含 exploration.action_points")
	assert_true(found_max, "batch_updated 含 exploration.max_action_points")


# ============================================================================
# AC-006：clear_exploration_navigation
# ============================================================================

func test_ac006_clear_navigation_resets_fields() -> void:
	gsm.set_exploration_map(&"test_map")
	gsm.set_exploration_position(2, 1)
	gsm.add_visited_node(101)
	gsm.add_visited_node(102)
	await _flush()
	_batch_changes.clear()
	gsm.clear_exploration_navigation()
	await _flush()
	assert_eq(gsm.exploration["current_map"], &"", "current_map 已重置")
	assert_eq(gsm.exploration["node_position"], {"layer": 0, "idx": 0}, "node_position 已重置")
	assert_eq(gsm.exploration["visited_nodes"], [], "visited_nodes 已重置")


func test_ac006_clear_navigation_preserves_map_states() -> void:
	gsm.update_exploration_map_state(&"test_map", {"entry_count": 3, "is_first_clear": true})
	await _flush()
	gsm.clear_exploration_navigation()
	await _flush()
	var map_states: Dictionary = gsm.exploration["map_states"]
	assert_true(map_states.has(&"test_map"), "map_states 保留地图状态")
	assert_eq(map_states[&"test_map"]["entry_count"], 3, "entry_count 保留")
	assert_eq(map_states[&"test_map"]["is_first_clear"], true, "is_first_clear 保留")


func test_ac006_clear_navigation_batch_updated() -> void:
	gsm.set_exploration_map(&"test_map")
	await _flush()
	_batch_changes.clear()
	gsm.clear_exploration_navigation()
	await _flush()
	var found_map: bool = false
	var found_pos: bool = false
	var found_visited: bool = false
	for changes in _batch_changes:
		if changes.has("exploration.current_map"):
			found_map = true
		if changes.has("exploration.node_position"):
			found_pos = true
		if changes.has("exploration.visited_nodes"):
			found_visited = true
	assert_true(found_map, "batch_updated 含 current_map 重置")
	assert_true(found_pos, "batch_updated 含 node_position 重置")
	assert_true(found_visited, "batch_updated 含 visited_nodes 重置")


# ============================================================================
# AC-007：update_exploration_map_state
# ============================================================================

func test_ac007_update_map_state() -> void:
	gsm.update_exploration_map_state(&"test_map", {"entry_count": 1})
	await _flush()
	var map_states: Dictionary = gsm.exploration["map_states"]
	assert_true(map_states.has(&"test_map"), "map_states 含 test_map")
	assert_eq(map_states[&"test_map"]["entry_count"], 1, "entry_count 已写入")


func test_ac007_update_map_state_merge() -> void:
	gsm.update_exploration_map_state(&"test_map", {"entry_count": 1, "collected_ling_shi": 50})
	await _flush()
	gsm.update_exploration_map_state(&"test_map", {"collected_cultivation": 30})
	await _flush()
	var state: Dictionary = gsm.exploration["map_states"][&"test_map"]
	assert_eq(state["entry_count"], 1, "entry_count 保留（合并）")
	assert_eq(state["collected_ling_shi"], 50, "collected_ling_shi 保留（合并）")
	assert_eq(state["collected_cultivation"], 30, "collected_cultivation 新增（合并）")


func test_ac007_update_map_state_batch_updated() -> void:
	gsm.update_exploration_map_state(&"test_map", {"entry_count": 1})
	await _flush()
	var found: bool = false
	for changes in _batch_changes:
		for key in changes:
			if key.begins_with("exploration.map_states"):
				found = true
	assert_true(found, "batch_updated 含 exploration.map_states 路径")


# ============================================================================
# AC-008：所有写入通过 batch_updated 传播（综合）
# ============================================================================

func test_ac008_all_writes_propagate_via_batch_updated() -> void:
	gsm.set_exploration_map(&"map_a")
	gsm.set_exploration_position(1, 0)
	gsm.add_visited_node(100)
	gsm.set_exploration_ap(10, 10)
	gsm.update_exploration_map_state(&"map_a", {"entry_count": 1})
	await _flush()
	# 至少应有 5 条不同路径的变更
	var all_paths: Array = []
	for changes in _batch_changes:
		for key in changes:
			if not all_paths.has(key):
				all_paths.append(key)
	assert_true(all_paths.has("exploration.current_map"), "含 current_map 路径")
	assert_true(all_paths.has("exploration.node_position"), "含 node_position 路径")
	assert_true(all_paths.has("exploration.visited_nodes"), "含 visited_nodes 路径")
	assert_true(all_paths.has("exploration.action_points"), "含 action_points 路径")
	assert_true(all_paths.has("exploration.max_action_points"), "含 max_action_points 路径")


# ============================================================================
# AC-009：序列化往返
# ============================================================================

func test_ac009_serialize_deserialize_roundtrip() -> void:
	gsm.set_exploration_map(&"roundtrip_map")
	gsm.set_exploration_position(3, 2)
	gsm.add_visited_node(101)
	gsm.add_visited_node(202)
	gsm.set_exploration_ap(7, 10)
	gsm.update_exploration_map_state(&"roundtrip_map", {"entry_count": 2, "is_first_clear": false})
	await _flush()

	var serialized: Dictionary = gsm.serialize()
	assert_true(serialized.has("exploration"), "序列化含 exploration 域")
	var exp_serialized: Dictionary = serialized["exploration"]
	assert_eq(exp_serialized["current_map"], &"roundtrip_map", "序列化 current_map 正确")
	assert_eq(exp_serialized["node_position"], {"layer": 3, "idx": 2}, "序列化 node_position 正确")
	assert_eq(exp_serialized["visited_nodes"], [101, 202], "序列化 visited_nodes 正确")
	assert_eq(exp_serialized["action_points"], 7, "序列化 action_points 正确")
	assert_eq(exp_serialized["max_action_points"], 10, "序列化 max_action_points 正确")

	# 清空后反序列化
	gsm.exploration = gsm.get("_serializer")._get_default_for_domain("exploration")
	var ok: bool = gsm.deserialize(serialized)
	assert_true(ok, "反序列化成功")
	assert_eq(gsm.exploration["current_map"], &"roundtrip_map", "反序列化 current_map 正确")
	assert_eq(gsm.exploration["node_position"], {"layer": 3, "idx": 2}, "反序列化 node_position 正确")
	assert_eq(gsm.exploration["visited_nodes"], [101, 202], "反序列化 visited_nodes 正确")
	assert_eq(gsm.exploration["action_points"], 7, "反序列化 action_points 正确")
	assert_eq(gsm.exploration["max_action_points"], 10, "反序列化 max_action_points 正确")
	var ms: Dictionary = gsm.exploration["map_states"]
	assert_true(ms.has(&"roundtrip_map"), "反序列化 map_states 含地图")
	assert_eq(ms[&"roundtrip_map"]["entry_count"], 2, "反序列化 entry_count 正确")


# ============================================================================
# 综合：ExplorationSystem.enter_map 集成
# ============================================================================

func test_enter_map_integration() -> void:
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	es.set("get_map_config_cb", Callable(func(_mid, _r):
		return es.get("DIFFICULTY_CONFIGS")[1].duplicate(true)))
	var result: Dictionary = es.call("enter_map", &"integration_map", 1, 10)
	await _flush()
	assert_true(result.has("graph"), "enter_map 返回图结构")
	assert_eq(gsm.exploration["current_map"], &"integration_map", "GSM current_map 已写入")
	assert_eq(gsm.exploration["action_points"], 10, "GSM action_points 已写入")
	assert_eq(gsm.exploration["max_action_points"], 10, "GSM max_action_points 已写入")
	var ms: Dictionary = gsm.exploration["map_states"]
	assert_true(ms.has(&"integration_map"), "GSM map_states 含地图")
	assert_eq(ms[&"integration_map"]["entry_count"], 1, "entry_count 递增为 1")
	es.free()
	es = null
