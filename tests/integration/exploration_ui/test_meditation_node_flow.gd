extends GutTest
## 打坐/洞府端到端 —— 到达洞府 → 突破面板上架 → 点「尝试突破」→ 扣修为升境界 → 离开。[br]
## [br][b]为什么是集成测试[/b]：本用例穿过「交互组件转发 → Presenter → 面板 →
## 探索系统结算 → RealmSystem.realm_up → GSM → CultivationSystem」整条链，验证的是
## 接线，而不只是公式（公式与五条验收见
## [code]tests/unit/exploration_system/test_exploration_breakthrough.gd[/code]）。[br]
## [br][b]断言点[/b]：[br]
##   · 到达后[b]不需要确认框[/b]——突破面板直接上架（与采集/炼制同类的 overlay）；
##     且面板上的成功率与所需修为都来自配置（不是 UI 自己算的）；[br]
##   · 点「尝试突破」后修为真的扣、境界真的升，且 [code]player.realm[/code] 变了
##     （落盘域）；[br]
##   · 修为不足时按钮禁用（键盘游标也跳不过去），且点不出任何状态变化；[br]
##   · 离开面板后节点图解冻，已发生的突破不回退。[br]
## [br][b]确定性[/b]：随机源经 [code]es.breakthrough_rng[/code] 注入固定种子——
## 子模块在首次取用时读取注入值，故必须在第一次 [code]attempt_breakthrough[/code]
## 之前注入。[br]
## [br][b]装置[/b]：真实 [code]node_graph_screen.tscn[/code] + 真实 Autoload
## （GSM / RealmSystem / CultivationSystem）；用例前后快照还原 [code]player[/code]。
##
## 来源: design/gdd/cultivation-system.md §4/§6/§边界、docs/decisions/ADR-0010、
## design/gdd/exploration-ui-system.md §4c（overlay 先例）、ADR-0031 §2。

const NodeGraphScreenScene: PackedScene = preload(
		"res://src/ui/exploration/node_graph_screen.tscn")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const TableScript := preload(
		"res://src/feature/exploration/exploration_breakthrough_table.gd")

## 洞府节点 ID（layer 2, idx 5——[code]NodeType.MEDITATION[/code] = 13）。
const MEDITATION_NODE: int = 205
const MEDITATION_TYPE: int = 13
## 用例地图 ID。
const MAP_ID: StringName = &"qing_yun_jian_zong"
## 炼气期——成功率最高档，种子扫描最容易命中。
const REALM_QI: int = 1
## 种子扫描上限（成功率最低档也有 10% 命中率，千次足够）。
const SEED_SCAN: int = 1000

var es: Node = null
var screen: Control = null
var _player_before: Dictionary = {}
var _required: int = 0


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_required = TableScript.required_cultivation(REALM_QI)
	_set_player(REALM_QI, _required)
	es = ES_SCRIPT.new()
	es.set("_dag_ready", true)
	es.set("_node_details", {MEDITATION_NODE: {
		"type": MEDITATION_TYPE, "layer": 2, "idx": 5, "label": "洞府",
	}})
	screen = NodeGraphScreenScene.instantiate()
	screen.animate = false
	screen.reduce_motion_override = true
	screen.exploration_system = es
	add_child_autofree(screen)
	screen._on_map_generated(MAP_ID, {"nodes": {}, "graph": {}})


func after_each() -> void:
	if screen != null and is_instance_valid(screen):
		var presenter: Variant = screen.meditation_presenter()
		if presenter != null:
			presenter.call(&"close_panel")
	GameStateManager.player = _player_before
	if es != null:
		es.free()
		es = null
	screen = null


# ═══════════════════════════════════════════════════════════════════════════════
# 到达 → 面板
# ═══════════════════════════════════════════════════════════════════════════════

func test_meditation_arrival_opens_panel_without_confirm_popup() -> void:
	# Act
	_reach()
	# Assert——面板直接上架，且没有确认弹窗（否则要玩家点两次）
	assert_not_null(_panel(), "洞府节点到达后应上架突破面板")
	assert_eq(_popup_host().call(&"get_open_kind"), &"",
			"打坐走独立通道——不得开确认弹窗")


