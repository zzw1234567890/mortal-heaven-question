extends GutTest
## Story 003 验收测试：move_to_node / resolve_node 节点推进。
##
## 覆盖 AC-001 到 AC-011（11 条 AC）。
## 测试策略：
##   - ES_SCRIPT.new() 构造 ExplorationSystem 实例
##   - 注入回调生成已知 DAG 结构
##   - 直接操作 _node_graph / _node_details 测试验证链路
##   - 通过 GSM Autoload 测试导航状态写入
##
## 设计文档来源：ADR-0014 §关键接口 + §决策 3 信号委托 + GDD §4
## Story 来源：production/epics/exploration-system/story-003-move-resolve-node.md

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

var es: Node = null
var gsm: Node = null
var _node_moved_signals: Array = []
var _event_reached: Array = []
var _combat_reached: Array = []
var _boss_reached: Array = []
var _interaction_triggered: Array = []


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

	# 信号捕获
	_node_moved_signals.clear()
	_event_reached.clear()
	_combat_reached.clear()
	_boss_reached.clear()
	_interaction_triggered.clear()
	es.node_moved.connect(_on_node_moved)
	es.event_node_reached.connect(_on_event_reached)
	es.combat_node_reached.connect(_on_combat_reached)
	es.boss_node_reached.connect(_on_boss_reached)
	es.node_interaction_triggered.connect(_on_interaction_triggered)


func after_each() -> void:
	if es != null:
		if es.node_moved.is_connected(_on_node_moved):
			es.node_moved.disconnect(_on_node_moved)
		if es.event_node_reached.is_connected(_on_event_reached):
			es.event_node_reached.disconnect(_on_event_reached)
		if es.combat_node_reached.is_connected(_on_combat_reached):
			es.combat_node_reached.disconnect(_on_combat_reached)
		if es.boss_node_reached.is_connected(_on_boss_reached):
			es.boss_node_reached.disconnect(_on_boss_reached)
		if es.node_interaction_triggered.is_connected(_on_interaction_triggered):
			es.node_interaction_triggered.disconnect(_on_interaction_triggered)
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


# === 信号捕获 ================================================================

func _on_node_moved(from: int, to: int, ap: int) -> void:
	_node_moved_signals.append({"from": from, "to": to, "ap": ap})

func _on_event_reached(pool: Array, realm: int) -> void:
	_event_reached.append({"pool": pool, "realm": realm})

func _on_combat_reached(roster: Array, ctype: StringName) -> void:
	_combat_reached.append({"roster": roster, "type": ctype})

func _on_boss_reached(data: Dictionary) -> void:
	_boss_reached.append(data)

func _on_interaction_triggered(nid: int, itype: StringName, payload: Dictionary) -> void:
	_interaction_triggered.append({"node_id": nid, "type": itype, "payload": payload})


# === 辅助 ================================================================

## 设置一个简单的线性 DAG 用于测试：0→100→200→300→400
## 注：为测试已访问回退，100→0 边也被加入（仅测试用途，真实 DAG 无回退边）
func _setup_linear_dag() -> void:
	es.set("_node_graph", {
		0: [100],
		100: [200, 0],  # 含回退边 100→0 用于测试已访问拒绝
		200: [300],
		300: [400],
		400: [],
	})
	es.set("_node_details", {
		0: {"type": 0, "layer": 0, "idx": 0},  # ENTRY
		100: {"type": 1, "layer": 1, "idx": 0},  # COMBAT
		200: {"type": 4, "layer": 2, "idx": 0, "event_pool": ["event_a", "event_b"]},  # EVENT
		300: {"type": 8, "layer": 3, "idx": 0},  # REST
		400: {"type": 3, "layer": 4, "idx": 0},  # BOSS
	})
	if gsm != null:
		gsm.exploration.action_points = 10
		gsm.exploration.max_action_points = 10
		gsm.exploration.visited_nodes = [0]
		gsm.exploration.node_position = {"layer": 0, "idx": 0}
	es.set("_dag_ready", true)


