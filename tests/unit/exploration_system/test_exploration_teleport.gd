extends GutTest
## 传送节点单元测试：可跳转层列表 + 跨层跳转执行。[br]
## [br][b]覆盖[/b]：[br]
##   - 目标层解锁判定（GDD §8 边界「目标层必须已解锁，否则传送节点不可激活」）；[br]
##   - 可跳列表排除当前层（GDD §4 禁同层横向移动）与已访问节点；[br]
##   - 跳转真的写 GSM 位置 + 标记已访问 + 发 node_moved + 触发 resolve_node；[br]
##   - 传送消耗 0 行动力（GDD §节点类型一览），AP=0 时同样可跳；[br]
##   - 拒绝路径（不可跳层 / 缓存未就绪 / GSM 不可用）返回可读 reason。[br]
## [br][b]层号口径[/b]：节点 ID 编码 [code]layer * 100 + idx[/code]，故 200 号节点
## 属于[b]第 2 层[/b]——本文件的断言一律用这个 0 基索引（玩家看到的 1 基层号由
## UI 侧 +1）。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域在 [code]before_each[/code] 快照、
## [code]after_each[/code] 原样还原——跳转会写位置与已访问。[br]
##
## 来源: GDD exploration-system.md §4 移动规则 / §节点类型一览 / §8 边界、
## ADR-0014 §决策 3（node_moved 信号）。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

## 用例 DAG——入口 0（第 0 层）→ 传送 100（第 1 层）→ 200/201（第 2 层）
## → 300（第 3 层）→ 400（第 4 层）。
const TELEPORT_NODE: int = 100
const TARGET_A: int = 200
const TARGET_B: int = 201
const DEEP_NODE: int = 300
const DEEPEST_NODE: int = 400
## 第 2 层 / 第 3 层的层索引（节点 ID 整除 100 得来）。
const TARGET_LAYER: int = 2
const DEEP_LAYER: int = 3

var es: Node = null
var _exploration_before: Dictionary = {}
var _moved: Array = []
var _interactions: Array = []


func before_each() -> void:
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	GameStateManager.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	_moved.clear()
	_interactions.clear()
	es = ES_SCRIPT.new()
	es.node_moved.connect(func(f: int, t: int, ap: int) -> void:
		_moved.append({"from": f, "to": t, "ap": ap}))
	es.node_interaction_triggered.connect(func(nid: int, itype: StringName,
			_payload: Dictionary) -> void:
		_interactions.append({"node_id": nid, "type": itype}))


func after_each() -> void:
	GameStateManager.exploration = _exploration_before
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 可跳转层列表（只读——不修改任何状态）
# ═══════════════════════════════════════════════════════════════════════════════

func test_targets_exclude_unreached_layers() -> void:
	# 只到达过第 0/1 层 → 更深的层全未解锁，列表为空（GDD §8：传送节点不可激活）
	_setup_dag([0, TELEPORT_NODE])
	var targets: Array = es.call(&"teleport_targets", TELEPORT_NODE)
	assert_true(targets.is_empty(), "未到达过的层不得出现在可跳列表（实际 %s）" % str(targets))


func test_targets_include_unlocked_unvisited_layers() -> void:
	# 本局已探到第 4 层（走过 400）→ 第 2/3 层已解锁且各自有未访问节点
	_setup_dag([0, TELEPORT_NODE, DEEPEST_NODE])
	var targets: Array = es.call(&"teleport_targets", TELEPORT_NODE)
	assert_eq(targets.size(), 2, "第 2、3 层都应可跳（第 4 层两个节点都访问过了）")
	var first: Dictionary = targets[0]
	assert_eq(int(first["layer"]), TARGET_LAYER, "首个可跳层应是索引 2")
	assert_true((first["node_ids"] as Array).has(TARGET_A), "未访问的 200 应可跳")


func test_targets_are_sorted_by_layer() -> void:
	# 层序升序——列表渲染顺序稳定（不随字典键序抖动）
	_setup_dag([0, TELEPORT_NODE, DEEPEST_NODE])
	var targets: Array = es.call(&"teleport_targets", TELEPORT_NODE)
	var layers: Array = []
	for raw: Variant in targets:
		layers.append(int((raw as Dictionary)["layer"]))
	assert_eq(layers, [TARGET_LAYER, DEEP_LAYER], "可跳层应按升序排列")


