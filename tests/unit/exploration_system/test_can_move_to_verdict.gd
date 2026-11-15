extends GutTest
## [code]can_move_to[/code] 的三态可判别结果——[code]can_move_to_detail[/code]。[br]
## [br][b]本文件补的断链[/b]：布尔判定把三件不同的事压成同一个 [code]false[/code]
## ——「走不到」（拓扑）/「走过了」（进度）/「走不起」（资源）。界面要画的是三种
## 不同的东西（锁标记 / 绿色勾 / 红色斜线），拿布尔去还原只能靠重新推导一遍判定
## 规则，而两处各推导一遍必然漂移。本轮把判定拆成 [code]{ok, reason}[/code]，
## 旧布尔降为它的投影。[br]
## [br][b]覆盖[/b]：[br]
##   1. 三态各自给出[b]可区分[/b]的 reason（不可达 / 已访问 / 行动力不足）；[br]
##   2. 守卫态（DAG 未就绪）与成功态的形状，成功时 reason 为空串；[br]
##   3. 旧布尔接口与可判别结果[b]逐例一致[/b]（兼容层不是第二份实现）；[br]
##   4. 命令（[code]move_to_node[/code]）与查询说[b]同一套话[/b]——同一个玩家动作
##      不该因为走的是查询还是命令而看到两种理由；[br]
##   5. reason 命中 UI 的 toast 映射表，且与 [code]NodeStateLogic.REASON_*[/code]
##      副本逐字同源（跨层契约，同 [code]AP_EXEMPT_TYPES[/code] 的处置）。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域在 [code]before_each[/code] 快照、
## [code]after_each[/code] 原样还原；探索系统用 [code]ES_SCRIPT.new()[/code] 构造，
## 不进 Autoload（同 [code]test_action_point_consumption.gd[/code] 口径）。[br]
##
## 来源: design/gdd/action-point-system.md §公式 2 可移动判定 + §边界、
## design/gdd/exploration-system.md §4 节点导航、ADR-0014 §关键接口、
## 本轮任务书第 3 条（三态混叠）。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const NodeStateLogic := preload("res://src/ui/exploration/node_state_logic.gd")
## UI 侧 toast 映射表——reason 是它的查表键。
const MoveInteractor := preload("res://src/ui/exploration/node_move_interactor.gd")

## 节点 ID（编码 layer * 100 + idx）。
const ENTRY: int = 0
const COMBAT_NODE: int = 100
const TELEPORT_NODE: int = 110
const EVENT_NODE: int = 200

var es: Node = null
var _exploration_before: Dictionary = {}


func before_each() -> void:
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	GameStateManager.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [ENTRY],
		"action_points": 5,
		"max_action_points": 5,
		"map_states": {},
	}
	GameStateManager.get("_signal_router").set("_pending_changes", [])
	es = ES_SCRIPT.new()
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite):
		return [{"enemy_id": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r):
		return ["event_a"]))
	_setup_dag()


func after_each() -> void:
	if es != null:
		es.free()
		es = null
	GameStateManager.exploration = _exploration_before


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 固定 DAG：0 →（100 战斗 | 110 传送）→ 200 事件。[br]
## 100 非豁免（用于 AP 不足态），110 豁免（用于对照——AP=0 也走得通）；[br]
## [b]100 带一条回退边到 0[/b]（真实 DAG 没有，仅为构造「邻接但已访问」这一格
## ——否则已访问态会被拓扑判定先拦下，测不到进度原因）。同
## [code]test_move_resolve_node.gd[/code] 的 [code]_setup_linear_dag[/code] 口径。
func _setup_dag() -> void:
	es.set("_node_graph", {
		ENTRY: [COMBAT_NODE, TELEPORT_NODE],
		COMBAT_NODE: [EVENT_NODE, ENTRY],
		TELEPORT_NODE: [EVENT_NODE],
		EVENT_NODE: [],
	})
	es.set("_node_details", {
		ENTRY: {"type": 0, "layer": 0, "idx": 0},                  # ENTRY
		COMBAT_NODE: {"type": 1, "layer": 1, "idx": 0},            # COMBAT 非豁免
		TELEPORT_NODE: {"type": 6, "layer": 1, "idx": 1},          # TELEPORT 豁免
		EVENT_NODE: {"type": 4, "layer": 2, "idx": 0},             # EVENT
	})
	es.set("_map_config", {})
	es.set("_dag_ready", true)


func _set_ap(p_current: int, p_max: int) -> void:
	GameStateManager.exploration.action_points = p_current
	GameStateManager.exploration.max_action_points = p_max


func _detail(p_from: int, p_to: int) -> Dictionary:
	return es.call(&"can_move_to_detail", p_from, p_to)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 三态各自可判别（本文件的核心断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_reachable_target_is_ok_with_empty_reason() -> void:
	# Arrange——够走一格
	_set_ap(5, 5)
	# Act
	var verdict: Dictionary = _detail(ENTRY, COMBAT_NODE)
	# Assert
	assert_true(bool(verdict["ok"]), "够行动力时应判定可移动")
	assert_eq(str(verdict["reason"]), "", "成功时 reason 为空串（统一形状，调用方无分支）")