## 设置带豁免节点的 DAG
func _setup_exempt_dag() -> void:
	es.set("_node_graph", {
		0: [100, 200],
		100: [300],  # 100→300 (BOSS)
		200: [300],  # 200→300
		300: [],     # BOSS
	})
	es.set("_node_details", {
		0: {"type": 0, "layer": 0, "idx": 0},  # ENTRY
		100: {"type": 6, "layer": 1, "idx": 0},  # TELEPORT
		200: {"type": 7, "layer": 1, "idx": 1},  # ACTION_SPRING
		300: {"type": 3, "layer": 2, "idx": 0},  # BOSS
	})
	if gsm != null:
		gsm.exploration.visited_nodes = [0]
		gsm.exploration.node_position = {"layer": 0, "idx": 0}
	es.set("_dag_ready", true)


## 设置带商店和渡劫台的 DAG
func _setup_shop_tribulation_dag() -> void:
	es.set("_node_graph", {
		0: [100],
		100: [200],
		200: [300],
		300: [],
	})
	es.set("_node_details", {
		0: {"type": 0, "layer": 0, "idx": 0},  # ENTRY
		100: {"type": 5, "layer": 1, "idx": 0, "inventory": {"items": [1,2,3]}},  # SHOP
		200: {"type": 9, "layer": 2, "idx": 0},  # TRIBULATION
		300: {"type": 2, "layer": 3, "idx": 0, "enemy_roster": [{"enemy_id": 2}]},  # ELITE
	})
	if gsm != null:
		gsm.exploration.visited_nodes = [0]
		gsm.exploration.node_position = {"layer": 0, "idx": 0}
		gsm.exploration.action_points = 10
		gsm.exploration.max_action_points = 10
	es.set("_dag_ready", true)


# ============================================================================
# AC-001：move_to_node 返回结构
# ============================================================================

func test_ac001_move_to_node_returns_valid_structure() -> void:
	_setup_linear_dag()
	var result: Dictionary = es.call("move_to_node", 0, 100)
	assert_true(result.has("success"), "含 success")
	assert_true(result.has("reason"), "含 reason")
	assert_true(result.has("ap_remaining"), "含 ap_remaining")
	assert_eq(result["success"], true, "成功移动")
	assert_eq(result["reason"], "", "成功时 reason 为空")
	assert_eq(result["ap_remaining"], 9, "AP 从 10 减为 9")


# ============================================================================
# AC-002：可达性验证——非邻接节点拒绝
# ============================================================================

func test_ac002_unreachable_rejected() -> void:
	_setup_linear_dag()
	var result: Dictionary = es.call("move_to_node", 0, 200)  # 0→200 无边
	assert_eq(result["success"], false, "不可达节点拒绝")
	assert_true(result["reason"].find("不可达") >= 0, "reason 含 '不可达'")


func test_ac002_nonexistent_from_rejected() -> void:
	_setup_linear_dag()
	var result: Dictionary = es.call("move_to_node", 999, 100)
	assert_eq(result["success"], false, "不存在的 from 节点拒绝")


# ============================================================================
# AC-003：已访问节点拒绝（不可回退）
# ============================================================================

func test_ac003_visited_rejected() -> void:
	_setup_linear_dag()
	# 先移动到 100
	es.call("move_to_node", 0, 100)
	# 尝试从 100 回退到 0（已访问）
	var result: Dictionary = es.call("move_to_node", 100, 0)
	assert_eq(result["success"], false, "已访问节点拒绝")
	assert_true(result["reason"].find("已访问") >= 0, "reason 含 '已访问'")


# ============================================================================
# AC-004：行动力不足拒绝（非豁免节点）
# ============================================================================

func test_ac004_ap_insufficient_rejected() -> void:
	_setup_linear_dag()
	if gsm != null:
		gsm.exploration.action_points = 0
	var result: Dictionary = es.call("move_to_node", 0, 100)  # COMBAT 非豁免
	assert_eq(result["success"], false, "AP 不足拒绝")
	assert_true(result["reason"].find("行动力不足") >= 0, "reason 含 '行动力不足'")


# ============================================================================
# AC-005：AP=0 豁免——传送/行动力泉/Boss
# ============================================================================

