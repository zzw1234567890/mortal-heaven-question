extends "res://tests/integration/exploration_ui/shop_rest_node_fixture.gd"
## 传送节点的端到端交互 —— 「到达之后」那一段的真实链路。[br]
## [br][b]本文件补的断链[/b]：传送节点被 B5 裁决排除在弹窗分发表之外
## （[code]DISPATCH_TABLE[/code] 里没有 [code]teleport[/code] 键），因此它既没有
## 确认框、也没有任何界面接手——到达之后什么都不发生。本文件走「探索系统
## [code]resolve_node[/code] → 交互组件转发 → [TeleportNodePresenter] → 传送
## 面板 → 系统执行跳转」的完整链路，断言「选了层真的会挪位置」。[br]
## [br][b]覆盖[/b]（本轮任务点名的断言）：[br]
##   1. 到达传送节点 → 可跳层列表随载荷下发 → 面板按层上架（且[b]不弹确认框[/b]
##      ——防双面板）；[br]
##   2. 选层 → 玩家位置真的写到目标层、落点被标记已访问、发 node_moved；[br]
##   3. 传送[b]不扣行动力[/b]（GDD §节点类型一览），AP=0 时同样可跳；[br]
##   4. 无可跳层（目标层均未解锁）→ 不上架面板，直接给一句可读提示；[br]
##   5. 面板在场期间节点图冻结，离开后还原；方向键 + 回车也能选层（双输入）。[br]
## [br][b]层号两套口径[/b]：节点 ID 编码 [code]layer * 100 + idx[/code]，故 200 号
## 节点在[b]索引 2 层[/b]；而面板行文案面向玩家，显示的是[b]第 3 层[/b]
## （索引 + 1）。断言两处都用各自的正确值。[br]
## [br][b]落点取无交互类型[/b]：用例 DAG 里 200/201 的类型给 0（入口型），
## [code]resolve_node[/code] 对它不发任何委托信号——这样「跳转确实分发了」的断言
## 不会被商店/灵泉弹窗干扰（分发本身的覆盖在
## [code]test_exploration_teleport.gd[/code]）。[br]
## [br]装置（场景搭建、存档快照还原）见 [code]shop_rest_node_fixture.gd[/code]。[br]
##
## 来源: GDD exploration-system.md §4 移动规则 / §节点类型一览 / §8 边界、
## design/gdd/exploration-ui-system.md §4c、ADR-0014 §决策 3、ADR-0031 §2、
## 本轮「传送节点最小可用交互」任务。

## 用例 DAG 的节点 ID——0 → 100 → (200/201) → 300 → 400。
const TELEPORT_NODE: int = 100
const TARGET_A: int = 200
const TARGET_B: int = 201
const DEEP_NODE: int = 300
const DEEPEST_NODE: int = 400
## 各节点所属的层索引（节点 ID 整除 100）。
const LAYER_TARGET: int = 2
const LAYER_DEEP: int = 3
const LAYER_DEEPEST: int = 4
## 玩家初始行动力（传送不该改动它）。
const START_AP: int = 5
const MAX_AP: int = 10

var _exploration_before: Dictionary = {}
## 到达载荷探针（载荷契约断言用——只记录，不改变链路行为）。
var _payload_log: Array = []


func before_each() -> void:
	super.before_each()
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	_payload_log.clear()
	if not es.node_interaction_triggered.is_connected(_on_interaction_probe):
		es.node_interaction_triggered.connect(_on_interaction_probe)


func after_each() -> void:
	_close_teleport_panel()
	GameStateManager.exploration = _exploration_before
	super.after_each()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 到达 → 可跳层列表随载荷下发 → 面板上架（不弹确认框）
# ═══════════════════════════════════════════════════════════════════════════════

func test_teleport_arrival_lists_jumpable_layers_without_popup() -> void:
	# Arrange——本局探到索引 4 层（400 走过），索引 2/3 层的节点都还没访问
	_prepare_exploration([0, TELEPORT_NODE, DEEPEST_NODE])
	# Act——到达传送节点（探索系统的真实分发，不是手工构造载荷）
	_reach_teleport()
	# Assert——面板上架：两层可跳，层号 1 基写进行文案
	var panel: Variant = _panel_of_teleport()
	assert_not_null(panel, "到达传送节点应上架选层面板")
	assert_eq(int(panel.call(&"row_count")), 2, "索引 2、3 两层都应可跳（各含未访问节点）")
	assert_eq(int(panel.call(&"layer_at", 0)), LAYER_TARGET, "首行对应索引 2 层")
	assert_true(str((panel.call(&"row_texts") as Array)[0]).contains("第 3 层"),
			"行文案应含 1 基层号（索引 2 → 第 3 层）")
	# Assert——传送不进弹窗分发表（B5 裁决）：不能同时弹确认框
	assert_eq(_popup_host().call(&"get_open_kind"), Rules.KIND_NONE,
			"传送节点不得再弹确认框（防双面板）")


