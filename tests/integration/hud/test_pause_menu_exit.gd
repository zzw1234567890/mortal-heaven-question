extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 暂停菜单两条退出路径验收：保存并退出 / 返回主菜单。[br]
## [br][b]为什么需要[/b]：GAP-5 裁决把两条路分开了——「保存并退出」存档成功才走
## （失败留在菜单里给原因），「返回主菜单」先顺手存一次底再走（失败也放行，因为
## 它是「留个底」而不是玩家显式要求的存档）。两条路都要解除暂停再转场：
## 转场管线不含暂停恢复职责，冻结态下新场景会停在冻结帧。[br]
## [br][b]本轮补二次确认[/b]：两条路都不可逆，无障碍要求防误触——按下按钮只弹确认框，
## 点「确认保存」才走上面那条链。故本文件每个用例在 [code]Act[/code] 里多走一步
## [code]confirm_button("ConfirmButton").pressed.emit()[/code]；「只弹框不动作」
## 与「取消 / ESC 不动作」是新增的独立断言面（见
## [code]test_pause_menu_confirm.gd[/code]）。[br]
## [br][b]覆盖[/b]：[br]
##   1. 保存并退出：成功 → 转场 MAIN_MENU（from 取当前场景）+ 解除暂停 + pop 锁；[br]
##   2. 保存并退出失败：留在菜单、保持暂停、不转场，给出带错误码的原因；[br]
##   3. 返回主菜单：先自动存档一次再转场（同一槽位，与场景切换的自动存档幂等）；[br]
##   4. 依赖缺失（无 SceneManager）：不崩、不静默——push_error 后仍解除暂停收起菜单。[br]
## [br]装置见 [code]pause_menu_fixture.gd[/code]。[br]
## [br]注：[code]SLS[/code] / [code]SM[/code] 由夹具提供，此处不再声明——
## GDScript 里子类重复声明同名成员是解析错误，整个文件会被 GUT 静默忽略。[br]
##
## 来源: design/ux/pause-menu.md（「保存并退出」vs「返回主菜单」）、
## ADR-0005（导航唯一入口）、ADR-0031 §1.1/§2、code-review M-2/M-4。

# ═══════════════════════════════════════════════════════════════════════════════
# 保存并退出
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_exit_writes_slot_then_returns_to_menu() -> void:
	# Arrange
	open_menu()
	# Act
	menu._on_save_exit_pressed()
	confirm_button("ConfirmButton").pressed.emit()
	# Assert
	assert_eq(sl.save_calls.size(), 1, "保存并退出应真实写盘一次")
	assert_eq(int(sl.save_calls[0][0]), SLS.SaveSlotType.AUTOSAVE, "写自动槽")
	assert_eq(sm.change_calls.size(), 1, "存档成功后应请求转场一次")
	var call: Array = sm.change_calls[0]
	assert_eq(int(call[0]), SM.SceneID.EXPLORATION, "from 应取当前场景 ID（非魔数）")
	assert_eq(int(call[1]), SM.SceneID.MAIN_MENU, "目标应为主菜单")
	assert_eq(int(call[2]), SM.TransitionType.GAME_TO_MENU, "转场类型应为游戏→菜单")


func test_save_exit_releases_pause_before_navigating() -> void:
	## 顺序不可反：冻结态下转场，新场景会停在冻结帧。
	# Arrange
	open_menu()
	# Act
	menu._on_save_exit_pressed()
	confirm_button("ConfirmButton").pressed.emit()
	# Assert
	assert_false(get_tree().paused, "转场前应解除暂停")
	assert_false(menu.visible, "转场前应收起菜单")
	assert_eq(InputManager.get_lock_stack().size(), 0, "转场前应 pop MODAL 锁")
	assert_eq(adapter.resume_calls, 1, "转场前应恢复音频")


func test_save_exit_failure_keeps_menu_open() -> void:
	# Arrange —— WRITE_ERROR（2）
	sl.save_result = SLS.SaveResult.WRITE_ERROR
	open_menu()
	# Act
	menu._on_save_exit_pressed()
	confirm_button("ConfirmButton").pressed.emit()
	# Assert
	assert_eq(status_text(), "存档失败（错误码 2）", "应给出带错误码的原因")
	assert_true(menu.visible, "存档失败应保持菜单打开（不丢进度、不退出）")
	assert_true(get_tree().paused, "存档失败应保持暂停")
	assert_eq(sm.change_calls.size(), 0, "存档失败不得转场")
	assert_true(InputManager.has_lock(&"pause_menu"), "存档失败不应释放锁")


# ═══════════════════════════════════════════════════════════════════════════════
# 返回主菜单
# ═══════════════════════════════════════════════════════════════════════════════

func test_return_to_menu_auto_saves_first_then_navigates() -> void:
	# Arrange
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(sl.auto_save_calls, 1, "返回主菜单应先自动存档一次（顺手留个底）")
	assert_eq(sm.change_calls.size(), 1, "应请求一次转场")
	assert_eq(int(sm.change_calls[0][1]), SM.SceneID.MAIN_MENU, "目标应为主菜单")
	assert_false(get_tree().paused, "转场前应解除暂停")
	assert_false(InputManager.has_lock(&"pause_menu"), "转场前应 pop MODAL 锁")


func test_return_to_menu_goes_even_when_auto_save_fails() -> void:
	## 「留个底」失败不该拦住玩家离开——它是顺手，不是玩家显式要求的存档。
	# Arrange
	sl.save_result = SLS.SaveResult.DISK_FULL
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(sl.auto_save_calls, 1, "仍应尝试自动存档一次")
	assert_eq(sm.change_calls.size(), 1, "自动存档失败不应拦住转场")
	assert_false(get_tree().paused, "仍应解除暂停")


func test_return_to_menu_without_scene_manager_releases_pause() -> void:
	## 依赖缺失：转场发不出去（push_error 报明），但菜单不能卡在冻结态。
	# Arrange
	menu.scene_manager = null
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(sm.change_calls.size(), 0, "SceneManager 缺失时不应有转场请求")
	assert_false(get_tree().paused, "依赖缺失也应解除暂停（不把玩家锁在冻结帧里）")
	assert_false(menu.visible, "依赖缺失也应收起菜单")
	assert_eq(InputManager.get_lock_stack().size(), 0, "依赖缺失也应 pop 锁")


func test_save_exit_does_not_double_write_via_auto_save() -> void:
	## 「保存并退出」刚写过盘——不必再顺手存一次（同一格同一内容，白写一遍）。
	# Arrange
	open_menu()
	# Act
	menu._on_save_exit_pressed()
	confirm_button("ConfirmButton").pressed.emit()
	# Assert
	assert_eq(sl.save_calls.size(), 1, "保存并退出只写一次")
	assert_eq(sl.auto_save_calls, 0, "保存并退出不应再触发一次自动存档")