func test_ac005_boss_ap_exempt() -> void:
	_setup_exempt_dag()
	if gsm != null:
		gsm.exploration.action_points = 0
		# 先访问 100 (TELEPORT)，不消耗 AP
	var r1: Dictionary = es.call("move_to_node", 0, 100)  # TELEPORT 豁免
	assert_eq(r1["success"], true, "传送节点 AP=0 可移动")
	assert_eq(r1["ap_remaining"], 0, "传送不消耗 AP")


func test_ac005_action_spring_ap_exempt() -> void:
	_setup_exempt_dag()
	if gsm != null:
		gsm.exploration.action_points = 0
	var result: Dictionary = es.call("move_to_node", 0, 200)  # ACTION_SPRING 豁免
	assert_eq(result["success"], true, "行动力泉 AP=0 可移动")
	assert_eq(result["ap_remaining"], 0, "行动力泉不消耗 AP")


func test_ac005_boss_from_high_ap_exempt() -> void:
	_setup_exempt_dag()
	if gsm != null:
		gsm.exploration.action_points = 5
		gsm.exploration.visited_nodes = [0, 100]
	# 从 100 移动到 300 (BOSS)
	var result: Dictionary = es.call("move_to_node", 100, 300)
	assert_eq(result["success"], true, "Boss 节点可移动")
	assert_eq(result["ap_remaining"], 5, "Boss 不消耗 AP")


# ============================================================================
# AC-006：AP 消耗（非豁免节点）
# ============================================================================

func test_ac006_ap_consumed() -> void:
	_setup_linear_dag()
	if gsm != null:
		gsm.exploration.action_points = 5
	var result: Dictionary = es.call("move_to_node", 0, 100)  # COMBAT 非豁免
	assert_eq(result["ap_remaining"], 4, "AP 从 5 减为 4")
	assert_eq(gsm.exploration["action_points"], 4, "GSM action_points 已更新")


# ============================================================================
# AC-007：GSM 导航状态更新
# ============================================================================

func test_ac007_gsm_position_updated() -> void:
	_setup_linear_dag()
	es.call("move_to_node", 0, 100)
	assert_eq(gsm.exploration["node_position"], {"layer": 1, "idx": 0}, "node_position 更新为目标节点")


func test_ac007_gsm_visited_updated() -> void:
	_setup_linear_dag()
	es.call("move_to_node", 0, 100)
	assert_true(gsm.exploration["visited_nodes"].has(100), "visited_nodes 含目标节点")


# ============================================================================
# AC-008：can_move_to 只读查询
# ============================================================================

func test_ac008_can_move_to_readonly() -> void:
	_setup_linear_dag()
	if gsm != null:
		gsm.exploration.action_points = 5
	# 多次调用不改变状态
	var ap_before: int = gsm.exploration["action_points"]
	var visited_before: int = gsm.exploration["visited_nodes"].size()
	var r1: bool = es.call("can_move_to", 0, 100)
	var r2: bool = es.call("can_move_to", 0, 100)
	assert_eq(r1, true, "can_move_to 可达")
	assert_eq(r2, true, "多次调用结果一致")
	assert_eq(gsm.exploration["action_points"], ap_before, "AP 未变化")
	assert_eq(gsm.exploration["visited_nodes"].size(), visited_before, "visited_nodes 未变化")


func test_ac008_can_move_to_unreachable() -> void:
	_setup_linear_dag()
	var result: bool = es.call("can_move_to", 0, 200)  # 无边
	assert_eq(result, false, "不可达 false")


func test_ac008_can_move_to_visited() -> void:
	_setup_linear_dag()
	if gsm != null:
		gsm.exploration.visited_nodes = [0, 100]
	var result: bool = es.call("can_move_to", 100, 0)  # 0 已访问
	assert_eq(result, false, "已访问 false")


func test_ac008_can_move_to_ap_insufficient() -> void:
	_setup_linear_dag()
	if gsm != null:
		gsm.exploration.action_points = 0
	var result: bool = es.call("can_move_to", 0, 100)  # COMBAT 非豁免
	assert_eq(result, false, "AP 不足 false")


# ============================================================================
# AC-009：resolve_node 信号分发
# ============================================================================

func test_ac009_resolve_event_emits_event_reached() -> void:
	_setup_linear_dag()
	es.call("resolve_node", 200)  # EVENT
	assert_eq(_event_reached.size(), 1, "event_node_reached 发射")
	assert_eq(_event_reached[0]["pool"], ["event_a", "event_b"], "event_pool 正确")


