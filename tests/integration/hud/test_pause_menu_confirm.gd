extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 暂停菜单二次确认验收：取消路径 / 确认路径 / ESC 分层。[br]
## [br][b]为什么需要[/b]：「保存并退出」与「返回主菜单」都是不可逆动作（前者结束本次
## 会话、后者丢掉未保存的进度），无障碍检查表要求两者均需二次确认——为认知障碍与
## 手滑玩家提供容错（design/ux/pause-menu.md §Accessibility「确认弹窗防误触」）。
## 同时要求「ESC 可取消」且「焦点默认落在取消上」——误开的框必须一个键退得出去，
## 且回车不会直接执行危险动作。[br]
## [br][b]覆盖[/b]：[br]
##   1. 点两个危险按钮只弹框——不写盘、不转场、不解除暂停、不动锁栈；[br]
##   2. 焦点默认落在「取消」上（回车不执行危险动作）；[br]
##   3. 取消按钮与 ESC 两条取消路径：框收起、菜单还在、什么都没发生；[br]
##   4. 取消后焦点回锚到菜单按钮（不悬空）；[br]
##   5. 确认路径：写盘 + 转场 + 解除暂停 + pop 锁（三条链各自的落地）；[br]
##   6. ESC 分层：确认框开着时第一下收框，第三层才关菜单；[br]
##   7. 返回主菜单变体三键齐全 + 战斗中补「视为战败」提示；[br]
##   8. 框是复用式单例（重开不叠第二个），关菜单时一并收起。[br]
## [br]装置见 [code]pause_menu_fixture.gd[/code]。[br]
## [br]注：[code]SLS[/code] / [code]SM[/code] 由夹具提供，此处不再声明——
## GDScript 里子类重复声明同名成员是解析错误，整个文件会被 GUT 静默忽略。[br]
##
## 来源: design/ux/pause-menu.md（两个确认弹窗 / Accessibility 确认弹窗防误触 /
## 键盘焦点顺序）、ADR-0031 §1.1/§2、.claude/rules/ui-code.md。

## 确认框的两种类型（[PauseMenuConfirm] 是真理来源，此处具名化以免用例里读魔数）。
const TYPE_SAVE_EXIT: int = 0
const TYPE_RETURN: int = 1
## 确认框内部的路径前缀（按钮行）。
const BUTTONS_PATH: String = "Panel/VBox/Buttons/"


func _label_text(label_name: String) -> String:
	var dialog: Control = confirm_dialog()
	if dialog == null or not is_instance_valid(dialog):
		return ""
	var label: Label = dialog.get_node_or_null("Panel/VBox/" + label_name) as Label
	return label.text if label != null else ""


func _label_visible(label_name: String) -> bool:
	var dialog: Control = confirm_dialog()
	if dialog == null or not is_instance_valid(dialog):
		return false
	var label: Label = dialog.get_node_or_null("Panel/VBox/" + label_name) as Label
	return label != null and label.visible


# ═══════════════════════════════════════════════════════════════════════════════
# 只弹框，不动作
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_exit_button_only_opens_confirm_dialog() -> void:
	## 按下「保存并退出」= 请求确认，不是执行——写盘与转场都要等确认。
	# Arrange
	open_menu()
	# Act
	menu._on_save_exit_pressed()
	# Assert
	assert_not_null(confirm_dialog(), "应创建一个确认框")
	assert_true(bool(confirm_dialog().call(&"is_open")), "确认框应处于打开态")
	assert_eq(int(confirm_dialog().call(&"confirm_type")), TYPE_SAVE_EXIT,
			"确认类型应为「保存并退出」")
	assert_eq(sl.save_calls.size(), 0, "仅弹框不得写盘")
	assert_eq(sm.change_calls.size(), 0, "仅弹框不得转场")
	assert_true(menu.visible, "仅弹框不得关菜单")
	assert_true(get_tree().paused, "仅弹框不得解除暂停")
	assert_true(InputManager.has_lock(&"pause_menu"), "仅弹框不得动锁栈")