func test_teleport_arrival_payload_carries_targets() -> void:
	# 载荷契约：可跳列表随 node_interaction_triggered 一次性下发（UI 不必再查一次）
	_prepare_exploration([0, TELEPORT_NODE, DEEPEST_NODE])
	_reach_teleport()
	var payload: Dictionary = _captured_payload()
	assert_true(payload.has("targets"), "传送载荷应带 targets 键")
	var targets: Array = payload.get("targets", [])
	assert_eq(targets.size(), 2, "两层可跳")
	assert_eq(int((targets[0] as Dictionary)["layer"]), LAYER_TARGET,
			"首个可跳层的索引为 2")
	assert_true(((targets[0] as Dictionary)["node_ids"] as Array).has(TARGET_A),
			"未访问的 200 应在落点列表里")


func test_teleport_with_no_jumpable_layer_shows_hint_and_no_panel() -> void:
	# Arrange——只到达过入口与传送节点本身：没有任何已解锁层可跳（GDD §8 边界）
	_prepare_exploration([0, TELEPORT_NODE])
	# Act
	_reach_teleport()
	# Assert——不上架空面板，直接给一句可读提示
	assert_null(_panel_of_teleport(), "无可跳层时不应上架面板")
	assert_true(str(_teleport_presenter().call(&"last_hint")).contains("暂无可跳转的层"),
			"应给出一句「暂无可跳转的层」提示")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 选层 → 真的挪位置 + 标记已访问 + 发 node_moved
# ═══════════════════════════════════════════════════════════════════════════════

func test_teleport_layer_choice_moves_player_to_target_layer() -> void:
	# Arrange
	_prepare_exploration([0, TELEPORT_NODE, DEEPEST_NODE])
	_reach_teleport()
	var moved: Array = []
	es.node_moved.connect(func(f: int, t: int, _ap: int) -> void:
		moved.append({"from": f, "to": t}))
	# Act——玩家点了首行（第 3 层）
	_panel_of_teleport().call(&"press_row", 0)
	# Assert——位置真的写到目标层（不是只关了个面板）
	assert_eq(int(GameStateManager.exploration.node_position["layer"]), LAYER_TARGET,
			"位置应写到索引 2 层")
	assert_eq(int(GameStateManager.exploration.node_position["idx"]), 0,
			"应写到该层首个落点的 idx")
	assert_true((GameStateManager.exploration.visited_nodes as Array).has(TARGET_A),
			"落点应被标记为已访问")
	assert_eq(moved.size(), 1, "应发一次 node_moved")
	assert_eq(int(moved[0]["from"]), TELEPORT_NODE, "node_moved 的起点应为传送节点")
	assert_eq(int(moved[0]["to"]), TARGET_A, "node_moved 的目标应为落点")
	assert_true(str(_teleport_presenter().call(&"last_hint")).contains("已抵达第 3 层"),
			"应给出一句「已抵达第 N 层」提示")


func test_teleport_costs_no_action_points_at_zero_ap() -> void:
	# Arrange——AP 归零（普通移动会被拒；传送属 AP 豁免类型）
	_prepare_exploration([0, TELEPORT_NODE, DEEPEST_NODE])
	GameStateManager.exploration.action_points = 0
	_reach_teleport()
	# Act
	_panel_of_teleport().call(&"press_row", 0)
	# Assert——照样跳成，AP 仍为 0（GDD §节点类型一览：传送不消耗行动力）
	assert_eq(int(GameStateManager.exploration.action_points), 0,
			"传送不得扣行动力，也不得回填")
	assert_true((GameStateManager.exploration.visited_nodes as Array).has(TARGET_A),
			"AP=0 时传送仍应生效")


func test_teleport_keeps_action_points_untouched() -> void:
	# 常规路径同理——AP 原样保留（既不掉也不回）
	_prepare_exploration([0, TELEPORT_NODE, DEEPEST_NODE])
	_reach_teleport()
	_panel_of_teleport().call(&"press_row", 0)
	assert_eq(int(GameStateManager.exploration.action_points), START_AP,
			"传送前后行动力应一致")


func test_teleport_panel_closes_after_choice() -> void:
	# 选完即关——否则面板会挡在落点节点的交互界面之前
	_prepare_exploration([0, TELEPORT_NODE, DEEPEST_NODE])
	_reach_teleport()
	_panel_of_teleport().call(&"press_row", 0)
	assert_false(bool(_teleport_presenter().call(&"is_panel_open")),
			"选层后传送面板应关闭")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 面板期间的节点图冻结
# ═══════════════════════════════════════════════════════════════════════════════

func test_teleport_panel_freezes_node_graph_and_restores_on_leave() -> void:
	# GDD §4c「overlay——节点图冻结」：面板在场期间节点图不吃输入
	_prepare_exploration([0, TELEPORT_NODE, DEEPEST_NODE])
	_reach_teleport()
	assert_true(bool(_teleport_presenter().call(&"is_node_graph_frozen")),
			"传送面板期间应冻结节点图")
	assert_false(_interactor().is_processing_unhandled_key_input(),
			"面板期间不应处理键盘走位")
	# Act——点「离开」
	_panel_of_teleport().call(&"press_leave")
	# Assert——全部还原（否则下一张地图点不动），且没发生任何跳转
	assert_false(bool(_teleport_presenter().call(&"is_node_graph_frozen")),
			"离开后应解冻节点图")
	assert_true(_interactor().is_processing_unhandled_key_input(),
			"离开后键盘走位应恢复")
	assert_false((GameStateManager.exploration.visited_nodes as Array).has(TARGET_A),
			"只是离开——不该发生任何跳转")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 面板的键盘 / 手柄导航（双输入——ui_code.md 强制）