func test_ac009_resolve_combat_emits_combat_reached() -> void:
	_setup_linear_dag()
	es.call("resolve_node", 100)  # COMBAT
	assert_eq(_combat_reached.size(), 1, "combat_node_reached 发射")
	assert_eq(_combat_reached[0]["type"], &"combat", "combat_type 正确")


func test_ac009_resolve_boss_emits_boss_reached() -> void:
	_setup_linear_dag()
	es.call("resolve_node", 400)  # BOSS
	assert_eq(_boss_reached.size(), 1, "boss_node_reached 发射")


func test_ac009_resolve_shop_emits_interaction_triggered() -> void:
	_setup_shop_tribulation_dag()
	es.call("resolve_node", 100)  # SHOP
	assert_eq(_interaction_triggered.size(), 1, "node_interaction_triggered 发射")
	assert_eq(_interaction_triggered[0]["type"], &"shop", "interaction_type=shop")
	assert_eq(_interaction_triggered[0]["payload"]["inventory"], {"items": [1, 2, 3]}, "inventory 正确")


func test_ac009_resolve_rest_emits_interaction() -> void:
	_setup_linear_dag()
	es.call("resolve_node", 300)  # REST
	assert_eq(_interaction_triggered.size(), 1, "rest → interaction_triggered")
	assert_eq(_interaction_triggered[0]["type"], &"rest", "type=rest")


func test_ac009_resolve_elite_emits_combat_reached() -> void:
	_setup_shop_tribulation_dag()
	es.call("resolve_node", 300)  # ELITE
	assert_eq(_combat_reached.size(), 1, "elite → combat_node_reached")
	assert_eq(_combat_reached[0]["type"], &"elite", "type=elite")


func test_ac009_resolve_tribulation_emits_interaction() -> void:
	_setup_shop_tribulation_dag()
	es.call("resolve_node", 200)  # TRIBULATION
	assert_eq(_interaction_triggered.size(), 1, "tribulation → interaction_triggered")
	assert_eq(_interaction_triggered[0]["type"], &"tribulation", "type=tribulation")


# ============================================================================
# AC-010：move_to_node 成功后自动调用 resolve_node
# ============================================================================

func test_ac010_move_auto_resolves() -> void:
	_setup_linear_dag()
	if gsm != null:
		gsm.exploration.action_points = 10
	es.call("move_to_node", 0, 100)  # COMBAT 节点
	# move_to_node 应自动调用 resolve_node → 发射 combat_node_reached
	assert_eq(_combat_reached.size(), 1, "move_to_node 自动触发 combat_node_reached")


func test_ac010_move_to_event_auto_resolves() -> void:
	_setup_linear_dag()
	if gsm != null:
		gsm.exploration.action_points = 10
	# 先到 100
	es.call("move_to_node", 0, 100)
	_combat_reached.clear()
	# 再到 200 (EVENT)
	es.call("move_to_node", 100, 200)
	assert_eq(_event_reached.size(), 1, "move_to_node 到事件节点自动触发 event_node_reached")


# ============================================================================
# AC-011：node_moved 信号
# ============================================================================

func test_ac011_node_moved_signal_emitted() -> void:
	_setup_linear_dag()
	if gsm != null:
		gsm.exploration.action_points = 10
	es.call("move_to_node", 0, 100)
	assert_eq(_node_moved_signals.size(), 1, "node_moved 发射")
	assert_eq(_node_moved_signals[0]["from"], 0, "from 正确")
	assert_eq(_node_moved_signals[0]["to"], 100, "to 正确")
	assert_eq(_node_moved_signals[0]["ap"], 9, "ap_remaining 正确")


func test_ac011_node_moved_exempt_no_ap_cost() -> void:
	_setup_exempt_dag()
	if gsm != null:
		gsm.exploration.action_points = 3
	es.call("move_to_node", 0, 100)  # TELEPORT 豁免
	assert_eq(_node_moved_signals.size(), 1, "node_moved 发射")
	assert_eq(_node_moved_signals[0]["ap"], 3, "豁免节点 ap_remaining 不变")