func test_return_button_only_opens_confirm_dialog() -> void:
	# Arrange
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	# Assert
	assert_true(bool(confirm_dialog().call(&"is_open")), "确认框应打开")
	assert_eq(int(confirm_dialog().call(&"confirm_type")), TYPE_RETURN,
			"确认类型应为「返回主菜单」")
	assert_eq(sl.auto_save_calls, 0, "仅弹框不得自动存档")
	assert_eq(sm.change_calls.size(), 0, "仅弹框不得转场")
	assert_true(menu.visible, "仅弹框不得关菜单")


func test_confirm_dialog_defaults_focus_to_cancel() -> void:
	## 无障碍核心：误开的框里按回车 = 取消，不是执行危险动作。[br]
	## 先点「返回主菜单」（三键变体）——取消仍应是焦点起点。
	# Arrange
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	# Assert
	var cancel: Button = confirm_button("CancelButton")
	assert_not_null(cancel, "确认框应有「取消」按钮")
	assert_true(cancel.has_focus(), "焦点应默认落在「取消」上（回车不执行危险动作）")
	assert_false(confirm_button("ConfirmButton").has_focus(), "焦点不应落在确认上")
	assert_false(confirm_button("LeaveButton").has_focus(), "焦点不应落在「不保存」上")


func test_confirm_dialog_text_matches_spec() -> void:
	# Arrange
	open_menu()
	# Act —— 保存并退出变体
	menu._on_save_exit_pressed()
	# Assert
	assert_eq(_label_text("TitleLabel"), "保存并退出？", "标题应为规格原文")
	assert_true(_label_text("BodyLabel").contains("当前进度将被保存"),
			"正文应说明「进度会被保存」")
	assert_eq(confirm_button("ConfirmButton").text, "确认保存", "确认键文案")
	assert_eq(confirm_button("CancelButton").text, "取消", "取消键文案")
	assert_false(confirm_button("LeaveButton").visible,
			"「保存并退出」只有确认/取消两键——不应出现「不保存」")


func test_return_variant_has_three_buttons_and_warning() -> void:
	# Arrange
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	# Assert
	assert_eq(_label_text("TitleLabel"), "⚠ 返回主菜单？", "标题应为规格原文")
	assert_true(_label_text("BodyLabel").contains("未保存的进度将丢失"),
			"正文应说明「未保存的进度会丢」")
	assert_true(confirm_button("LeaveButton").visible, "返回主菜单应有「不保存」键")
	assert_eq(confirm_button("LeaveButton").text, "不保存", "「不保存」键文案")


func test_combat_return_shows_defeat_warning() -> void:
	## 战斗中的「返回主菜单」额外提示「当前战斗进度将丢失——视为战败」（规格明写）。
	# Arrange —— 当前场景设为战斗
	sm.scene_id = SM.SceneID.COMBAT
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	# Assert
	assert_true(_label_visible("WarningLabel"), "战斗中应显示警示行")
	assert_true(_label_text("WarningLabel").contains("视为战败"),
			"警示应说明「视为战败」")


func test_non_combat_return_hides_defeat_warning() -> void:
	# Arrange —— 缺省 EXPLORATION
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	# Assert
	assert_false(_label_visible("WarningLabel"), "非战斗场景不应显示战败警示")


# ═══════════════════════════════════════════════════════════════════════════════
# 取消路径（按钮 / ESC）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cancel_button_closes_dialog_and_does_nothing() -> void:
	# Arrange
	open_menu()
	menu._on_save_exit_pressed()
	# Act
	confirm_button("CancelButton").pressed.emit()
	# Assert
	assert_false(bool(confirm_dialog().call(&"is_open")), "取消后确认框应收起")
	assert_eq(sl.save_calls.size(), 0, "取消不得写盘")
	assert_eq(sm.change_calls.size(), 0, "取消不得转场")
	assert_true(menu.visible, "取消后应留在暂停菜单")
	assert_true(get_tree().paused, "取消后应仍处于暂停")
	assert_true(InputManager.has_lock(&"pause_menu"), "取消不应释放锁")


