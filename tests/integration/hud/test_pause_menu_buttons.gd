extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 暂停菜单场景接线验收：7 个按钮都在、都接对了、顺序与 UX 规格一致。[br]
## [br][b]为什么需要[/b]：动作层写好了、菜单脚本接好了，但玩家点的是 tscn 里的
## 按钮——[code][connection][/code] 那几行漏一条，按钮就是个哑巴（点下去什么都不
## 发生），而脚本层的用例全绿。本文件从场景文件本身出发，走真实的 [code]pressed[/code]
## 信号，钉住「按了会发生什么」。[br]
## [br][b]覆盖[/b]：[br]
##   1. 七个按钮齐全（继续 / 查看卡组 / 系统设置 / 存档 / 读档 / 保存并退出 / 返回主菜单）；[br]
##   2. 树序 = UX 规格的展示顺序，且反馈行排在进度行之后（都在最底）；[br]
##   3. 新加的两个按钮真的接了：存档按下 → 写盘 + 反馈；读档按下 → 打开槽位面板；[br]
##   4. 两个导航留桩按钮收到的是信号（界面本体归各自的 epic）。[br]
## [br]装置见 [code]pause_menu_fixture.gd[/code]。[br]
##
## 来源: design/ux/pause-menu.md（选项列表区 5 按钮 + 本轮新增 2 个）、
## production/epics/hud/story-005-pause-menu.md。

## 按钮的展示顺序（UX 规格：主按钮 → 次按钮 → 分隔线 → 退出两项）。
const BUTTON_ORDER: Array[String] = [
	"ContinueButton", "DeckViewButton", "SettingsButton",
	"SaveButton", "LoadButton", "SaveExitButton", "ReturnButton",
]


func _button(button_name: String) -> Button:
	return menu.get_node("Panel/VBox/" + button_name) as Button


func _button_names_in_order() -> Array[String]:
	## 取 [code]String[/code] 而非 [code]StringName[/code]：节点名比较用 plain String，
	## 两侧类型一致才不会被 GUT 判成「值相同但类型不同」。
	var names: Array[String] = []
	for child: Node in menu.get_node("Panel/VBox").get_children():
		if child is Button:
			names.append(String(child.name))
	return names


# ═══════════════════════════════════════════════════════════════════════════════
# 结构与顺序
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_seven_buttons_exist_in_spec_order() -> void:
	# Act
	var names: Array[String] = _button_names_in_order()
	# Assert
	assert_eq(names.size(), BUTTON_ORDER.size(), "面板应恰好有 7 个按钮")
	assert_eq(names, BUTTON_ORDER, "按钮树序应与 UX 规格的展示顺序一致")


func test_status_row_sits_below_progress_row() -> void:
	## 反馈行贴在最底：玩家的视线从按钮往下走，反馈不该插在按钮中间。
	# Act
	var box: Node = menu.get_node("Panel/VBox")
	var children: Array = box.get_children()
	var progress_index: int = children.find(box.get_node("ProgressLabel"))
	var status_index: int = children.find(box.get_node("StatusLabel"))
	# Assert
	assert_gt(status_index, progress_index, "反馈行应排在进度行之后")
	assert_eq(status_index, children.size() - 1, "反馈行应是面板里最后一个子节点")


func test_separator_sits_before_exit_buttons() -> void:
	# Act
	var box: Node = menu.get_node("Panel/VBox")
	var children: Array = box.get_children()
	# Assert
	assert_eq(children.find(box.get_node("HSeparator")), children.find(box.get_node("SaveExitButton")) - 1,
			"分隔线应紧邻「保存并退出」之前（视觉上把退出两项分开）")


# ═══════════════════════════════════════════════════════════════════════════════
# 接线
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_button_is_wired_to_save_action() -> void:
	# Arrange
	open_menu()
	# Act —— 走真实场景信号（不直调处理函数）
	_button("SaveButton").pressed.emit()
	# Assert
	assert_eq(sl.save_calls.size(), 1, "点「存档」应真实写盘一次")
	assert_eq(status_text(), "已存档", "点「存档」应看到「已存档」")


func test_load_button_is_wired_to_open_panel() -> void:
	# Arrange
	open_menu()
	# Act
	_button("LoadButton").pressed.emit()
	# Assert
	assert_not_null(load_panel(), "点「读档」应创建槽位面板")
	assert_true(bool(load_panel().call(&"is_open")), "点「读档」后面板应打开")


func test_continue_button_closes_menu() -> void:
	# Arrange
	open_menu()
	# Act
	_button("ContinueButton").pressed.emit()
	# Assert
	assert_false(menu.visible, "点「继续游戏」应关闭菜单")
	assert_false(get_tree().paused, "点「继续游戏」应恢复游戏")


func test_navigation_stub_buttons_emit_signals() -> void:
	## 查看卡组 / 系统设置的目标界面不在本 story——留桩为信号，不实现界面本体。
	# Arrange
	open_menu()
	watch_signals(menu)
	# Act
	_button("DeckViewButton").pressed.emit()
	_button("SettingsButton").pressed.emit()
	# Assert
	assert_signal_emitted(menu, "deck_view_requested", "「查看卡组」应发出导航请求信号")
	assert_signal_emitted(menu, "settings_requested", "「系统设置」应发出导航请求信号")
	assert_true(menu.visible, "留桩按钮不应关闭菜单")