func test_targets_exclude_visited_nodes() -> void:
	# 第 2 层的 200 已访问、201 未访问 → 只有 201 在列表里
	_setup_dag([0, TELEPORT_NODE, TARGET_A, DEEPEST_NODE])
	var targets: Array = es.call(&"teleport_targets", TELEPORT_NODE)
	var ids: Array = (targets[0] as Dictionary)["node_ids"]
	assert_eq(int((targets[0] as Dictionary)["layer"]), TARGET_LAYER, "首个可跳层仍是第 2 层")
	assert_false(ids.has(TARGET_A), "已访问的 200 不得作为落点")
	assert_true(ids.has(TARGET_B), "未访问的 201 应可跳")


func test_targets_exclude_current_layer() -> void:
	# 同层的另一个节点也不得可跳（GDD §4「不可在同一层内横向移动」）
	# 布局：传送 100 与 101 同在索引 1 层；索引 2 层有已访问的 202 与未访问的 200。
	es.set("_node_graph", {
		0: [TELEPORT_NODE],
		TELEPORT_NODE: [TARGET_A],
		101: [],
		TARGET_A: [],
		202: [],
	})
	es.set("_node_details", {
		0: {"type": 0, "layer": 0, "idx": 0},
		TELEPORT_NODE: {"type": 6, "layer": 1, "idx": 0},
		101: {"type": 1, "layer": 1, "idx": 1},
		TARGET_A: {"type": 7, "layer": TARGET_LAYER, "idx": 0},
		202: {"type": 1, "layer": TARGET_LAYER, "idx": 2},
	})
	es.set("_dag_ready", true)
	# 走到索引 2 层（202）→ 该层解锁；200 未访问 → 它是唯一合法候选
	GameStateManager.exploration.visited_nodes = [0, TELEPORT_NODE, 101, 202]
	var targets: Array = es.call(&"teleport_targets", TELEPORT_NODE)
	assert_eq(targets.size(), 1, "只有索引 2 层可跳（同层与已访问都被排除）")
	for raw: Variant in targets:
		assert_ne(int((raw as Dictionary)["layer"]), 1, "同层（索引 1）不得进入可跳列表")
		assert_false(((raw as Dictionary)["node_ids"] as Array).has(101),
				"同层的 101 不得作为落点")


func test_targets_empty_when_dag_cache_missing() -> void:
	# 缓存未就绪——不臆造目标（空列表由调用方解释为「不可激活」）
	es.set("_dag_ready", true)
	assert_true((es.call(&"teleport_targets", TELEPORT_NODE) as Array).is_empty(),
			"无节点详情缓存时应返回空列表")


# ═══════════════════════════════════════════════════════════════════════════════
# 跳转执行（写 GSM → 标记 → 发信号 → 分发节点交互）
# ═══════════════════════════════════════════════════════════════════════════════

func test_teleport_moves_player_and_marks_visited() -> void:
	_setup_dag([0, TELEPORT_NODE, DEEPEST_NODE])
	GameStateManager.exploration.action_points = 3
	GameStateManager.exploration.max_action_points = 7
	var result: Dictionary = es.call(&"teleport_to_node", TELEPORT_NODE, TARGET_A)
	assert_true(bool(result["success"]), "已解锁层的未访问节点应可跳（%s）" % str(result))
	assert_eq(int(GameStateManager.exploration.node_position["layer"]), TARGET_LAYER,
			"位置应写到目标层（索引 2）")
	assert_eq(int(GameStateManager.exploration.node_position["idx"]), 0,
			"位置应写到目标层内的 idx")
	assert_true((GameStateManager.exploration.visited_nodes as Array).has(TARGET_A),
			"落点应被标记为已访问")


func test_teleport_costs_no_action_points() -> void:
	_setup_dag([0, TELEPORT_NODE, DEEPEST_NODE])
	GameStateManager.exploration.action_points = 3
	GameStateManager.exploration.max_action_points = 7
	var result: Dictionary = es.call(&"teleport_to_node", TELEPORT_NODE, TARGET_A)
	assert_eq(int(result["ap_remaining"]), 3, "传送不扣行动力")
	assert_eq(int(GameStateManager.exploration.action_points), 3, "GSM 行动力原样保留")


func test_teleport_allowed_at_zero_action_points() -> void:
	_setup_dag([0, TELEPORT_NODE, DEEPEST_NODE])
	GameStateManager.exploration.action_points = 0
	GameStateManager.exploration.max_action_points = 7
	var result: Dictionary = es.call(&"teleport_to_node", TELEPORT_NODE, TARGET_A)
	assert_true(bool(result["success"]), "AP=0 不应挡住传送（AP 豁免类型）")
	assert_eq(int(GameStateManager.exploration.action_points), 0, "AP 仍为 0")