# ═══════════════════════════════════════════════════════════════════════════════

func test_teleport_panel_confirm_key_chooses_focused_layer() -> void:
	# Arrange——两层可跳（索引 2 层与索引 3 层）
	_prepare_exploration([0, TELEPORT_NODE, DEEPEST_NODE])
	_reach_teleport()
	var panel: Variant = _panel_of_teleport()
	assert_eq(int(panel.call(&"row_count")), 2, "前置：两层可跳")
	assert_eq(int(panel.call(&"focused_index")), 0, "前置：游标落在首行")
	# Act——方向键下移一行后回车
	panel.call(&"_input", _key(KEY_DOWN))
	assert_eq(int(panel.call(&"focused_index")), 1, "下方向键应把游标移到第二行")
	panel.call(&"_input", _key(KEY_ENTER))
	# Assert——落到第二行那一层（索引 3 层）
	assert_eq(int(GameStateManager.exploration.node_position["layer"]), LAYER_DEEP,
			"回车应确认游标所在的那一层")
	assert_true(str(_teleport_presenter().call(&"last_hint")).contains("已抵达第 4 层"),
			"提示层号应为 1 基（索引 3 → 第 4 层）")


func test_teleport_panel_cancel_key_leaves_without_jumping() -> void:
	# Arrange
	_prepare_exploration([0, TELEPORT_NODE, DEEPEST_NODE])
	_reach_teleport()
	# Act——按 Esc（ui_cancel）
	_panel_of_teleport().call(&"_input", _key(KEY_ESCAPE))
	# Assert——面板关闭、没跳转、节点图解冻
	assert_false(bool(_teleport_presenter().call(&"is_panel_open")), "Esc 应关闭面板")
	assert_false((GameStateManager.exploration.visited_nodes as Array).has(TARGET_A),
			"取消不得发生跳转")
	assert_true(_interactor().is_processing_unhandled_key_input(), "取消后键盘走位应恢复")


## 造一条按键事件（[param p_code] 为主键盘键码）。
func _key(p_code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = p_code
	event.pressed = true
	event.echo = false
	return event


# ═══════════════════════════════════════════════════════════════════════════════
# 装置与查询
# ═══════════════════════════════════════════════════════════════════════════════

## 到达传送节点——走探索系统的真实分发（[code]resolve_node[/code]），
## 载荷由 Feature 层现算，不是本文件手工构造的。
func _reach_teleport() -> void:
	_payload_log.clear()
	es.call(&"resolve_node", TELEPORT_NODE)


## 最近一次 node_interaction_triggered 的载荷。
func _captured_payload() -> Dictionary:
	if _payload_log.is_empty():
		return {}
	return (_payload_log[_payload_log.size() - 1] as Dictionary)["payload"]


## 传送选层组件（屏幕公开入口）。
func _teleport_presenter() -> Variant:
	return screen.teleport_presenter()


## 当前传送面板（未打开为 null）。
func _panel_of_teleport() -> Variant:
	return _teleport_presenter().call(&"panel")


## 关掉传送面板（用例收尾——面板留着会把节点图冻结带进下一个用例）。
func _close_teleport_panel() -> void:
	var presenter: Variant = _teleport_presenter()
	if presenter != null:
		presenter.call(&"close_panel")


## 搭好探索域 + 用例 DAG（跳转会写位置与已访问，[code]after_each[/code] 已还原）。[br]
## [br][param p_visited] 已访问节点——「哪一层已解锁」由它推得。[br]
## [br]DAG 形状：0 → 100 → (200/201) → 300 → 400；落点 200/201 取入口型（不发
## 委托信号）。[param p_visited] 里走到哪一层，就解锁到哪一层。
func _prepare_exploration(p_visited: Array) -> void:
	GameStateManager.exploration.node_position = {"layer": 0, "idx": 0}
	GameStateManager.exploration.visited_nodes = p_visited
	GameStateManager.exploration.action_points = START_AP
	GameStateManager.exploration.max_action_points = MAX_AP
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
		TARGET_A: {"type": 0, "layer": LAYER_TARGET, "idx": 0},
		TARGET_B: {"type": 0, "layer": LAYER_TARGET, "idx": 1},
		DEEP_NODE: {"type": 0, "layer": LAYER_DEEP, "idx": 0},
		DEEPEST_NODE: {"type": 0, "layer": LAYER_DEEPEST, "idx": 0},
	})
	es.set("_dag_ready", true)


## 到达载荷探针——只记录（载荷契约断言用，不改变链路行为）。
func _on_interaction_probe(p_node_id: int, p_type: StringName,
		p_payload: Dictionary) -> void:
	_payload_log.append({"node_id": p_node_id, "type": p_type, "payload": p_payload})
