extends GutTest
## 探索行动力（AP）消耗闭环——单元/集成测试。[br]
## [br][b]★ 本轮语义变更（有意改动，报告单列）★[/b]：移动开销从「按格定价」
## （[code]ap_cost[/code] / [code]ap_costs[/code]）改成「按两节点在布局坐标里的距离
## 定价」（老板 2026-11-27 18:40：「每个节点之间都可达，只是消耗的行动力不一样」）。[br]
## [br]旧断言里有四条是在钉「配置键怎么读」——那两个键本轮起[b]不再参与扣费[/b]
## （保留只为旧存档/旧地图表不报错）。断言留着会变成「测一个已经被忽略的键」：绿着，
## 但什么都没守住。四条改法如下（[b]都是改语义，不是放宽[/b]）：[br]
##   · 「按图配置扣」→ 改为「调小单位距离 = 整图涨价」（同一个用途的新旋钮）；[br]
##   · 「按类型覆盖表扣」→ 改为「遗留键不再改变扣费」（保留键的兼容性断言）；[br]
##   · 「免费地图不扣」→ 改为「没有免费地图：开销下限是 1」（[code]ap_cost: 0[/code]
##     不再能让一张图白走——那正是距离定价要堵的洞）；[br]
##   · 「判定的开销阈值」由配置的 2 改为配置单位算出来的 2（数值不变，来源换了）。[br]
## [br][b]覆盖[/b]（本轮任务点名三组）：[br]
##   1. [b]正常扣减[/b]——按距离算出的开销扣、写入 GSM、[code]node_moved[/code]
##      载荷的 [code]ap_remaining[/code] 与 GSM 实际值一致；[br]
##   2. [b]不足拒绝且不扣[/b]——[code]move_to_node[/code] 返回 reason「行动力不足」
##      （中文文案，UI 据此弹提示，不静默失败），且[b]零状态写入[/b]：
##      AP 不变、[code]node_position[/code] 不变、[code]visited_nodes[/code] 不变、
##      不发 [code]node_moved[/code]；[code]can_move_to[/code] 同口径返回 false；[br]
##   3. [b]回复夹上限[/b]——灵泉结算后 AP 恰好等于上限、绝不越界。[br]
## [br][b]另外锁定[/b]：豁免类型（Boss/传送/灵泉）AP=0 仍可移入且不扣；越界存档值
## （负数）不会让 AP 落负、也不会把豁免节点锁死。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域在 [code]before_each[/code] 快照、
## [code]after_each[/code] 原样还原（同 [code]test_exploration_action_spring.gd[/code]
## 先例）；探索系统用 [code]ES_SCRIPT.new()[/code] 构造，不进 Autoload。[br]
##
## 来源: design/gdd/action-point-system.md §公式 2/3 + §边界 + §调优参数、
## design/gdd/exploration-system.md §4 节点导航 / §节点类型一览、ADR-0014 §关键接口、
## 本轮任务书追加规则（全连通 + 距离定价）。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
## UI 侧文案映射表——锁定「系统 reason → 中文 toast」这一跨层契约。
const MoveInteractor := preload("res://src/ui/exploration/node_move_interactor.gd")
## 布局几何——夹具里那个「让这一跳恰好值 2 点」的单位距离由它算，不写死数。
const GEOMETRY := preload("res://src/feature/exploration/exploration_node_geometry.gd")

## 节点 ID（编码 layer * 100 + idx）。
const ENTRY: int = 0
const COMBAT_NODE: int = 100
const TELEPORT_NODE: int = 110
const EVENT_NODE: int = 200
const BOSS_NODE: int = 300

var es: Node = null
var gsm: Node = null
var _exploration_before: Dictionary = {}
var _node_moved: Array = []


func before_each() -> void:
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm != null:
		gsm.exploration = {
			"current_map": &"",
			"node_position": {"layer": 0, "idx": 0},
			"visited_nodes": [ENTRY],
			"action_points": 5,
			"max_action_points": 5,
			"map_states": {},
		}
		gsm.get("_signal_router").set("_pending_changes", [])

	es = ES_SCRIPT.new()
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite):
		return [{"enemy_id": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r):
		return ["event_a"]))
	_node_moved.clear()
	es.node_moved.connect(_on_node_moved)
	_setup_dag()


func after_each() -> void:
	if es != null:
		if es.node_moved.is_connected(_on_node_moved):
			es.node_moved.disconnect(_on_node_moved)
		es.free()
		es = null
	GameStateManager.exploration = _exploration_before


