extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 暂停菜单「读档」验收：面板开关 + 选格导航 + 失败留在菜单。[br]
## [br][b]为什么需要[/b]：暂停菜单只有「保存并退出」一条出口——探索途中想换个档
## 重来（比如刚打的这局走歪了）只能退回主菜单再走一遍。本轮接上主菜单那条读档链
## （同一份 [code]LoadSlotPanel[/code]、同一个 [code]load_and_resume[/code]）。[br]
## [br][b]覆盖[/b]：[br]
##   1. 点「读档」打开槽位面板，四格（自动 + 手动 1-3）与主菜单同一份口径；[br]
##   2. 选一格：真实读档 → 发续玩意图 → 请求转场探索 → 解除暂停（成功后不留冻结态）；[br]
##   3. 档损坏：不导航、不解除暂停，菜单里给带错误码的原因；[br]
##   4. 成功但空载荷：文件没坏只是没东西可续，不导航也不说谎；[br]
##   5. 面板开着时 ESC 先收面板（分层），菜单与锁都不动；[br]
##   6. 再点「读档」重新取槽位列表（停留期间可能刚存过一档）。[br]
## [br]装置见 [code]pause_menu_fixture.gd[/code]。[br]
## [br]注：[code]SLS[/code] / [code]SM[/code] / [code]IntentScript[/code] 由夹具提供，
## 此处不再声明——GDScript 里子类重复声明同名成员是解析错误，整个文件会被 GUT
## 静默忽略。[br]
##
## 来源: design/gdd/main-menu-system.md（读档路径）、ADR-0005（导航唯一入口）、
## ADR-0031 §2。

## 读档列表第一格（自动存档）——多数用例的默认选中项。
const AUTOSAVE: int = 0


# ═══════════════════════════════════════════════════════════════════════════════
# 面板开关
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_button_opens_slot_panel_with_four_slots() -> void:
	# Arrange
	sl.slots = [slot_meta(AUTOSAVE, 0), slot_meta(1, 2)]
	open_menu()
	# Act
	menu._on_load_pressed()
	# Assert
	var panel: Control = load_panel()
	assert_not_null(panel, "点「读档」应创建槽位面板")
	assert_true(bool(panel.call(&"is_open")), "面板应处于打开态")
	var buttons: Array = panel.call(&"slot_buttons")
	assert_eq(buttons.size(), 4, "面板应列出四格（自动 + 手动 1-3，空槽也列）")


func test_load_panel_is_child_of_menu() -> void:
	## 挂载宿主是菜单本体——面板随菜单一起被树隐藏（暂停中不会留在屏幕上）。
	# Arrange
	open_menu()
	# Act
	menu._on_load_pressed()
	# Assert
	var panel: Control = load_panel()
	assert_eq(panel.get_parent(), menu, "面板应挂在暂停菜单节点树下")


func test_load_panel_closes_on_esc_and_keeps_menu_open() -> void:
	## ESC 分层：面板开着时第一下收面板，菜单与暂停状态都不动。
	# Arrange
	open_menu()
	menu._on_load_pressed()
	assert_true(bool(load_panel().call(&"is_open")), "前置：面板已打开")
	# Act
	menu._unhandled_input(esc_event())
	# Assert
	assert_false(bool(load_panel().call(&"is_open")), "ESC 应先收起读档面板")
	assert_true(menu.visible, "ESC 收起面板时不应关闭暂停菜单")
	assert_true(get_tree().paused, "暂停状态不应被这一下 ESC 改变")
	assert_true(InputManager.has_lock(&"pause_menu"), "锁不应被这一下 ESC 释放")


func test_load_panel_back_restores_menu_focus_and_clears_status() -> void:
	## 面板收起后焦点不能悬空——面板按钮一隐藏，键盘/手柄玩家会觉得「什么都按不动」。
	# Arrange —— 先留一条失败反馈，再开面板（开面板本身就清反馈）
	sl.save_result = SLS.SaveResult.WRITE_ERROR
	open_menu()
	menu._on_save_pressed()
	assert_ne(status_text(), "", "前置：菜单里留着一条失败反馈")
	menu._on_load_pressed()
	assert_true(load_panel().get_parent() == menu, "前置：面板已挂上")
	# Act —— 面板「返回」（面板已自行收起）
	menu._on_load_panel_back()
	# Assert
	assert_eq(status_text(), "", "从读档面板返回应清掉上一条反馈")
	assert_true((menu.get_node("Panel/VBox/ContinueButton") as Button).has_focus(),
			"返回后焦点应落回菜单的默认按钮（不悬空）")


func test_load_button_repopulates_slots_each_time() -> void:
	## 停留期间可能刚存过一档（或另一进程写过）——列表不能缓存。
	# Arrange —— 首次打开时手动 1 还是空的
	sl.slots = [slot_meta(AUTOSAVE, 0)]
	open_menu()
	menu._on_load_pressed()
	var before: Array = load_panel().call(&"slot_buttons")
	assert_true((before[1] as Button).text.contains("（空）"),
			"前置：手动 1 应为空槽（文案带「（空）」）")
	menu.get_actions().close_load_panel()
	# Act —— 存了一档后重新打开
	sl.slots = [slot_meta(AUTOSAVE, 0), slot_meta(1, 1, "金丹期")]
	menu._on_load_pressed()
	# Assert
	var after: Array = load_panel().call(&"slot_buttons")
	assert_true((after[1] as Button).text.contains("金丹期"),
			"重新打开应看到刚写进去的那一档（列表现取现画）")
	assert_false((after[1] as Button).disabled, "有档的槽位应可点")
	assert_true((after[2] as Button).disabled, "仍为空的槽位应保持置灰")


