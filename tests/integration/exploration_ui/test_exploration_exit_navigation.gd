extends "res://tests/integration/exploration_ui/exploration_exit_fixture.gd"
## 探索退出闭环 · 回退地图选择 —— 退出之后界面回到哪、还能不能再进。[br]
## [br][b]覆盖[/b]（结算与结束原因见 [code]test_exploration_exit_flow.gd[/code]）：[br]
##   1. [b]回到地图选择[/b]——节点图卸载、地图选择界面在场（GDD exploration-system.md
##      §AC）；[br]
##   2. [b]还能再进[/b]——[code]_on_enter_map_requested[/code] 靠引用判「已挂载」，
##      引用不清会拒绝下一次进入（「退出后再也进不去」）；[br]
##   3. [b]界面读到的是结算后的数[/b]——余额与「已通关可重入」标记都随 GSM 现取，
##      否则停在进图那一刻；[br]
##   4. [b]行动力在下次进图时重置[/b]——退出本身不动 AP，重置发生在
##      [code]enter_map[/code]（GDD action-point-system.md §1）。[br]
## [br][b]装置[/b]见 [code]exploration_exit_fixture.gd[/code]（真实 Autoload + GSM 隔离）。
##
## 来源: design/gdd/exploration-system.md §8 边界 + §AC 退回地图选择、
## design/gdd/action-point-system.md §1 行动力重置、ADR-0014 §决策 5。

const StatusBarScript := preload("res://src/ui/exploration/node_graph_status_bar.gd")


func test_exit_unmounts_node_graph_and_shows_map_select() -> void:
	# Arrange
	_enter_map()
	var graph: Control = _graph()
	# Act
	_confirm_exit()
	# Assert——节点图卸下、地图选择在场
	assert_null(scene.get("node_graph_screen"), "退出后应解除节点图引用")
	assert_false(graph.is_inside_tree(), "退出后节点图应已从场景树移除")
	assert_not_null(scene.get("map_select_screen"), "退出后应回到地图选择界面")
	assert_true((scene.get("map_select_screen") as Control).is_inside_tree(),
			"地图选择界面应在场景树中")


func test_reentry_after_exit_mounts_a_fresh_node_graph() -> void:
	## 引用不清会让 [_on_enter_map_requested] 一直早退——「退出后再也进不去」。
	# Arrange——进出一次
	_enter_map()
	_confirm_exit()
	var select: Control = scene.get("map_select_screen")
	# Act——再进同一张图
	scene.call("_on_enter_map_requested", MAP_ID)
	# Assert
	assert_not_null(_graph(), "退出后应能再次进入地图")
	assert_eq(gsm.exploration.get("current_map"), MAP_ID, "再次进入应重新生成并写图 ID")
	assert_same(scene.get("map_select_screen"), select,
			"地图选择界面始终在场（节点图是叠在它上面的）")


func test_action_points_are_reset_on_the_next_entry() -> void:
	## 退出本身不动行动力（[code]clear_exploration_navigation[/code] 只管导航域），
	## 重置发生在下次进图——GDD action-point-system.md §1「每个地图开始时，行动力
	## 重置为上限值（不继承上一地图的剩余行动力）」。
	# Arrange——把行动力耗到 1 再退出
	_enter_map()
	gsm.call(&"set_exploration_ap", 1, int(gsm.exploration.get("max_action_points", 5)))
	_confirm_exit()
	# Act——重新进图
	scene.call("_on_enter_map_requested", MAP_ID)
	# Assert——回到上限，不带着上一局的 1 点进来
	var max_ap: int = int(gsm.exploration.get("max_action_points", 0))
	assert_eq(int(gsm.exploration.get("action_points", -1)), max_ap,
			"重新进图应把行动力重置为上限")
	assert_true(max_ap > 1, "前置：本用例需要上限大于 1（否则测不出重置）")


func test_map_select_after_exit_reflects_the_settled_balance() -> void:
	## 结算刚把灵石写进 GSM——界面必须重新读取，否则余额停在进图那一刻。
	# Arrange——先记下退出后应有的余额
	_enter_map()
	es.call("collect_resource", &"ling_shi", COLLECTED_LING_SHI)
	var expected: int = int(gsm.player.resources.get("ling_shi", 0)) + COLLECTED_LING_SHI
	# Act
	_confirm_exit()
	# Assert——余额标签 = 结算后的值
	var label: Label = scene.get("map_select_screen").get_node(
			NodePath("LayoutAnchor/BalanceLabel")) as Label
	assert_eq(label.text, "灵石: %d" % expected,
			"回到地图选择后应读到结算后的灵石余额")


func test_map_select_after_exit_drops_the_cleared_reentry_gate() -> void:
	## 另一条过期数据：卡片上的「已通关可重入」。本局通关会写
	## [code]is_first_clear[/code]，退出时列表若不重读，卡片会一直显示进图那一刻的
	## 状态（首通那局结束后仍画着「未通关」）。
	# Arrange——把本图标成已通关（模拟刚通关后的结算）
	_enter_map()
	gsm.call(&"update_exploration_map_state", MAP_ID, {"is_first_clear": true})
	# Act
	_confirm_exit()
	# Assert——条目随 GSM 现取
	var entries: Array = es.call("get_map_list")
	var entry: Dictionary = {}
	for candidate: Dictionary in entries:
		if candidate.get("map_id", &"") == MAP_ID:
			entry = candidate
	assert_false(entry.is_empty(), "探明表里应有本图条目")
	assert_true(bool(entry.get("is_cleared", false)),
			"回到地图选择后条目应按 GSM 现取（已通关标记可见）")


func test_exit_button_is_always_available() -> void:
	# Arrange——进图并把行动力压到 0（「走投无路」正是需要这个按钮的时候）
	_enter_map()
	gsm.call(&"set_exploration_ap", 0, int(gsm.exploration.get("max_action_points", 5)))
	_graph().call("_on_node_moved", 0, 0, 0)
	# Act
	var button: Button = _exit_button()
	# Assert——可见、可点、文案取自 GDD 点名词条
	assert_true(button.visible, "退出按钮应始终可见（AP 为 0 时更该在）")
	assert_false(button.disabled, "退出按钮不该灰显")
	assert_eq(button.text, StatusBarScript.TEXT_EXIT, "按钮文案应为「退出探索」")