func test_cancel_restores_focus_to_menu_button() -> void:
	## 框一收起，框里的按钮就隐藏——焦点不重锚的话键盘玩家觉得「什么都按不动」。
	# Arrange
	open_menu()
	menu._on_return_main_menu_pressed()
	# Act
	confirm_button("CancelButton").pressed.emit()
	# Assert
	assert_eq(focus_owner(), menu.get_node("Panel/VBox/ContinueButton"),
			"取消后焦点应回锚到菜单的首个可选按钮")


func test_esc_cancels_dialog_and_keeps_menu_open() -> void:
	## ESC 可取消（无障碍要求）——且只退一层，菜单不动。
	# Arrange
	open_menu()
	menu._on_save_exit_pressed()
	assert_true(bool(confirm_dialog().call(&"is_open")), "前置：确认框已打开")
	# Act
	menu._unhandled_input(esc_event())
	# Assert
	assert_false(bool(confirm_dialog().call(&"is_open")), "ESC 应收起确认框")
	assert_true(menu.visible, "ESC 收框时不应关闭暂停菜单")
	assert_true(get_tree().paused, "ESC 收框时不应解除暂停")
	assert_true(InputManager.has_lock(&"pause_menu"), "ESC 收框时不应释放锁")
	assert_eq(sl.save_calls.size(), 0, "ESC 取消不得写盘")
	assert_eq(sm.change_calls.size(), 0, "ESC 取消不得转场")


func test_esc_layering_confirm_then_menu() -> void:
	## 三层退：第一下收确认框，第二下才关菜单（共用一个键必须一层层退）。
	# Arrange
	open_menu()
	menu._on_save_exit_pressed()
	# Act —— 第一下
	menu._unhandled_input(esc_event())
	# Assert
	assert_true(menu.visible, "第一下 ESC 后菜单应还在")
	# Act —— 第二下
	menu._unhandled_input(esc_event())
	# Assert
	assert_false(menu.visible, "第二下 ESC 才关闭菜单")
	assert_false(get_tree().paused, "菜单关闭后应解除暂停")


func test_esc_layering_confirm_then_load_panel_then_menu() -> void:
	## 确认框压在读档面板之上：先退框、再退面板、最后关菜单。
	# Arrange —— 面板与框同时开着（框在其上）
	open_menu()
	menu._on_load_pressed()
	menu._on_save_exit_pressed()
	# Act + Assert —— 第一下：收框
	menu._unhandled_input(esc_event())
	assert_false(bool(confirm_dialog().call(&"is_open")), "第一下应收确认框")
	assert_true(bool(load_panel().call(&"is_open")), "第一下不应动读档面板")
	# Act + Assert —— 第二下：收面板
	menu._unhandled_input(esc_event())
	assert_false(bool(load_panel().call(&"is_open")), "第二下应收读档面板")
	assert_true(menu.visible, "第二下后菜单应还在")
	# Act + Assert —— 第三下：关菜单
	menu._unhandled_input(esc_event())
	assert_false(menu.visible, "第三下才关闭菜单")


# ═══════════════════════════════════════════════════════════════════════════════
# 确认路径
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_save_exit_writes_and_navigates() -> void:
	# Arrange
	open_menu()
	menu._on_save_exit_pressed()
	# Act
	confirm_button("ConfirmButton").pressed.emit()
	# Assert
	assert_eq(sl.save_calls.size(), 1, "确认后应真实写盘一次")
	assert_eq(int(sl.save_calls[0][0]), SLS.SaveSlotType.AUTOSAVE, "写自动槽")
	assert_eq(sm.change_calls.size(), 1, "确认后应请求转场")
	assert_eq(int(sm.change_calls[0][1]), SM.SceneID.MAIN_MENU, "目标应为主菜单")
	assert_false(get_tree().paused, "转场前应解除暂停")
	assert_false(InputManager.has_lock(&"pause_menu"), "转场前应 pop 锁")