# ═══════════════════════════════════════════════════════════════════════════════
# 选中一格
# ═══════════════════════════════════════════════════════════════════════════════

func test_choosing_slot_loads_navigates_and_unpauses() -> void:
	# Arrange
	sl.slots = [slot_meta(AUTOSAVE, 0)]
	open_menu()
	menu._on_load_pressed()
	# Act —— 真实点击按钮（先收起面板 → 报意图 → 读档 → 转场）
	(load_panel().call(&"slot_buttons")[0] as Button).pressed.emit()
	# Assert
	assert_eq(sl.load_calls.size(), 2,
			"应读同一格两次：先探判定、判定通过才让导航层真正走那一跳")
	assert_eq(sl.load_calls[0], [AUTOSAVE, 0], "第一次探的应是玩家点的那一格")
	assert_true(IntentScript.has_pending(), "读档成功应留下续玩意图")
	assert_eq(IntentScript.take_entry_mode(), IntentScript.EntryMode.RESUME,
			"意图应为「回到存档里那张图」")
	assert_eq(sm.change_calls.size(), 1, "应请求一次转场")
	assert_eq(int(sm.change_calls[0][1]), SM.SceneID.EXPLORATION,
			"读档的目标应为探索（绕过身份选择）")
	assert_false(get_tree().paused, "转场前应解除暂停（否则新场景停在冻结帧）")
	assert_false(menu.visible, "转场前应收起菜单")
	assert_false(InputManager.has_lock(&"pause_menu"), "转场前应 pop MODAL 锁")


func test_corrupt_save_keeps_menu_open_with_reason() -> void:
	# Arrange —— 档损坏（CORRUPTED = 2）
	sl.slots = [slot_meta(AUTOSAVE, 0)]
	sl.load_result = SLS.LoadResult.CORRUPTED
	open_menu()
	menu._on_load_pressed()
	# Act
	(load_panel().call(&"slot_buttons")[0] as Button).pressed.emit()
	# Assert
	assert_eq(status_text(), "读档失败（错误码 2）", "损坏档应给带错误码的原因")
	assert_true(menu.visible, "读档失败应留在暂停菜单里（不静默丢进度）")
	assert_true(get_tree().paused, "读档失败不应解除暂停")
	assert_true(InputManager.has_lock(&"pause_menu"), "读档失败不应释放锁")
	assert_eq(sm.change_calls.size(), 0, "读档失败不得请求转场")
	assert_false(IntentScript.has_pending(), "读档失败不得留下续玩意图")
	assert_eq(sl.load_calls.size(), 1, "判定失败即止——不应重复读同一格")


func test_empty_payload_does_not_navigate() -> void:
	## 成功但空载荷：文件没坏，只是没有可续玩的内容——不导航也不说谎。
	# Arrange
	sl.slots = [slot_meta(AUTOSAVE, 0)]
	sl.payload = {}
	open_menu()
	menu._on_load_pressed()
	# Act
	(load_panel().call(&"slot_buttons")[0] as Button).pressed.emit()
	# Assert
	assert_eq(status_text(), "该存档没有可续玩的内容", "应说清「没东西可续」而非「失败」")
	assert_eq(sm.change_calls.size(), 0, "空载荷不得请求转场")
	assert_true(menu.visible, "空载荷应留在菜单里")
	assert_true(get_tree().paused, "空载荷不应解除暂停")


func test_load_unavailable_when_save_load_missing() -> void:
	# Arrange
	menu.save_load = null
	open_menu()
	menu._on_load_pressed()
	# Act
	(load_panel().call(&"slot_buttons")[0] as Button).pressed.emit()
	# Assert
	assert_eq(status_text(), "读档系统不可用", "依赖缺失应说明原因")
	assert_true(menu.visible, "依赖缺失时应留在菜单里")


func test_empty_slot_is_disabled_and_focus_start_skips_it() -> void:
	## 空槽位置灰——「你还能存到哪」是信息，但它点不动、也不该被键盘停在上面：
	## 置灰的 Button 不响应激活，且焦点起点落在有档的那一格。
	# Arrange —— 只有自动槽有档（手动 1-3 全空）
	sl.slots = [slot_meta(AUTOSAVE, 0)]
	open_menu()
	menu._on_load_pressed()
	# Assert
	var buttons: Array = load_panel().call(&"slot_buttons")
	assert_true((buttons[2] as Button).disabled, "空槽位按钮应置灰（引擎不派发激活）")
	assert_false((buttons[0] as Button).disabled, "有档的槽位应可点")
	var first: Button = load_panel().call(&"first_enabled_button")
	assert_eq(first, buttons[0], "首个可聚焦按钮应落在有档的那一格，而不是空槽")
	assert_true(first.has_focus(), "打开面板时焦点起点应在有档的那一格上")
