extends GutTest
## 采集点端到端 —— 到达采集节点 → 面板上架可采列表 → 点击采集 → 材料入背包 → 重复采集失败。[br]
## [br][b]为什么是集成测试[/b]：本用例穿过「交互组件转发 → Presenter → 面板 →
## 探索系统结算 → ResourceSystem → GSM → 地图状态」整条链，验证的是接线，
## 而不只是公式（公式侧见 [code]test_exploration_harvest.gd[/code]）。[br]
## [br][b]断言点[/b]：[br]
##   · 到达后[b]不需要确认框[/b]——采集面板直接上架（与传送同类的 overlay）；[br]
##   · 点击材料行后背包真的多出对应品质的数量；[br]
##   · 同槽位再采返回失败且背包不变（提示为中文「此处已采集过」）；[br]
##   · 离开面板后节点图解冻、背包与已采状态都不回退（取消不改变采集结果）。[br]
## [br][b]装置[/b]：真实 [code]node_graph_screen.tscn[/code] + 真实 Autoload
## （ResourceSystem / GSM）；用例前后快照还原 [code]player[/code] 与探索域。
##
## 来源: design/gdd/resource-system.md §资源表（灵材）/ §边界（AC-19）、
## design/gdd/exploration-ui-system.md §4c（overlay 先例）、ADR-0031 §2。

const NodeGraphScreenScene: PackedScene = preload(
		"res://src/ui/exploration/node_graph_screen.tscn")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const HarvestScript := preload("res://src/feature/exploration/exploration_harvest.gd")
const TableScript := preload("res://src/feature/exploration/exploration_harvest_table.gd")

## 采集点节点 ID 与用例地图（已采状态写进该地图的 map_states）。
const HARVEST_NODE: int = 204
const MAP_ID: StringName = &"qing_yun_jian_zong"

var es: Node = null
var screen: Control = null
var _player_before: Dictionary = {}
var _exploration_before: Dictionary = {}


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	GameStateManager.player.resources.ling_cai = {
		"low": 0, "medium": 0, "high": 0, "top": 0}
	GameStateManager.exploration.current_map = MAP_ID
	GameStateManager.exploration.map_states = {}

	es = ES_SCRIPT.new()
	es.set("_dag_ready", true)
	es.set("_node_details", {HARVEST_NODE: {
		"type": 10,  # NodeType.HARVEST
		"layer": 2,
		"idx": 4,
		"label": "采集点",
		"materials": TableScript.payload_for(MAP_ID, 1),
	}})
	screen = NodeGraphScreenScene.instantiate()
	screen.animate = false
	screen.reduce_motion_override = true
	screen.exploration_system = es
	add_child_autofree(screen)
	screen._on_map_generated(MAP_ID, {"nodes": {}, "graph": {}})


func after_each() -> void:
	if screen != null and is_instance_valid(screen):
		var presenter: Variant = screen.harvest_presenter()
		if presenter != null:
			presenter.call(&"close_panel")
	GameStateManager.player = _player_before
	GameStateManager.exploration = _exploration_before
	if es != null:
		es.free()
		es = null
	screen = null


# ═══════════════════════════════════════════════════════════════════════════════
# 到达 → 面板
# ═══════════════════════════════════════════════════════════════════════════════

func test_harvest_arrival_opens_panel_with_payload_entries() -> void:
	# Act——经交互组件的转发信号到达（生产路径的同一发射点）
	_reach()
	# Assert——无需确认框，面板直接上架；行数与节点载荷一致
	var panel: Variant = _panel()
	assert_not_null(panel, "采集节点到达后应上架采集面板")
	assert_eq(int(panel.call(&"entry_count")), 2, "面板应列出载荷里的两条材料")
	var texts: Array = panel.call(&"entry_texts")
	assert_true(str(texts[0]).contains("灵草"), "首行应含「灵草」（类别可见）")
	assert_true(str(texts[1]).contains("矿脉"), "次行应含「矿脉」")


func test_harvest_arrival_produces_no_confirm_popup() -> void:
	_reach()
	assert_eq(_popup_host().call(&"get_open_kind"), &"",
			"采集走独立通道——不得开确认弹窗（否则要玩家点两次）")