func test_teleport_emits_node_moved_and_resolves_target() -> void:
	_setup_dag([0, TELEPORT_NODE, DEEPEST_NODE])
	GameStateManager.exploration.action_points = 2
	GameStateManager.exploration.max_action_points = 7
	es.call(&"teleport_to_node", TELEPORT_NODE, TARGET_A)
	assert_eq(_moved.size(), 1, "应发一次 node_moved")
	assert_eq(int(_moved[0]["from"]), TELEPORT_NODE, "from 应为传送节点")
	assert_eq(int(_moved[0]["to"]), TARGET_A, "to 应为落点")
	assert_eq(_interactions.size(), 1, "落点节点交互应被分发（resolve_node）")
	assert_eq(int(_interactions[0]["node_id"]), TARGET_A, "分发的是落点节点")
	assert_eq(_interactions[0]["type"], &"action_spring",
			"应按落点自己的类型分发（200 是灵泉），而不是传送节点类型")


func test_teleport_to_locked_layer_is_rejected() -> void:
	# 第 2 层从未到达过 → 目标层未解锁（GDD §8 边界）
	_setup_dag([0, TELEPORT_NODE])
	var result: Dictionary = es.call(&"teleport_to_node", TELEPORT_NODE, TARGET_A)
	assert_false(bool(result["success"]), "未解锁层不得跳转")
	assert_true(str(result["reason"]).find("目标层未解锁") >= 0,
			"拒绝原因应可读（实际 %s）" % str(result["reason"]))
	assert_eq(_moved.size(), 0, "被拒时不得发 node_moved")
	assert_false((GameStateManager.exploration.visited_nodes as Array).has(TARGET_A),
			"被拒时不得标记已访问")


func test_teleport_to_visited_node_is_rejected() -> void:
	_setup_dag([0, TELEPORT_NODE, TARGET_A, DEEPEST_NODE])
	var result: Dictionary = es.call(&"teleport_to_node", TELEPORT_NODE, TARGET_A)
	assert_false(bool(result["success"]), "已访问节点不得作为落点")


func test_teleport_by_layer_picks_first_target() -> void:
	# UI 报层号，落点由 Feature 层定（层内首个可跳节点，ID 升序）
	_setup_dag([0, TELEPORT_NODE, DEEPEST_NODE])
	var result: Dictionary = es.call(&"teleport_to_layer", TELEPORT_NODE, TARGET_LAYER)
	assert_true(bool(result["success"]), "按层传送应成功（%s）" % str(result))
	assert_true((GameStateManager.exploration.visited_nodes as Array).has(TARGET_A),
			"应落到该层首个可跳节点 200（201 的 ID 更大）")


func test_teleport_by_layer_rejects_locked_layer() -> void:
	_setup_dag([0, TELEPORT_NODE])
	var result: Dictionary = es.call(&"teleport_to_layer", TELEPORT_NODE, TARGET_LAYER)
	assert_false(bool(result["success"]), "未解锁层不得按层传送")
	assert_true(str(result["reason"]).find("目标层未解锁") >= 0, "原因应可读")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 搭一张用例 DAG：入口 0 → 传送 100 → (200/201) → 300 → 400。[br]
## [br][b]类型选择[/b]：落点 200 取灵泉类型（[code]resolve_node[/code] 对它发
## [code]node_interaction_triggered[/code]，分发断言用它）；201 取普通战斗类型
## （走 [code]combat_node_reached[/code]，不干扰上面的探针）。[br]
## [br][param p_visited] 已访问节点——决定哪一层「已解锁」（= 到达过的最深层）。
func _setup_dag(p_visited: Array) -> void:
	es.set("_node_graph", {
		0: [TELEPORT_NODE],
		TELEPORT_NODE: [TARGET_A, TARGET_B],
		TARGET_A: [DEEP_NODE],
		TARGET_B: [DEEP_NODE],
		DEEP_NODE: [DEEPEST_NODE],
		DEEPEST_NODE: [],
	})
	es.set("_node_details", {
		0: {"type": 0, "layer": 0, "idx": 0},
		TELEPORT_NODE: {"type": 6, "layer": 1, "idx": 0},
		TARGET_A: {"type": 7, "layer": TARGET_LAYER, "idx": 0},
		TARGET_B: {"type": 1, "layer": TARGET_LAYER, "idx": 1},
		DEEP_NODE: {"type": 1, "layer": DEEP_LAYER, "idx": 0},
		DEEPEST_NODE: {"type": 3, "layer": 4, "idx": 0},
	})
	GameStateManager.exploration.visited_nodes = p_visited
	es.set("_dag_ready", true)