func _on_node_moved(from_node: int, to_node: int, ap_remaining: int) -> void:
	_node_moved.append({"from": from_node, "to": to_node, "ap": ap_remaining})


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 固定 DAG：0 →（100 战斗 | 110 传送）→ 200 事件 → 300 Boss。[br]
## [br][param p_map_config] 本图配置快照——[code]ap_distance_unit[/code] /
## [code]ap_move_max[/code] 由 [ExplorationDAGBuilder] 在生成期写入
## [code]_map_config[/code]，此处直填（[code]ap_cost[/code] / [code]ap_costs[/code]
## 是本轮的遗留键，填了也不影响扣费）。
func _setup_dag(p_map_config: Dictionary = {}) -> void:
	es.set("_node_graph", {
		ENTRY: [COMBAT_NODE, TELEPORT_NODE],
		COMBAT_NODE: [EVENT_NODE],
		TELEPORT_NODE: [EVENT_NODE],
		EVENT_NODE: [BOSS_NODE],
		BOSS_NODE: [],
	})
	es.set("_node_details", {
		ENTRY: {"type": 0, "layer": 0, "idx": 0},                       # ENTRY
		COMBAT_NODE: {"type": 1, "layer": 1, "idx": 0, "enemy_roster": [{"enemy_id": 1}]},
		TELEPORT_NODE: {"type": 6, "layer": 1, "idx": 1},               # TELEPORT 豁免
		EVENT_NODE: {"type": 4, "layer": 2, "idx": 0, "event_pool": ["event_a"]},
		BOSS_NODE: {"type": 3, "layer": 3, "idx": 0, "enemy_roster": []},  # BOSS 豁免
	})
	es.set("_map_config", p_map_config)
	es.set("_dag_ready", true)


## 「从入口走到 [param p_node_id] 恰好值 [param p_cost] 点」所需的单位距离。[br]
## [br][b]为什么现算而不是写一个数[/b]：布局标定（层间距 / 同层间距 / 错开量）可调，
## 写死的单位距离会在标定变化后让这一跳的价钱变成 1 或 3，用例随之失真。[br]
## [br][b]为什么取 [code]distance / cost[/code] 而不是别的[/b]：公式是
## [code]clamp(round(distance / unit), 1, MAX)[/code]，令比值恰为整数 [param p_cost]
## 就落在取整的不动点上——不会因为 0.5 的舍入规则变化而漂移。
func _unit_for_cost(p_node_id: int, p_cost: int) -> float:
	var counts: Dictionary = GEOMETRY.layer_counts(es.get("_node_details"))
	var distance: float = GEOMETRY.distance_between(
			es.get("_node_details")[ENTRY], es.get("_node_details")[p_node_id], counts)
	return distance / float(p_cost)


func _set_ap(p_current: int, p_max: int) -> void:
	gsm.exploration.action_points = p_current
	gsm.exploration.max_action_points = p_max


func _ap() -> int:
	return int(gsm.exploration.action_points)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 正常扣减
# ═══════════════════════════════════════════════════════════════════════════════

func test_move_deducts_default_cost_and_writes_gsm() -> void:
	# Arrange——无配置键 → 出厂单位距离 120px；入口到第 1 层（104px）→ 1 点
	_set_ap(5, 5)
	# Act
	var result: Dictionary = es.call("move_to_node", ENTRY, COMBAT_NODE)
	# Assert
	assert_true(result["success"], "移动成功")
	assert_eq(result["ap_remaining"], 4, "返回值 AP 从 5 减为 4（相邻一层的距离恰是 1 点档）")
	assert_eq(_ap(), 4, "GSM 实际值同步为 4")
	assert_eq(_node_moved.size(), 1, "node_moved 发射一次")
	assert_eq(_node_moved[0]["ap"], 4, "信号载荷的 ap_remaining 与 GSM 同口径")


func test_move_deducts_more_when_the_unit_distance_is_smaller() -> void:
	## 「按地图配置扣」的新旋钮：单位距离减半 = 同一条路更贵。[br]
	## [b]改前红[/b]：旧版填的是 [code]{"ap_cost": 2}[/code]——那个键本轮起被忽略。
	# Arrange——让这一跳恰好值 2 点
	var unit: float = _unit_for_cost(COMBAT_NODE, 2)
	assert_gt(unit, 0.0, "前置：单位距离应为正")
	_setup_dag({"ap_distance_unit": unit})
	_set_ap(5, 5)
	# Act
	var result: Dictionary = es.call("move_to_node", ENTRY, COMBAT_NODE)
	# Assert
	assert_eq(result["ap_remaining"], 3, "5 - 2 = 3")
	assert_eq(_ap(), 3, "GSM 按配置的距离单位扣减")