func test_harvest_panel_freezes_node_graph() -> void:
	_reach()
	assert_true(bool(_presenter().call(&"is_node_graph_frozen")),
			"采集面板期间节点图应冻结（GDD §4c overlay 口径）")


# ═══════════════════════════════════════════════════════════════════════════════
# 点击采集 → 入库
# ═══════════════════════════════════════════════════════════════════════════════

func test_harvest_click_writes_material_and_refreshes_panel() -> void:
	# Arrange
	_reach()
	var panel: Variant = _panel()
	var expected: int = int(_entries().call(&"entries_at", HARVEST_NODE)[0]["amount"])
	# Act——点击首行（真实信号路径，不直调私有方法）
	panel.call(&"press_entry", 0)
	# Assert——背包真的增加，行变成了已采集（禁用 + 文案）
	assert_eq(_ling_cai(1), expected, "点击后下品灵材应真的入库")
	assert_false(bool(panel.call(&"is_entry_enabled", 0)), "已采集的行应被禁用")
	assert_true(str((panel.call(&"entry_texts") as Array)[0]).contains("已采集"),
			"已采集行应有文字标记（不只靠颜色）")
	assert_true(str(panel.call(&"message_text")).begins_with("采集：获得"),
			"结果文案应为系统给的中文提示")


func test_harvest_repeat_click_is_rejected_and_bag_unchanged() -> void:
	# Arrange——采一次
	_reach()
	var panel: Variant = _panel()
	panel.call(&"press_entry", 0)
	var after_first: int = _ling_cai(1)
	# Act——再点同一行（禁用行不发意图，故直接调系统验证结算层也拒）
	var second: Dictionary = _entries().call(&"harvest_at_node", HARVEST_NODE,
			int(panel.call(&"slot_at", 0)))
	# Assert
	assert_false(bool(second["success"]), "重复采集应返回失败")
	assert_eq(str(second["message"]), HarvestScript.TEXT_ALREADY, "提示应为中文已采文案")
	assert_eq(_ling_cai(1), after_first, "重复采集不得再改背包")


func test_harvest_cancel_keeps_collected_result() -> void:
	# Arrange——采一次后离开面板（槽位先记下——离开后面板已释放）
	_reach()
	var panel: Variant = _panel()
	panel.call(&"press_entry", 0)
	var collected: int = _ling_cai(1)
	var slot: int = int(panel.call(&"slot_at", 0))
	# Act——点「离开」
	panel.call(&"press_leave")
	# Assert——面板关闭 + 解冻，但已采到的材料与已采状态都保留（取消不回退已发生的事）
	assert_null(_presenter().call(&"panel"), "离开后不应还有面板")
	assert_false(bool(_presenter().call(&"is_node_graph_frozen")), "离开后应解冻")
	assert_eq(_ling_cai(1), collected, "取消不得回退已入库的材料")
	assert_true(HarvestScript.is_harvested(
			GameStateManager.exploration.map_states[MAP_ID], HARVEST_NODE, slot),
			"已采状态应持久化在 map_states 里")


func test_harvest_second_slot_remains_enabled() -> void:
	_reach()
	var panel: Variant = _panel()
	panel.call(&"press_entry", 0)
	assert_true(bool(panel.call(&"is_entry_enabled", 1)),
			"另一条材料不受同节点已采影响")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 到达采集节点——经交互组件的转发信号（生产路径的同一发射点）。
func _reach() -> void:
	var interactor: Node = screen.get_node(NodePath("NodeMoveInteractor"))
	interactor.emit_signal(&"node_interaction_forwarded", HARVEST_NODE, &"harvest",
			{"entries": _entries().call(&"entries_at", HARVEST_NODE)})


func _entries() -> RefCounted:
	return HarvestScript.new(es)


func _presenter() -> Variant:
	return screen.harvest_presenter()


func _panel() -> Variant:
	var presenter: Variant = _presenter()
	return presenter.call(&"panel") if presenter != null else null


func _popup_host() -> Node:
	return screen.get_node(NodePath("NodeInteractionPopupHost"))


func _ling_cai(p_quality: int) -> int:
	return int(ResourceSystem.get_resource(&"ling_cai", p_quality))