func test_unreachable_target_reports_topology_reason() -> void:
	# Arrange——0→200 无边（入口与事件节点不相邻）
	_set_ap(5, 5)
	# Act
	var verdict: Dictionary = _detail(ENTRY, EVENT_NODE)
	# Assert
	assert_false(bool(verdict["ok"]), "非邻接节点拒绝")
	assert_eq(str(verdict["reason"]), "不可达", "走不到 → 拓扑原因（不是「已访问」也不是「行动力不足」）")


func test_visited_target_reports_progress_reason() -> void:
	# Arrange——0 已访问，从 100 往回走
	_set_ap(5, 5)
	GameStateManager.exploration.visited_nodes = [ENTRY, COMBAT_NODE]
	# Act——从 100 回退到 0（0 已访问）
	var verdict: Dictionary = _detail(COMBAT_NODE, ENTRY)
	# Assert
	assert_false(bool(verdict["ok"]), "已访问节点拒绝")
	assert_eq(str(verdict["reason"]), "已访问", "走过了 → 进度原因（与「不可达」区分）")


func test_ap_insufficient_reports_resource_reason() -> void:
	# Arrange——行动力耗尽，目标为非豁免的战斗节点
	_set_ap(0, 5)
	# Act
	var verdict: Dictionary = _detail(ENTRY, COMBAT_NODE)
	# Assert
	assert_false(bool(verdict["ok"]), "行动力不足拒绝")
	assert_eq(str(verdict["reason"]), "行动力不足",
			"走不起 → 资源原因（三态里第三个可判别值）")


func test_three_refusal_reasons_are_pairwise_distinct() -> void:
	## 三态混叠的病根就是「都返回 false」——本用例直接钉住三者互不相同。
	_set_ap(0, 5)
	var unreachable: String = str(_detail(ENTRY, EVENT_NODE)["reason"])
	var insufficient: String = str(_detail(ENTRY, COMBAT_NODE)["reason"])
	GameStateManager.exploration.visited_nodes = [ENTRY, COMBAT_NODE]
	_set_ap(5, 5)
	var visited: String = str(_detail(COMBAT_NODE, ENTRY)["reason"])
	assert_ne(unreachable, insufficient, "不可达与行动力不足必须不同")
	assert_ne(unreachable, visited, "不可达与已访问必须不同")
	assert_ne(insufficient, visited, "行动力不足与已访问必须不同")


func test_exempt_target_is_ok_at_zero_ap() -> void:
	## 对照（防「AP=0 一律拒绝」的假通过）：豁免类型（传送）耗尽力也走得通。
	_set_ap(0, 5)
	var verdict: Dictionary = _detail(ENTRY, TELEPORT_NODE)
	assert_true(bool(verdict["ok"]), "传送节点 AP=0 仍可移动（豁免）")
	assert_eq(str(verdict["reason"]), "", "豁免通过时 reason 同样为空串")