func test_legacy_ap_costs_key_no_longer_changes_the_deduction() -> void:
	## ★ 有意改动：按类型的覆盖表 [code]ap_costs[/code] 不再参与扣费 ★[br]
	## [b]改前红[/b]：旧版断言「覆盖表命中 → 扣 3（不是 1）」。那个键保留只为旧存档
	## 与旧地图表不报错——「读它不改变任何行为」这件事必须有断言守着，否则将来有人
	## 顺手把它接回扣费，就会出现「同一张图两套定价」而没有任何测试会红。
	# Arrange——覆盖表写着战斗节点扣 3
	_setup_dag({"ap_distance_unit": _unit_for_cost(COMBAT_NODE, 1),
			"ap_cost": 1, "ap_costs": {1: 3}})
	_set_ap(5, 5)
	# Act
	var result: Dictionary = es.call("move_to_node", ENTRY, COMBAT_NODE)
	# Assert——扣的是距离定价的 1，不是覆盖表的 3
	assert_eq(result["ap_remaining"], 4, "覆盖表被忽略 → 扣距离定价的 1（不是 3）")
	assert_eq(_ap(), 4, "GSM 同上")


func test_there_is_no_free_map_the_floor_is_one() -> void:
	## ★ 有意改动：没有「免费地图」了 ★[br]
	## [b]改前红[/b]：旧版填 [code]{"ap_cost": 0}[/code] 断言「开销 0 → AP 不变」。
	## 距离定价的下限是 1——0 消耗意味着白走，玩家会找 0 消耗的落点反复横跳刷访问状态。
	## 那张「免费地图」现在由 [code]ap_distance_unit[/code] 调到很大来近似（仍然至少 1 点）。
	# Arrange——单位距离大到比值趋近 0
	_setup_dag({"ap_cost": 0, "ap_distance_unit": 100000.0})
	_set_ap(3, 5)
	# Act
	var result: Dictionary = es.call("move_to_node", ENTRY, COMBAT_NODE)
	# Assert——仍扣 1 点下限
	assert_eq(result["success"], true, "仍可移动")
	assert_eq(result["ap_remaining"], 2, "开销下限为 1（ap_cost: 0 不再能白走）")
	assert_eq(_ap(), 2, "GSM 同步")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 不足拒绝且不扣（点名断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_insufficient_ap_rejected_with_chinese_reason() -> void:
	_set_ap(0, 5)
	var result: Dictionary = es.call("move_to_node", ENTRY, COMBAT_NODE)
	assert_eq(result["success"], false, "AP 不足拒绝")
	assert_eq(result["reason"], "行动力不足", "reason 为中文文案「行动力不足」")


func test_insufficient_ap_writes_no_state() -> void:
	# Arrange
	_set_ap(0, 5)
	var visited_before: Array = (gsm.exploration.visited_nodes as Array).duplicate()
	var pos_before: Dictionary = (gsm.exploration.node_position as Dictionary).duplicate(true)
	# Act
	es.call("move_to_node", ENTRY, COMBAT_NODE)
	# Assert——零写入
	assert_eq(_ap(), 0, "AP 未被扣减")
	assert_eq(gsm.exploration.visited_nodes, visited_before, "visited_nodes 未变")
	assert_eq(gsm.exploration.node_position, pos_before, "node_position 未变")
	assert_eq(_node_moved.size(), 0, "不发 node_moved 信号")


func test_insufficient_ap_returns_ap_remaining_zero_not_negative() -> void:
	_set_ap(0, 5)
	var result: Dictionary = es.call("move_to_node", ENTRY, COMBAT_NODE)
	assert_eq(result["ap_remaining"], 0, "拒绝路径的 ap_remaining 为 0，不落负")


func test_can_move_to_shares_deduction_rule() -> void:
	# Arrange——让这一跳恰好值 2 点（判定与扣费读的是同一份距离定价）
	_setup_dag({"ap_distance_unit": _unit_for_cost(COMBAT_NODE, 2)})
	_set_ap(2, 5)
	# Assert——判定说能走
	assert_eq(es.call("can_move_to", ENTRY, COMBAT_NODE), true, "2 点够走 2 点开销")
	# Act——同一目标真的扣得起
	var result: Dictionary = es.call("move_to_node", ENTRY, COMBAT_NODE)
	assert_eq(result["success"], true, "判定与扣费同口径（能走就扣得起）")
	assert_eq(_ap(), 0, "扣完恰好为 0")


func test_can_move_to_false_when_short_by_one() -> void:
	_setup_dag({"ap_distance_unit": _unit_for_cost(COMBAT_NODE, 2)})
	_set_ap(1, 5)
	assert_eq(es.call("can_move_to", ENTRY, COMBAT_NODE), false,
			"差 1 点 → 判定 false（不是「有 AP 就 true」）")


func test_insufficient_reason_maps_to_chinese_toast() -> void:
	## 系统 reason 是 UI toast 文案的键——「不静默失败」的落地端在 UI 映射表。
	## 此处锁定键存在且文案为中文（UI 侧另有端到端用例断言真弹提示）。
	assert_eq(MoveInteractor.REASON_TEXTS.get("行动力不足", null), "行动力不足",
			"「行动力不足」必须映射到中文提示（不得落回兜底文案或静默）")
	assert_eq(MoveInteractor.TEXT_AP_INSUFFICIENT, "行动力不足", "文案常量本身即中文")


