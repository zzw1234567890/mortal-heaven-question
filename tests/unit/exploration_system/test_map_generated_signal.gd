extends GutTest
## ExplorationSystem.map_generated 信号单测（ADR-0014 §决策 3 信号表）。[br]
## [br][b]为什么单独一处[/b]：信号是探索系统与节点图 UI 之间[b]唯一[/b]的数据
## 交接面——载荷少一个键、AP 口径与 GSM 不一致，UI 就只能猜。本文件锁死三件事：[br]
##   1. 只有 [method enter_map] 广播（[method generate_map] 是纯生成，不惊动 UI）；[br]
##   2. 载荷的 graph/nodes 与系统缓存同源，visited/current_node/ap_remaining
##      与 GSM 实际写入值一致；[br]
##   3. 换图时已访问集合被重置为「入口」——上一张图的路径不会画进新图。[br]
##
## 来源: ADR-0014 §决策 3、GDD exploration-system.md §4、story-003 数据契约。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

var es: Node = null
var gsm: Node = null
var _emitted: Array = []


func before_each() -> void:
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	es.set("get_map_config_cb", Callable(func(_mid, _r):
		return (es.get("DIFFICULTY_CONFIGS") as Array)[1].duplicate(true)))
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite):
		return [{"template_id": &"san_xiu", "name": "散修", "realm": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r): return []))
	es.set("generate_shop_inventory_cb", Callable(func(_r): return {}))
	_emitted.clear()
	es.map_generated.connect(func(map_id: StringName, map_data: Dictionary) -> void:
		_emitted.append([map_id, map_data]))
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	_reset_gsm()


func after_each() -> void:
	_reset_gsm()
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 发射时机
# ═══════════════════════════════════════════════════════════════════════════════

func test_enter_map_emits_map_generated_once() -> void:
	# Act
	es.call("enter_map", &"qing_yun_jian_zong", 1, 5)
	# Assert
	assert_eq(_emitted.size(), 1, "enter_map 应恰好广播一次 map_generated")
	assert_eq(_emitted[0][0], &"qing_yun_jian_zong", "载荷地图 ID 应为入参")


func test_generate_map_does_not_emit_map_generated() -> void:
	# generate_map 是纯生成（不写导航状态）——不应惊动 UI
	es.call("generate_map", &"qing_yun_jian_zong", 1, 1)
	assert_eq(_emitted.size(), 0, "generate_map 不广播 map_generated（只有 enter_map 广播）")


func test_signal_declared_on_system() -> void:
	# UI 的降级判定读 has_signal——信号必须在系统上声明
	assert_true(es.has_signal(&"map_generated"), "ExplorationSystem 应声明 map_generated 信号")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 载荷契约（UI 消费面）
# ═══════════════════════════════════════════════════════════════════════════════

func test_payload_carries_render_snapshot_keys() -> void:
	# Act
	es.call("enter_map", &"qing_yun_jian_zong", 1, 5)
	var data: Dictionary = _emitted[0][1]
	# Assert——NodeGraphScreen 消费的五个键齐备
	for key: String in ["graph", "nodes", "visited", "current_node", "ap_remaining"]:
		assert_true(data.has(key), "map_data 应含渲染键 %s" % key)
	assert_eq(int(data["current_node"]), 0, "当前节点应为入口 0")
	assert_eq(data["visited"], [0] as Array, "入口应记为已访问")
	assert_eq(int(data["ap_remaining"]), 5, "AP 取 enter_map 的 max_ap")


func test_payload_graph_and_nodes_match_system_cache() -> void:
	# Act
	es.call("enter_map", &"xue_yuan_mi_jing", 1, 7)
	var data: Dictionary = _emitted[0][1]
	# Assert——载荷与系统缓存同源（UI 渲染的图就是系统判定的图）
	assert_eq(data["graph"], es.get("_node_graph"), "载荷 graph 与系统缓存一致")
	assert_eq(data["nodes"], es.get("_node_details"), "载荷 nodes 与系统缓存一致")


func test_payload_ap_matches_gsm_written_value() -> void:
	# Act
	es.call("enter_map", &"qing_yun_jian_zong", 1, 9)
	# Assert——信号说的 AP 就是 GSM 里写的 AP（口径不分裂）
	assert_eq(int(_emitted[0][1]["ap_remaining"]),
			int(gsm.exploration.get("action_points", -1)), "载荷 AP 与 GSM 一致")
	assert_eq(int(gsm.exploration.get("max_action_points", -1)), 9, "GSM 上限同步写入")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 换图重置已访问（防上一张图的路径串色）
# ═══════════════════════════════════════════════════════════════════════════════

func test_enter_map_resets_stale_visited_nodes() -> void:
	# Arrange——上一张图留下的已访问路径
	gsm.exploration.visited_nodes = [0, 100, 200]
	# Act
	es.call("enter_map", &"dan_xia_gu", 1, 5)
	# Assert——新图只有入口已访问
	assert_eq(gsm.exploration.visited_nodes, [0] as Array,
			"进入地图应重置已访问为「仅入口」")
	assert_eq(_emitted[0][1]["visited"], [0] as Array, "载荷与 GSM 同口径")


func test_enter_map_node_count_matches_payload() -> void:
	# Act
	es.call("enter_map", &"qing_yun_jian_zong", 1, 5)
	var data: Dictionary = _emitted[0][1]
	# Assert——载荷节点数 = 系统缓存节点数（UI 渲染节点数应与系统一致）
	assert_eq((data["nodes"] as Dictionary).size(),
			(es.get("_node_details") as Dictionary).size(),
			"载荷节点数应与系统一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 重置 GSM 探索域（enter_map 会写 current_map / visited / ap / map_states）。
func _reset_gsm() -> void:
	if gsm == null:
		return
	gsm.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	gsm.set("_signal_chain_depth", 0)
	var router: Variant = gsm.get("_signal_router")
	if router != null:
		router.set("_pending_changes", [])