func test_dag_not_ready_reports_guard_reason() -> void:
	# Arrange——清缓存（读档重建前的窗口）
	es.call(&"clear_dag_cache")
	# Act
	var verdict: Dictionary = _detail(ENTRY, COMBAT_NODE)
	# Assert
	assert_false(bool(verdict["ok"]), "DAG 未就绪时拒绝")
	assert_eq(str(verdict["reason"]), "DAG 缓存未就绪", "守卫态有专属 reason（不与「不可达」混）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 只读（查询与命令分离——ADR-0014 §关键接口）
# ═══════════════════════════════════════════════════════════════════════════════

func test_detail_is_read_only() -> void:
	_set_ap(5, 5)
	var ap_before: int = int(GameStateManager.exploration.action_points)
	var visited_before: Array = (GameStateManager.exploration.visited_nodes as Array).duplicate()
	var pos_before: Dictionary = (GameStateManager.exploration.node_position as Dictionary).duplicate(true)
	# Act——成功与拒绝两条路各问一次
	_detail(ENTRY, COMBAT_NODE)
	_set_ap(0, 5)
	_detail(ENTRY, COMBAT_NODE)
	# Assert
	assert_eq(int(GameStateManager.exploration.action_points), 0,
			"查询不扣行动力（0 是本步设的，不是查询写的）")
	assert_eq(GameStateManager.exploration.visited_nodes, visited_before,
			"查询不写 visited_nodes")
	assert_eq(GameStateManager.exploration.node_position, pos_before,
			"查询不写 node_position")
	_set_ap(ap_before, 5)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 旧布尔接口是投影，不是第二份实现
# ═══════════════════════════════════════════════════════════════════════════════

func test_boolean_wrapper_agrees_with_detail_on_every_case() -> void:
	## 兼容层若各写一套判定，就会出现「查询说不能走、移动却走得了」——
	## 逐例比对三条拒绝路径 + 一条通过路径。
	_set_ap(0, 5)
	assert_eq(es.call("can_move_to", ENTRY, COMBAT_NODE),
			bool(_detail(ENTRY, COMBAT_NODE)["ok"]), "行动力不足：布尔与详版一致")
	assert_eq(es.call("can_move_to", ENTRY, EVENT_NODE),
			bool(_detail(ENTRY, EVENT_NODE)["ok"]), "不可达：布尔与详版一致")
	assert_eq(es.call("can_move_to", ENTRY, TELEPORT_NODE),
			bool(_detail(ENTRY, TELEPORT_NODE)["ok"]), "豁免通过：布尔与详版一致")
	GameStateManager.exploration.visited_nodes = [ENTRY, COMBAT_NODE]
	_set_ap(5, 5)
	assert_eq(es.call("can_move_to", COMBAT_NODE, ENTRY),
			bool(_detail(COMBAT_NODE, ENTRY)["ok"]), "已访问：布尔与详版一致")
	es.call(&"clear_dag_cache")
	assert_eq(es.call("can_move_to", ENTRY, COMBAT_NODE),
			bool(_detail(ENTRY, COMBAT_NODE)["ok"]), "DAG 未就绪：布尔与详版一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 查询与命令说同一套话（跨接口契约）
# ═══════════════════════════════════════════════════════════════════════════════

func test_query_and_command_report_the_same_reason() -> void:
	## 同一个玩家动作，走查询还是走命令应得到同一条理由——否则 UI 的提示文案会
	## 取决于它是「预览」还是「真的点了」，玩家看到的说法前后不一致。
	for setup: Array in [
			[5, [ENTRY], ENTRY, EVENT_NODE],              # 不可达
			[0, [ENTRY], ENTRY, COMBAT_NODE],             # 行动力不足
			[5, [ENTRY, COMBAT_NODE], COMBAT_NODE, ENTRY],  # 已访问
	]:
		_set_ap(int(setup[0]), 5)
		GameStateManager.exploration.visited_nodes = setup[1]
		var from_node: int = int(setup[2])
		var to_node: int = int(setup[3])
		var query_reason: String = str(_detail(from_node, to_node)["reason"])
		var command_reason: String = str(es.call("move_to_node", from_node, to_node)["reason"])
		assert_eq(query_reason, command_reason,
				"查询与命令对 (%d→%d) 应给出同一条理由" % [from_node, to_node])


func test_not_ready_reason_matches_the_command_guard() -> void:
	es.call(&"clear_dag_cache")
	var query_reason: String = str(_detail(ENTRY, COMBAT_NODE)["reason"])
	var command_reason: String = str(es.call("move_to_node", ENTRY, COMBAT_NODE)["reason"])
	assert_eq(query_reason, command_reason, "未就绪守卫在查询与命令两侧同文案")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 跨层词表同源（UI 认得的键 = 系统说得出的理由）
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_refusal_reason_is_a_ui_toast_key() -> void:
	## 「不静默失败」的落地端在 UI 映射表——系统新造一个理由而 UI 不认识，玩家
	## 就会看到兜底的「无法移动」而不是真正的理由。
	var reasons: Array = [
		ES_SCRIPT.REASON_NOT_READY, ES_SCRIPT.REASON_UNREACHABLE,
		ES_SCRIPT.REASON_NO_GSM, ES_SCRIPT.REASON_VISITED, ES_SCRIPT.REASON_AP_SHORT,
	]
	for reason: String in reasons:
		assert_true(MoveInteractor.REASON_TEXTS.has(reason),
				"系统 reason「%s」必须命中 UI 的 REASON_TEXTS" % reason)


func test_reason_table_shared_across_layers() -> void:
	## 三份副本逐字同源：继承链（系统说得出的）/ UI 分类器（画得出的）/
	## UI 交互器（提示得出来的）——同 [code]AP_EXEMPT_TYPES[/code] 的处置。
	assert_eq(NodeStateLogic.REASON_NOT_READY, ES_SCRIPT.REASON_NOT_READY)
	assert_eq(NodeStateLogic.REASON_UNREACHABLE, ES_SCRIPT.REASON_UNREACHABLE)
	assert_eq(NodeStateLogic.REASON_NO_GSM, ES_SCRIPT.REASON_NO_GSM)
	assert_eq(NodeStateLogic.REASON_VISITED, ES_SCRIPT.REASON_VISITED)
	assert_eq(NodeStateLogic.REASON_AP_SHORT, ES_SCRIPT.REASON_AP_SHORT)
	assert_eq(ES_SCRIPT.REASON_AP_SHORT, "行动力不足", "文案本身即 GDD 的中文口径")
	assert_eq(NodeStateLogic.REASON_AP_SHORT, MoveInteractor.TEXT_AP_INSUFFICIENT,
			"词表与 toast 文案常量同名同值（「行动力不足」）")