func test_system_reason_string_is_the_ui_mapping_key() -> void:
	## 跨层契约：系统返回的 reason 必须与 UI 映射表的键逐字一致——
	## 系统改文案而 UI 没跟着改，玩家会看到一个词不达意的兜底提示。
	_set_ap(0, 5)
	var reason: String = str(es.call("move_to_node", ENTRY, COMBAT_NODE)["reason"])
	assert_true(MoveInteractor.REASON_TEXTS.has(reason),
			"系统 reason「%s」必须命中 UI 的 REASON_TEXTS" % reason)


func test_refusal_does_not_block_later_move_after_restore() -> void:
	## 拒绝不留下副作用——补足 AP 后同一目标可正常移动（防止拒绝路径写坏状态）
	_set_ap(0, 5)
	assert_eq(es.call("move_to_node", ENTRY, COMBAT_NODE)["success"], false, "先被拒绝")
	_set_ap(1, 5)
	var result: Dictionary = es.call("move_to_node", ENTRY, COMBAT_NODE)
	assert_eq(result["success"], true, "补足后同一目标可移动")
	assert_eq(_ap(), 0, "正常扣减 1")


# ═══════════════════════════════════════════════════════════════════════════════
# 豁免节点（AP=0 仍可移入 + 不扣费）
# ═══════════════════════════════════════════════════════════════════════════════

func test_exempt_teleport_movable_at_zero_ap() -> void:
	_set_ap(0, 5)
	var result: Dictionary = es.call("move_to_node", ENTRY, TELEPORT_NODE)
	assert_eq(result["success"], true, "传送节点 AP=0 可移入")
	assert_eq(_ap(), 0, "豁免不扣费")


func test_exempt_boss_ignores_configured_override() -> void:
	## 配置给 Boss 写了 3 点开销也不生效——豁免是系统级不变量
	var deep_dag: Dictionary = {"ap_cost": 1, "ap_costs": {3: 3}}
	_setup_dag(deep_dag)
	gsm.exploration.visited_nodes = [ENTRY, COMBAT_NODE, EVENT_NODE]
	_set_ap(2, 5)
	var result: Dictionary = es.call("move_to_node", EVENT_NODE, BOSS_NODE)
	assert_eq(result["success"], true, "Boss 可移入")
	assert_eq(_ap(), 2, "Boss 开销恒为 0（配置覆盖被压制）")


# ═══════════════════════════════════════════════════════════════════════════════
# 越界存档值（负数）——AP 永不落负，豁免节点不被锁死
# ═══════════════════════════════════════════════════════════════════════════════

func test_negative_saved_ap_does_not_go_more_negative() -> void:
	_set_ap(-3, 5)
	var result: Dictionary = es.call("move_to_node", ENTRY, TELEPORT_NODE)
	assert_eq(result["success"], true, "豁免节点在负数存档下仍可移入")
	assert_eq(_ap(), 0, "负数先夹到 0（不写成 -3 - 0 = -3）")


func test_negative_saved_ap_refuses_non_exempt() -> void:
	_set_ap(-3, 5)
	var result: Dictionary = es.call("move_to_node", ENTRY, COMBAT_NODE)
	assert_eq(result["success"], false, "负数存档视为 0 → 非豁免拒绝")
	assert_eq(result["reason"], "行动力不足", "同为「行动力不足」文案")
	assert_eq(_ap(), -3, "拒绝路径不写状态（原值保留，交由上层修正）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 回复夹上限（灵泉）
# ═══════════════════════════════════════════════════════════════════════════════

func test_spring_restores_to_cap_exactly() -> void:
	_set_ap(1, 5)
	var restored: int = int(es.call("use_action_spring", 210))
	assert_eq(restored, 4, "1/5 → 回复 4 点")
	assert_eq(_ap(), 5, "结算后恰好等于上限，不越过")
	assert_eq(int(gsm.exploration.max_action_points), 5, "上限不被写坏")


func test_spring_never_exceeds_cap_from_partial() -> void:
	_setup_dag({"ap_cost": 2})
	_set_ap(4, 5)
	assert_eq(int(es.call("use_action_spring", 210)), 1, "4/5 → 回复 1 点")
	assert_eq(_ap(), 5, "结果夹在上限")


func test_spring_at_full_cap_writes_nothing() -> void:
	_set_ap(5, 5)
	assert_eq(int(es.call("use_action_spring", 210)), 0, "满行动力 → 回复 0")
	assert_eq(_ap(), 5, "本就不超上限，原值不动")