func test_confirm_return_with_save_writes_then_navigates() -> void:
	## 返回主菜单确认框的「确认保存」= 先存档再离开（与「保存并退出」同一条链）。
	# Arrange
	open_menu()
	menu._on_return_main_menu_pressed()
	# Act
	confirm_button("ConfirmButton").pressed.emit()
	# Assert
	assert_eq(sl.save_calls.size(), 1, "「确认保存」应真实写盘一次")
	assert_eq(sl.auto_save_calls, 0, "刚写过盘——不再顺手存一次")
	assert_eq(sm.change_calls.size(), 1, "应请求转场一次")
	assert_false(get_tree().paused, "转场前应解除暂停")


func test_confirm_return_without_save_leaves_directly() -> void:
	## 「不保存」= 不以存档成功为前提直接离开；自动存档仍会顺手存一次底。
	# Arrange
	open_menu()
	menu._on_return_main_menu_pressed()
	# Act
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(sl.save_calls.size(), 0, "「不保存」不得显式写盘")
	assert_eq(sl.auto_save_calls, 1, "应顺手自动存档一次（留个底）")
	assert_eq(sm.change_calls.size(), 1, "应请求转场一次")
	assert_false(menu.visible, "应收起菜单")


func test_confirm_save_exit_failure_keeps_menu_open() -> void:
	## 确认后写盘失败：留在菜单里给原因（与二次确认前的失败语义一致）。
	# Arrange
	sl.save_result = SLS.SaveResult.WRITE_ERROR
	open_menu()
	menu._on_save_exit_pressed()
	# Act
	confirm_button("ConfirmButton").pressed.emit()
	# Assert
	assert_eq(status_text(), "存档失败（错误码 2）", "应给出带错误码的原因")
	assert_true(menu.visible, "写盘失败应留在菜单里")
	assert_true(get_tree().paused, "写盘失败应保持暂停")
	assert_eq(sm.change_calls.size(), 0, "写盘失败不得转场")


# ═══════════════════════════════════════════════════════════════════════════════
# 复用与清理
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_dialog_is_reused_across_openings() -> void:
	## 复用式单例：反复开合不叠加第二个框（同 LoadSlotPanel 的口径）。
	# Arrange
	open_menu()
	menu._on_save_exit_pressed()
	var first: Control = confirm_dialog()
	menu._unhandled_input(esc_event())
	# Act —— 换一个危险按钮再开一次
	menu._on_return_main_menu_pressed()
	# Assert
	assert_eq(confirm_dialog(), first, "应复用同一个确认框实例")
	assert_eq(int(confirm_dialog().call(&"confirm_type")), TYPE_RETURN,
			"重开后类型应切到「返回主菜单」")


func test_closing_menu_also_closes_confirm_dialog() -> void:
	## 留一个「开着」的框在隐藏的菜单里，下次打开会看到它浮在菜单上（状态串味）。
	# Arrange
	open_menu()
	menu._on_save_exit_pressed()
	# Act
	menu.request_close()
	# Assert
	assert_false(bool(confirm_dialog().call(&"is_open")), "关菜单应一并收起确认框")
	assert_false(confirm_dialog().visible, "确认框应不可见")


func test_reopening_menu_shows_no_stale_confirm_dialog() -> void:
	# Arrange —— 开着框关菜单，再打开
	open_menu()
	menu._on_save_exit_pressed()
	menu.request_close()
	# Act
	open_menu()
	# Assert
	assert_false(confirm_dialog().visible, "重开菜单不应看到上一次留下的确认框")
	assert_true(menu.visible, "菜单本身应正常打开")