func test_panel_shows_configured_cost_and_rate() -> void:
	# Act
	_reach()
	var panel: Variant = _panel()
	# Assert——三个数字都来自配置表，UI 不自己算
	assert_eq(str(panel.call(&"realm_text")), TableScript.realm_name(REALM_QI),
			"顶部应显示当前境界名")
	var action: String = str(panel.call(&"attempt_text"))
	assert_true(action.contains(str(_required)),
			"按钮文案应含配置里的所需修为 %d：%s" % [_required, action])
	assert_true(action.contains(
			"%d%%" % int(round(TableScript.success_rate_for(REALM_QI) * 100.0))),
			"按钮文案应含配置里的成功率：%s" % action)
	assert_true(int(panel.call(&"line_count")) > 0, "应有状态行（修为 / 所需 / 代价）")


func test_meditation_panel_freezes_node_graph() -> void:
	_reach()
	assert_true(bool(_presenter().call(&"is_node_graph_frozen")),
			"突破面板期间节点图应冻结（GDD §4c overlay 口径）")


# ═══════════════════════════════════════════════════════════════════════════════
# 点击突破 → 扣修为 / 升境界
# ═══════════════════════════════════════════════════════════════════════════════

func test_click_breakthrough_deducts_and_raises_realm() -> void:
	# Arrange——固定种子确保掷中
	_inject_success_seed()
	_reach()
	var panel: Variant = _panel()
	# Act——点击按钮（真实信号路径，不直调私有方法）
	panel.call(&"press_attempt")
	# Assert——修为扣掉、境界升高，且都写进了 GSM
	assert_eq(int(GameStateManager.player.cultivation), 0,
			"点击后应扣掉全部所需修为")
	assert_eq(int(GameStateManager.player.realm), REALM_QI + 1,
			"点击后境界应 +1（写进 GSM.player，随 serialize 落盘）")
	assert_true(str(panel.call(&"message_text")).begins_with("突破成功"),
			"面板应回填系统给的中文成功文案")
	assert_eq(str(_presenter().call(&"last_hint")),
			str(panel.call(&"message_text")), "同一条文案应发到 HUD 通知")


func test_panel_refreshes_to_next_realm_after_success() -> void:
	# Arrange
	_inject_success_seed()
	_reach()
	var panel: Variant = _panel()
	# Act
	panel.call(&"press_attempt")
	# Assert——面板刷新到新境界（可继续连冲，不是一次性的）
	assert_eq(str(panel.call(&"realm_text")), TableScript.realm_name(REALM_QI + 1),
			"成功后顶部应显示新境界名")
	assert_true(str(panel.call(&"attempt_text")).contains(
			str(TableScript.required_cultivation(REALM_QI + 1))),
			"按钮文案应换成新境界的所需修为：%s" % panel.call(&"attempt_text"))


func test_insufficient_cultivation_disables_button_and_changes_nothing() -> void:
	# Arrange——差一点修为
	_set_player(REALM_QI, _required - 1)
	_reach()
	var panel: Variant = _panel()
	# Assert——按钮禁用 + 游标无可选行（键盘也点不动）
	assert_false(bool(panel.call(&"is_attempt_enabled")),
			"修为不足时「尝试突破」应禁用")
	assert_eq(int(panel.call(&"focused_index")), -1,
			"无可选行时键盘游标不得停在任何行上")
	assert_true(str(panel.call(&"message_text")).contains("修为不足"),
			"面板应说明原因：%s" % panel.call(&"message_text"))
	# Act——按钮禁用时点击不发意图（与真实按钮行为一致）
	panel.call(&"press_attempt")
	# Assert——状态一点没动
	assert_eq(int(GameStateManager.player.cultivation), _required - 1,
			"被拒时修为不得变化")
	assert_eq(int(GameStateManager.player.realm), REALM_QI, "被拒时境界不得变化")


func test_failure_through_panel_deducts_penalty_and_keeps_realm() -> void:
	# Arrange——固定种子确保掷空
	_inject_failure_seed()
	_reach()
	var panel: Variant = _panel()
	var expected_penalty: int = TableScript.penalty_for(REALM_QI, _required)
	# Act
	panel.call(&"press_attempt")
	# Assert——扣惩罚、境界不变；失败不发 HUD 提示（只有成功才播报）
	assert_eq(int(GameStateManager.player.cultivation), _required - expected_penalty,
			"失败后应按配置扣掉惩罚量")
	assert_eq(int(GameStateManager.player.realm), REALM_QI, "失败不得升境界")
	assert_true(str(panel.call(&"message_text")).begins_with("突破失败"),
			"面板应回填失败文案：%s" % panel.call(&"message_text"))
	assert_eq(str(_presenter().call(&"last_hint")), "",
			"失败不发 HUD 提示（面板上的文案才是主动作）")


# ═══════════════════════════════════════════════════════════════════════════════
# 离开
# ═══════════════════════════════════════════════════════════════════════════════

func test_leave_closes_panel_unfreezes_and_keeps_breakthrough() -> void:
	# Arrange——先突破成功
	_inject_success_seed()
	_reach()
	_panel().call(&"press_attempt")
	var cultivation: int = int(GameStateManager.player.cultivation)
	# Act——点「离开」
	_panel().call(&"press_leave")
	# Assert——面板关闭 + 解冻，但已发生的突破不回退（取消不回退已发生的事）
	assert_null(_presenter().call(&"panel"), "离开后不应还有面板")
	assert_false(bool(_presenter().call(&"is_node_graph_frozen")), "离开后应解冻")
	assert_eq(int(GameStateManager.player.realm), REALM_QI + 1, "境界保留")
	assert_eq(int(GameStateManager.player.cultivation), cultivation, "修为保留")


func test_leave_without_attempt_leaves_state_untouched() -> void:
	# Arrange——到达后什么都不做
	_reach()
	# Act
	_panel().call(&"press_leave")
	# Assert
	assert_eq(int(GameStateManager.player.cultivation), _required, "未尝试不得扣修为")
	assert_eq(int(GameStateManager.player.realm), REALM_QI, "未尝试不得升境界")
	assert_eq(str(_presenter().call(&"last_hint")), "", "未尝试不发提示")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 到达洞府——经交互组件的转发信号（生产路径的同一发射点）。
## [br][b]载荷口径[/b]：与 [code]resolve_node[/code] 的 MEDITATION 分支一致——
## 状态由 [code]breakthrough_status[/code] 现算。
func _reach() -> void:
	var interactor: Node = screen.get_node(NodePath("NodeMoveInteractor"))
	interactor.emit_signal(&"node_interaction_forwarded", MEDITATION_NODE,
			&"meditation", {"status": es.call(&"breakthrough_status")})


## 摆好玩家状态（修为上限按境界表读——不硬编码）。
func _set_player(p_realm: int, p_cultivation: int) -> void:
	GameStateManager.player.realm = p_realm
	GameStateManager.player.cultivation = p_cultivation
	GameStateManager.player.max_cultivation = TableScript.required_cultivation(p_realm)
	GameStateManager.player.cultivation_full = false


## 注入固定种子的随机源——须在首次 [code]attempt_breakthrough[/code] 之前调用
## （子模块首次取用时读取 [code]es.breakthrough_rng[/code]）。
func _inject_seed(p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	es.set(&"breakthrough_rng", rng)


func _inject_success_seed() -> void:
	_inject_seed(_find_seed(true))


func _inject_failure_seed() -> void:
	_inject_seed(_find_seed(false))


## 找一颗掷出指定结果的种子——从 0 起顺序扫描，结果确定
## （不写死字面量：改配置档位不会让用例失效）。
func _find_seed(p_want_success: bool) -> int:
	var rate: float = TableScript.success_rate_for(REALM_QI)
	for candidate: int in SEED_SCAN:
		var probe := RandomNumberGenerator.new()
		probe.seed = candidate
		if TableScript.roll_success(probe, rate) == p_want_success:
			return candidate
	fail_test("在 %d 个种子里找不到「%s」的结果（成功率 %.2f）"
			% [SEED_SCAN, "成功" if p_want_success else "失败", rate])
	return -1


func _presenter() -> Variant:
	return screen.meditation_presenter()


func _panel() -> Variant:
	var presenter: Variant = _presenter()
	return presenter.call(&"panel") if presenter != null else null


func _popup_host() -> Node:
	return screen.get_node(NodePath("NodeInteractionPopupHost"))
